import Darwin
import Foundation
import WebKit
import PanePeekCore

actor HTMLPreviewAssets {
    static let maximumBytes = 8 * 1_048_576
    static let maximumTotalBytes = 32 * 1_048_576
    static let maximumRequests = 128
    private let directory: Int32
    private let access: DirectoryAccess?
    private var requests = 0
    private var bytesRead = 0

    struct Asset: Sendable {
        let data: Data
        let mimeType: String
    }

    static func open(_ selection: DetailsSelection) async throws -> HTMLPreviewAssets {
        let pending = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try HTMLPreviewAssets(root: selection.item.url.deletingLastPathComponent(), access: selection.access)
        }
        return try await withTaskCancellationHandler { try await pending.value } onCancel: { pending.cancel() }
    }

    init(root: URL, access: DirectoryAccess? = nil) throws {
        guard root.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let descriptor = Darwin.open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw Self.posixError() }
        directory = descriptor
        self.access = access
    }

    deinit {
        Darwin.close(directory)
        withExtendedLifetime(access) {}
    }

    func read(_ encodedPath: String) throws -> Asset {
        try Task.checkCancellation()
        guard requests < Self.maximumRequests else { throw CocoaError(.fileReadTooLarge) }
        requests += 1
        guard encodedPath.hasPrefix("/") else { throw CocoaError(.fileReadNoPermission) }
        let components = try encodedPath.split(separator: "/").map { component in
            guard let decoded = String(component).removingPercentEncoding,
                  !decoded.isEmpty, decoded != ".", decoded != "..",
                  !decoded.contains("/"), !decoded.contains("\\"), !decoded.contains("\0") else {
                throw CocoaError(.fileReadNoPermission)
            }
            return decoded
        }
        guard let name = components.last else { throw CocoaError(.fileReadNoPermission) }
        let mimeType = try Self.mimeType(for: name)
        var descriptor = fcntl(directory, F_DUPFD_CLOEXEC, 0)
        guard descriptor >= 0 else { throw Self.posixError() }
        defer { Darwin.close(descriptor) }
        // Resolve every component beneath the opened root without following links or path replacements.
        for (index, component) in components.enumerated() {
            try Task.checkCancellation()
            let flags = O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC | (index == components.count - 1 ? 0 : O_DIRECTORY)
            let next = openat(descriptor, component, flags)
            guard next >= 0 else { throw Self.posixError() }
            Darwin.close(descriptor)
            descriptor = next
        }
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0 else { throw Self.posixError() }
        guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let remaining = Self.maximumTotalBytes - bytesRead
        guard attributes.st_size >= 0, attributes.st_size <= Self.maximumBytes,
              attributes.st_size <= remaining else { throw CocoaError(.fileReadTooLarge) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        let data = try handle.read(upToCount: min(Self.maximumBytes, remaining) + 1) ?? Data()
        try Task.checkCancellation()
        bytesRead += data.count
        guard data.count <= Self.maximumBytes, data.count <= remaining else { throw CocoaError(.fileReadTooLarge) }
        return Asset(data: data, mimeType: mimeType)
    }

    private static func mimeType(for name: String) throws -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "css": "text/css"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "svg": "image/svg+xml"
        case "webp": "image/webp"
        case "avif": "image/avif"
        case "heic", "heif": "image/heic"
        case "tif", "tiff": "image/tiff"
        case "bmp": "image/bmp"
        case "ico": "image/x-icon"
        case "woff": "font/woff"
        case "woff2": "font/woff2"
        case "ttf": "font/ttf"
        case "otf": "font/otf"
        case "ttc": "font/collection"
        default: throw CocoaError(.fileReadUnsupportedScheme)
        }
    }

    private static func posixError() -> POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}

@MainActor final class HTMLPreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "panepeek-html"
    let documentURL = URL(string: "panepeek-html://" + UUID().uuidString.lowercased() + "/index.html")!
    private let document: Data
    private var assets: HTMLPreviewAssets?
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(document: String, assets: HTMLPreviewAssets?) {
        self.document = Data(document.utf8)
        self.assets = assets
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, url.scheme == Self.scheme,
              url.host == documentURL.host, url.port == nil, url.user == nil, url.password == nil,
              urlSchemeTask.request.httpMethod == "GET" else {
            urlSchemeTask.didFailWithError(CocoaError(.fileReadNoPermission))
            return
        }
        let identity = ObjectIdentifier(urlSchemeTask)
        let document = document
        let isDocument = url.path == documentURL.path
        tasks[identity] = Task { [weak self, assets] in
            do {
                let asset: HTMLPreviewAssets.Asset
                if isDocument { asset = .init(data: document, mimeType: "text/html") }
                else if let assets { asset = try await assets.read(url.path(percentEncoded: true)) }
                else { throw CocoaError(.fileReadNoPermission) }
                guard let self, self.tasks.removeValue(forKey: identity) != nil, !Task.isCancelled else { return }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                    "Content-Type": asset.mimeType == "text/html" ? "text/html; charset=utf-8" : asset.mimeType,
                    "Content-Length": String(asset.data.count),
                    "Access-Control-Allow-Origin": "*",
                    "Cache-Control": "no-store",
                    "X-Content-Type-Options": "nosniff"
                ])!
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(asset.data)
                urlSchemeTask.didFinish()
            } catch {
                guard let self, self.tasks.removeValue(forKey: identity) != nil, !Task.isCancelled else { return }
                urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }

    func stop() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        assets = nil
    }
}
