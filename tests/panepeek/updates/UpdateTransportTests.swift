import Foundation
import Testing
@testable import PanePeek

@Suite(.serialized) struct UpdateTransportTests {
    @Test func requestsUseFixedMetadataWithoutCookiesOrCredentials() async throws {
        UpdateURLProtocol.respond = { request in
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "PanePeek-Updates")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "")
            #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return (200, Data("hello".utf8), [:])
        }
        let result = try await UpdateTransport(protocolClasses: [UpdateURLProtocol.self]).fetch(.metadata)
        #expect(result.data == Data("hello".utf8))
        #expect(result.digest == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    @Test func streamedResponsesRespectSizeAndCompletionBounds() async throws {
        UpdateURLProtocol.respond = { _ in (200, Data(repeating: 1, count: 20), [:]) }
        let transport = UpdateTransport(protocolClasses: [UpdateURLProtocol.self])
        await #expect(throws: (any Error).self) { try await transport.fetch(.metadata, maximumBytes: 10) }
        await #expect(throws: (any Error).self) { try await transport.fetch(.metadata, expectedBytes: 30) }
        UpdateURLProtocol.respond = { _ in (429, Data(), ["Retry-After": "3600"]) }
        do { _ = try await transport.fetch(.metadata); Issue.record("Expected rate limit") }
        catch UpdateError.rateLimited(let date) { #expect(date > Date().addingTimeInterval(3500)) }
    }

    @Test func downloadsStreamToAFileAndCancellationStopsAPendingRequest() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("payload.partial")
        let bytes = Data(repeating: 7, count: 100_000)
        UpdateURLProtocol.respond = { _ in (200, bytes, [:]) }
        let result = try await UpdateTransport(protocolClasses: [UpdateURLProtocol.self]).fetch(.metadata, to: file, expectedBytes: Int64(bytes.count))
        let saved = try Data(contentsOf: file)
        #expect(result.data.isEmpty && saved == bytes)

        let started = AsyncStream<Void>.makeStream()
        PendingUpdateProtocol.started = { started.continuation.yield(()); started.continuation.finish() }
        let operation = Task { try await UpdateTransport(protocolClasses: [PendingUpdateProtocol.self]).fetch(.metadata) }
        for await _ in started.stream { break }
        operation.cancel()
        await #expect(throws: CancellationError.self) { try await operation.value }
    }

    @Test func redirectsStayWithinTheExpectedDownloadHostAndCount() throws {
        let good = try #require(URL(string: "https://release-assets.githubusercontent.com/github-production-release-asset/test?sig=public"))
        #expect(UpdateRoute.download(URL(string: "https://github.com/bcinarli/pane-peek/releases/download/v1.2.0/file.dmg")!).allows(good, redirect: 1))
        #expect(!UpdateRoute.metadata.allows(good, redirect: 1))
        for value in ["http://release-assets.githubusercontent.com/x", "https://example.org/file", "https://user:pass@release-assets.githubusercontent.com/x", "https://release-assets.githubusercontent.com:444/x", "https://github.com/other/project/file"] {
            #expect(!UpdateRoute.download(good).allows(URL(string: value)!, redirect: 1))
        }
        #expect(!UpdateRoute.download(good).allows(good, redirect: 4))
    }
}

private final class UpdateURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: ((URLRequest) -> (Int, Data, [String: String]))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data, headers) = Self.respond(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class PendingUpdateProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var started: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.started?() }
    override func stopLoading() { }
}
