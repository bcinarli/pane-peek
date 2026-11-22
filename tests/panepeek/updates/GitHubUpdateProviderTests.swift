import Foundation
import Synchronization
import Testing
@testable import PanePeek

@MainActor @Suite(.serialized) struct GitHubUpdateProviderTests {
    @Test(arguments: ["1.1.0", "1.2.0"])
    func repeatedChecksReuseSuccessfulCurrentAndAvailableResults(version: String) async throws {
        let requests = Mutex(0)
        ProviderURLProtocol.respond = { _ in
            requests.withLock { $0 += 1 }
            return (200, Self.release(version: version), [:])
        }
        let provider = try provider()
        let first = try await provider.check()
        let repeated = try await provider.check()
        #expect(first == repeated)
        #expect((first == nil) == (version == "1.1.0"))
        #expect(requests.withLock { $0 } == 1)
    }

    @Test(arguments: ["beta.2", "rc.1"], [13, 15])
    func installedPrereleaseAppearsInSuccessfulUpdateDialogs(suffix: String, releaseBuild: Int) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-update-\(UUID()).bundle")
        let contents = root.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let metadata = ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "13",
                        "PanePeekPrereleaseSuffix": suffix, "PanePeekUpdateChannel": "github"]
        let plist = try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: root))
        let preferences = try #require(UserDefaults(suiteName: root.lastPathComponent))
        defer { preferences.removePersistentDomain(forName: root.lastPathComponent) }
        ProviderURLProtocol.respond = { _ in (200, Self.release(version: "1.3.0", build: releaseBuild), [:]) }
        let updates = UpdateComposition.make(in: bundle, preferences: preferences,
                                             transport: UpdateTransport(protocolClasses: [ProviderURLProtocol.self]))
        updates.check()
        await updates.operation?.value
        let window = UpdateWindow(updates: updates, bundle: bundle)
        defer { window.close() }

        let installed = "1.3.0-\(suffix) (13)"
        if releaseBuild > 13 {
            #expect(updates.phase == .available)
            #expect(window.heading.stringValue == "PanePeek 1.3.0 (15) is available")
            #expect(window.message.stringValue == "Installed version: \(installed)")
        } else {
            #expect(updates.phase == .current)
            #expect(window.message.stringValue == "PanePeek \(installed) is installed. No newer version is available.")
        }
        #expect(window.message.accessibilityValue() == window.message.stringValue)
    }

    @Test func failedChecksCanBeRetriedWithoutBecomingACachedCurrentResult() async throws {
        let requests = Mutex(0)
        ProviderURLProtocol.respond = { _ in
            let count = requests.withLock { $0 += 1; return $0 }
            return (200, count == 1 ? Data("invalid".utf8) : Self.release(version: "1.2.0"), [:])
        }
        let provider = try provider()
        do { _ = try await provider.check(); Issue.record("Expected invalid metadata") }
        catch UpdateError.invalidRelease {}
        let offer = try await provider.check()
        #expect(offer?.version == "1.2.0")
        #expect(requests.withLock { $0 } == 2)
    }

    @Test func expiredResultsRefreshAndServerBackoffStillApplies() async throws {
        var time = Date()
        let requests = Mutex(0)
        ProviderURLProtocol.respond = { _ in
            let count = requests.withLock { $0 += 1; return $0 }
            if count == 2 { return (429, Data(), ["Retry-After": "3600"]) }
            return (200, Self.release(version: count == 1 ? "1.1.0" : "1.2.0"), [:])
        }
        let provider = try provider(now: { time })
        #expect(try await provider.check() == nil)
        time = time.addingTimeInterval(60)
        do { _ = try await provider.check(); Issue.record("Expected server rate limit") }
        catch UpdateError.rateLimited {}
        do { _ = try await provider.check(); Issue.record("Expected retained server backoff") }
        catch UpdateError.rateLimited {}
        #expect(requests.withLock { $0 } == 2)
        time = time.addingTimeInterval(3600)
        #expect(try await provider.check()?.version == "1.2.0")
        #expect(requests.withLock { $0 } == 3)
    }

    @Test func cancellationDoesNotReturnACachedSuccess() async throws {
        let requests = Mutex(0)
        ProviderURLProtocol.respond = { _ in
            requests.withLock { $0 += 1 }
            return (200, Self.release(version: "1.2.0"), [:])
        }
        let provider = try provider()
        _ = try await provider.check()
        let operation = Task { try await provider.check() }
        operation.cancel()
        await #expect(throws: CancellationError.self) { try await operation.value }
        #expect(requests.withLock { $0 } == 1)
    }

    private func provider(now: @escaping () -> Date = Date.init) throws -> GitHubUpdateProvider {
        GitHubUpdateProvider(installed: try #require(ReleaseVersion("1.1.0", build: 9)),
            transport: UpdateTransport(protocolClasses: [ProviderURLProtocol.self]),
            storage: UpdateStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)), now: now)
    }

    nonisolated private static func release(version: String, build: Int = 9) -> Data {
        Data("""
        {"id":123,"tag_name":"v\(version)","draft":false,"prerelease":false,
         "published_at":"2026-10-20T12:00:00Z",
         "html_url":"https://github.com/bcinarli/pane-peek/releases/tag/v\(version)",
         "assets":[{"name":"PanePeek-\(version)-build\(build)-macos-arm64.dmg","size":3723956,
         "digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
         "browser_download_url":"https://github.com/bcinarli/pane-peek/releases/download/v\(version)/PanePeek-\(version)-build\(build)-macos-arm64.dmg"}]}
        """.utf8)
    }
}

private final class ProviderURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: (@Sendable (URLRequest) -> (Int, Data, [String: String]))!
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
