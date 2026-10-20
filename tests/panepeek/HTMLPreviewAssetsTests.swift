import Darwin
import Foundation
import Synchronization
import Testing
import WebKit
import PanePeekCore
@testable import PanePeek

struct HTMLPreviewAssetsTests {
    @Test func directoryDescriptorKeepsItsRootAndRejectsLinksEscapeAndSpecialFiles() async throws {
        let fixture = try HTMLAssetsFixture()
        defer { fixture.finish() }
        let root = fixture.root.appendingPathComponent("site")
        let outside = fixture.root.appendingPathComponent("outside")
        for directory in [root, outside, root.appendingPathComponent("styles")] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try Data("original".utf8).write(to: root.appendingPathComponent("styles/main.css"))
        try Data("outside".utf8).write(to: outside.appendingPathComponent("secret.css"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.css"), withDestinationURL: outside.appendingPathComponent("secret.css"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked"), withDestinationURL: outside)
        try #require(mkfifo(root.appendingPathComponent("pipe.css").path, 0o600) == 0)
        let assets = try HTMLPreviewAssets(root: root)
        for path in ["/link.css", "/linked/secret.css", "/../outside/secret.css", "/%2e%2e/outside/secret.css", "/styles%2f..%2fsecret.css", "/styles/%00.css", "/pipe.css", "/missing.css", "/script.js", "/page.html", "/movie.mp4"] {
            await #expect(throws: (any Error).self) { _ = try await assets.read(path) }
        }
        try FileManager.default.moveItem(at: root, to: fixture.root.appendingPathComponent("original-site"))
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: outside)
        let original = try await assets.read("/styles/main.css")
        #expect(original.data == Data("original".utf8) && original.mimeType == "text/css")
    }

    @Test func assetByteAndRequestBudgetsAreBounded() async throws {
        let fixture = try HTMLAssetsFixture()
        defer { fixture.finish() }
        let large = fixture.root.appendingPathComponent("large.png")
        try Data().write(to: large)
        let handle = try FileHandle(forWritingTo: large)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(HTMLPreviewAssets.maximumBytes + 1))
        let oversized = try HTMLPreviewAssets(root: fixture.root)
        await #expect(throws: (any Error).self) { _ = try await oversized.read("/large.png") }
        try handle.truncate(atOffset: UInt64(HTMLPreviewAssets.maximumBytes))
        let bytes = try HTMLPreviewAssets(root: fixture.root)
        for _ in 0..<(HTMLPreviewAssets.maximumTotalBytes / HTMLPreviewAssets.maximumBytes) {
            #expect(try await bytes.read("/large.png").data.count == HTMLPreviewAssets.maximumBytes)
        }
        await #expect(throws: (any Error).self) { _ = try await bytes.read("/large.png") }
        try Data("body {}".utf8).write(to: fixture.root.appendingPathComponent("small.css"))
        let requests = try HTMLPreviewAssets(root: fixture.root)
        for _ in 0..<HTMLPreviewAssets.maximumRequests { _ = try await requests.read("/small.css") }
        await #expect(throws: (any Error).self) { _ = try await requests.read("/small.css") }
    }

    @Test @MainActor func stoppedSchemeRequestsDoNotCallbackAndReleaseTheirFolderGrant() async throws {
        let fixture = try HTMLAssetsFixture()
        defer { fixture.finish() }
        let released = Mutex(0)
        let (events, source) = AsyncStream<Void>.makeStream()
        defer { source.finish() }
        var iterator = events.makeAsyncIterator()
        var assets: HTMLPreviewAssets? = try HTMLPreviewAssets(root: fixture.root, access: DirectoryAccess(root: fixture.root) {
            released.withLock { $0 += 1 }
            source.yield(())
        })
        let handler = HTMLPreviewSchemeHandler(document: "<p>Draft</p>", assets: assets)
        assets = nil
        #expect(released.withLock { $0 } == 0)
        let view = WKWebView()
        let task = HTMLSchemeRequest(url: handler.documentURL.appendingPathComponent("missing.css"))
        handler.webView(view, start: task)
        handler.webView(view, stop: task)
        handler.stop()
        let deadline = Task {
            do { try await Task.sleep(for: .seconds(5)); source.finish() } catch {}
        }
        defer { deadline.cancel() }
        _ = await iterator.next()
        #expect(released.withLock { $0 } == 1 && task.callbacks == 0)
    }
}

@MainActor private final class HTMLSchemeRequest: NSObject, @MainActor WKURLSchemeTask {
    let request: URLRequest
    private(set) var callbacks = 0
    init(url: URL) { request = URLRequest(url: url); super.init() }
    func didReceive(_ response: URLResponse) { callbacks += 1 }
    func didReceive(_ data: Data) { callbacks += 1 }
    func didFinish() { callbacks += 1 }
    func didFailWithError(_ error: any Error) { callbacks += 1 }
}

private struct HTMLAssetsFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-html-files-" + UUID().uuidString)
    init() throws { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    func finish() { try? FileManager.default.removeItem(at: root) }
}
