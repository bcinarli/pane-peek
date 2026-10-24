#if !PANEPEEK_APP_STORE
import Foundation
import CryptoKit

enum UpdateRoute: Sendable {
    case metadata
    case download(URL)

    var url: URL {
        switch self {
        case .metadata: URL(string: "https://api.github.com/repos/bcinarli/pane-peek/releases/latest")!
        case .download(let url): url
        }
    }

    func allows(_ url: URL, redirect: Int) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil, url.fragment == nil, redirect <= 3 else { return false }
        switch self {
        case .metadata: return redirect == 0 && url == self.url
        case .download:
            if redirect == 0 {
                return url.host == "github.com" && url.path.hasPrefix("/bcinarli/pane-peek/releases/download/") && url.query == nil
            }
            return url.host == "release-assets.githubusercontent.com"
                && url.path.hasPrefix("/github-production-release-asset/")
        }
    }

    var accept: String {
        switch self { case .metadata: "application/vnd.github+json"; case .download: "application/octet-stream" }
    }
}

struct UpdateResponse: Sendable {
    let data: Data
    let digest: String
}

struct UpdateTransport: @unchecked Sendable {
    static let maximumDownloadBytes: Int64 = 256 * 1024 * 1024
    let protocolClasses: [AnyClass]?
    init(protocolClasses: [AnyClass]? = nil) { self.protocolClasses = protocolClasses }

    func fetch(_ route: UpdateRoute, maximumBytes: Int64 = 256 * 1024, to destination: URL? = nil,
               expectedBytes: Int64? = nil, progress: (@Sendable (Double?) -> Void)? = nil) async throws -> UpdateResponse {
        guard route.allows(route.url, redirect: 0) else { throw UpdateError.transport }
        let transfer = try UpdateTransfer(route: route, maximumBytes: maximumBytes, destination: destination,
                                          expectedBytes: expectedBytes, progress: progress, protocolClasses: protocolClasses)
        return try await withTaskCancellationHandler { try await transfer.run() } onCancel: { transfer.cancel() }
    }
}

/// A separate ephemeral session bounds each transfer and streams file bytes without a memory-sized download.
private final class UpdateTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let route: UpdateRoute
    private let maximumBytes: Int64
    private let expectedBytes: Int64?
    private let progress: (@Sendable (Double?) -> Void)?
    private let protocolClasses: [AnyClass]?
    private var file: FileHandle?
    private var data = Data()
    private var digest = SHA256()
    private var count: Int64 = 0
    private var redirects = 0
    private var failure: (any Error)?
    private var cancelled = false
    private var continuation: CheckedContinuation<UpdateResponse, any Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?

    init(route: UpdateRoute, maximumBytes: Int64, destination: URL?, expectedBytes: Int64?,
         progress: (@Sendable (Double?) -> Void)?, protocolClasses: [AnyClass]?) throws {
        self.route = route
        self.maximumBytes = maximumBytes
        self.expectedBytes = expectedBytes
        self.progress = progress
        self.protocolClasses = protocolClasses
        if let destination {
            let descriptor = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
            guard descriptor >= 0 else { throw UpdateError.storage }
            file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        }
    }

    func run() async throws -> UpdateResponse {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                guard !cancelled else { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                let config = URLSessionConfiguration.ephemeral
                config.httpCookieStorage = nil
                config.httpShouldSetCookies = false
                config.urlCredentialStorage = nil
                config.urlCache = nil
                config.requestCachePolicy = .reloadIgnoringLocalCacheData
                config.timeoutIntervalForRequest = 30
                config.timeoutIntervalForResource = route.isMetadata ? 30 : 300
                config.protocolClasses = protocolClasses
                let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.session = session
                task = session.dataTask(with: request(route.url))
                task?.resume()
            }
        }
    }

    func cancel() {
        lock.withLock { cancelled = true; task?.cancel() }
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpShouldHandleCookies = false
        request.setValue("PanePeek-Updates", forHTTPHeaderField: "User-Agent")
        request.setValue(route.accept, forHTTPHeaderField: "Accept")
        request.setValue("", forHTTPHeaderField: "Accept-Language")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        return request
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        redirects += 1
        guard let url = newRequest.url, route.allows(url, redirect: redirects) else {
            failure = UpdateError.transport
            completionHandler(nil)
            return
        }
        completionHandler(request(url))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else { completionHandler(.cancelAuthenticationChallenge, nil) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength <= maximumBytes,
              expectedBytes == nil || response.expectedContentLength < 0 || response.expectedContentLength == expectedBytes else {
            if let http = response as? HTTPURLResponse, [403, 429].contains(http.statusCode) {
                let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
                let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init).map { Date().addingTimeInterval($0) }
                failure = UpdateError.rateLimited(max(Date().addingTimeInterval(60), retry ?? reset ?? Date().addingTimeInterval(3600)))
            } else { failure = UpdateError.incomplete }
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        count += Int64(chunk.count)
        guard count <= maximumBytes, expectedBytes == nil || count <= expectedBytes! else {
            failure = UpdateError.tooLarge
            dataTask.cancel()
            return
        }
        do {
            if let file { try file.write(contentsOf: chunk) }
            else { data.append(chunk) }
            digest.update(data: chunk)
            progress?(expectedBytes.map { Double(count) / Double($0) })
        } catch { failure = UpdateError.storage; dataTask.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        do { try file?.synchronize(); try file?.close() } catch { failure = UpdateError.storage }
        file = nil
        let result: Result<UpdateResponse, any Error> = lock.withLock {
            if cancelled { return .failure(CancellationError()) }
            if let failure { return .failure(failure) }
            if error != nil { return .failure(UpdateError.transport) }
            if let expectedBytes, count != expectedBytes { return .failure(UpdateError.incomplete) }
            return .success(UpdateResponse(data: data, digest: digest.finalize().map { String(format: "%02x", $0) }.joined()))
        }
        let continuation = lock.withLock { let saved = self.continuation; self.continuation = nil; self.task = nil; self.session = nil; return saved }
        session.finishTasksAndInvalidate()
        continuation?.resume(with: result)
    }
}

private extension UpdateRoute {
    var isMetadata: Bool { if case .metadata = self { return true }; return false }
}

#endif
