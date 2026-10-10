import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct PreviewTests {
    @Test func utf8BOMAndEmptyFilesPreserveTextAndNewlines() async throws {
        let fixture = try PreviewFixture()
        defer { fixture.remove() }
        let text = "Türkçe 👀\r\nsecond\nthird\rfourth"
        for (name, bytes, expected) in [
            ("plain.txt", Data(text.utf8), text),
            ("bom.txt", Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8), text),
            ("empty.txt", Data(), ""),
            ("bom-only.txt", Data([0xEF, 0xBB, 0xBF]), "")
        ] {
            let item = try fixture.write(name, bytes: bytes)
            #expect(try await TextPreview.read(item) == .text(expected))
            #expect(try Data(contentsOf: item.url) == bytes)
        }
    }

    @Test func actualBytesRespectTheLimitIncludingBOMAndMultibyteCharacters() async throws {
        let fixture = try PreviewFixture()
        defer { fixture.remove() }
        let limit = TextPreview.maximumBytes
        let text = String(repeating: "é", count: limit / 2)
        let exact = try fixture.write("exact.txt", bytes: Data(text.utf8))
        #expect(try await TextPreview.read(exact) == .text(text))
        let oversized = try fixture.write("oversized.txt", bytes: Data(text.utf8) + Data([0x61]))
        #expect(try await TextPreview.read(oversized) == .unavailable(.tooLarge))
        let bom = Data([0xEF, 0xBB, 0xBF])
        let bomText = String(repeating: "a", count: limit - bom.count)
        let exactBOM = try fixture.write("exact-bom.txt", bytes: bom + Data(bomText.utf8))
        #expect(try await TextPreview.read(exactBOM) == .text(bomText))
        let oversizedBOM = try fixture.write("oversized-bom.txt", bytes: bom + Data(bomText.utf8) + Data([0x61]))
        #expect(try await TextPreview.read(oversizedBOM) == .unavailable(.tooLarge))
    }

    @Test func binaryAndInvalidUTF8DoNotDecodeWithReplacementCharacters() async throws {
        let fixture = try PreviewFixture()
        defer { fixture.remove() }
        for (name, bytes, reason): (String, Data, TextPreview.UnavailableReason) in [
            ("nul.txt", Data([0x61, 0x00, 0x62]), .binary),
            ("invalid.txt", Data([0xC3, 0x28]), .invalidUTF8),
            ("truncated.txt", Data([0xEF, 0xBB, 0xBF, 0xE2, 0x82]), .invalidUTF8)
        ] {
            #expect(try await TextPreview.read(fixture.write(name, bytes: bytes)) == .unavailable(reason))
        }
    }

    @Test func foldersPackagesAndSpecialFilesAreUnavailableAndTextLinksReadTheirTargets() async throws {
        let fixture = try PreviewFixture()
        defer { fixture.remove() }
        let files = FileManager.default
        let text = try fixture.write("target.txt", bytes: Data("linked text".utf8))
        for (name, target) in [("relative-link", text.url.lastPathComponent), ("absolute-link", text.url.path)] {
            let link = fixture.root.appendingPathComponent(name)
            try files.createSymbolicLink(atPath: link.path, withDestinationPath: target)
            #expect(try await TextPreview.read(DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: true)) == .text("linked text"))
        }
        for (name, package) in [("folder", false), ("Example.app", true)] {
            let directory = fixture.root.appendingPathComponent(name, isDirectory: true)
            try files.createDirectory(at: directory, withIntermediateDirectories: false)
            let item = DirectoryEntry(url: directory, isDirectory: !package, isPackage: package)
            #expect(try await TextPreview.read(item) == .unavailable(package ? .package : .folder))
            // A stale row or retargeted link must not open a directory as text.
            let stale = DirectoryEntry(url: directory, isDirectory: false)
            #expect(try await TextPreview.read(stale) == .unavailable(package ? .package : .folder))
        }
        let fifo = fixture.root.appendingPathComponent("named-pipe")
        try #require(mkfifo(fifo.path, 0o600) == 0)
        #expect(try await TextPreview.read(DirectoryEntry(url: fifo, isDirectory: false)) == .unavailable(.nonRegularFile))
        let broken = fixture.root.appendingPathComponent("broken-link")
        try files.createSymbolicLink(atPath: broken.path, withDestinationPath: "missing.txt")
        await #expect(throws: (any Error).self) {
            try await TextPreview.read(DirectoryEntry(url: broken, isDirectory: false, isSymbolicLink: true))
        }
    }

    @Test(arguments: [false, true]) @MainActor
    func olderSuccessOrFailureCannotReplaceTheLatestPreview(olderFails: Bool) async throws {
        let gate = PreviewGate()
        let state = PreviewState(read: { try await gate.read($0) })
        let first = previewSelection("first.txt")
        let second = previewSelection("second.txt")
        let oldRead = Task { await state.load(first) }
        try await gate.waitForRequest(0)
        let newRead = Task { await state.load(second) }
        try await gate.waitForRequest(1)
        try await gate.finish(1, result: .success(.text("second")))
        await newRead.value
        try await gate.finish(0, result: olderFails ? .failure(CocoaError(.fileReadNoPermission)) : .success(.text("first")))
        await oldRead.value
        #expect(state.selection == second && state.preview == .text("second"))
        #expect(state.errorMessage == nil && !state.isLoading)
    }

    @Test @MainActor func clearNewSelectionAndFailureCannotLeaveOldContent() async throws {
        let gate = PreviewGate()
        let state = PreviewState(read: { try await gate.read($0) })
        let pending = Task { await state.load(previewSelection("first.txt")) }
        try await gate.waitForRequest(0)
        await state.load(nil)
        try await gate.finish(0, result: .success(.text("first")))
        await pending.value
        #expect(state.selection == nil && state.preview == nil && !state.isLoading)

        let good = Task { await state.load(previewSelection("second.txt")) }
        try await gate.waitForRequest(1)
        try await gate.finish(1, result: .success(.text("second")))
        await good.value
        let failing = Task { await state.load(previewSelection("missing.txt")) }
        try await gate.waitForRequest(2)
        #expect(state.preview == nil && state.errorMessage == nil && state.isLoading)
        try await gate.finish(2, result: .failure(CocoaError(.fileReadNoPermission)))
        await failing.value
        #expect(state.preview == nil && state.errorMessage != nil && !state.isLoading)
    }

    @Test @MainActor func cancellationDoesNotPublishAndTheSameSelectionCanRetry() async throws {
        let gate = PreviewGate()
        let state = PreviewState(read: { try await gate.read($0) })
        let selection = previewSelection("file.txt")
        let cancelled = Task { await state.load(selection) }
        try await gate.waitForRequest(0)
        cancelled.cancel()
        try await gate.finish(0, result: .success(.text("cancelled")))
        await cancelled.value
        #expect(state.preview == nil && state.errorMessage == nil && !state.isLoading)
        let retry = Task { await state.load(selection) }
        try await gate.waitForRequest(1)
        try await gate.finish(1, result: .success(.text("retried")))
        await retry.value
        #expect(state.preview == .text("retried"))
    }

    @Test(arguments: [false, true]) @MainActor
    func staleHighlightSuccessOrFailureCannotReplaceTheNewFile(olderFails: Bool) async throws {
        let gate = PreviewGate()
        let state = PreviewState(
            read: { .text($0.name == "first.swift" ? "let first" : "true") },
            highlight: { text, fileExtension in
                _ = try await gate.read(DirectoryEntry(url: URL(fileURLWithPath: "/preview/file.\(fileExtension)"), isDirectory: false))
                return [SyntaxToken(range: NSRange(location: 0, length: text.utf16.count),
                                    kind: fileExtension == "swift" ? .keyword : .literal)]
            }
        )
        let old = Task { await state.load(previewSelection("first.swift")) }
        try await gate.waitForRequest(0)
        let latest = Task { await state.load(previewSelection("second.json")) }
        try await gate.waitForRequest(1)
        try await gate.finish(1, result: .success(.text("release")))
        await latest.value
        try await gate.finish(0, result: olderFails ? .failure(CocoaError(.fileReadUnknown)) : .success(.text("release")))
        await old.value
        #expect(state.preview == .text("true"))
        #expect(state.tokens == [SyntaxToken(range: NSRange(location: 0, length: 4), kind: .literal)])
        #expect(state.errorMessage == nil && !state.isLoading)
    }

    @Test @MainActor func plainOrClearedSelectionRemovesHighlighting() async {
        let state = PreviewState(read: { _ in .text("let value") })
        await state.load(previewSelection("colour.swift"))
        #expect(state.tokens == [SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)])
        await state.load(previewSelection("plain.txt"))
        #expect(state.preview == .text("let value") && state.tokens.isEmpty)
        await state.load(nil)
        #expect(state.preview == nil && state.tokens.isEmpty)
    }

    @Test @MainActor func refreshRereadsTheSameFileAndFocusedPaneSuppliesItsPrimary() async throws {
        let fixture = try PreviewFixture()
        defer { fixture.remove() }
        let file = try fixture.write("same.txt", bytes: Data("before".utf8))
        let other = try fixture.write("other.txt", bytes: Data("other".utf8))
        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: file.url.path)
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.navigate(to: fixture.root)
        await browser.right.navigate(to: fixture.root)
        browser.left.setSelection([file.url])
        browser.right.setSelection([file.url, other.url], focusedItem: other.url)
        let state = PreviewState()
        await state.load(browser.detailsSelection)
        #expect(state.preview == .text("before"))
        let listing = browser.left.entries
        try Data("after!".utf8).write(to: file.url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: file.url.path)
        await browser.left.refresh()
        #expect(browser.left.entries == listing)
        await state.load(browser.detailsSelection)
        #expect(state.preview == .text("after!"))
        browser.focus(.right)
        await state.load(browser.detailsSelection)
        #expect(state.preview == .text("other"))
        browser.right.setSelection([])
        await state.load(browser.detailsSelection)
        #expect(state.preview == nil)
    }
}

private func previewSelection(_ name: String) -> DetailsSelection {
    DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview/\(name)"), isDirectory: false), listingRevision: UUID())
}

private struct PreviewFixture {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-preview-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }
    func write(_ name: String, bytes: Data) throws -> DirectoryEntry {
        let url = root.appendingPathComponent(name)
        try bytes.write(to: url)
        return DirectoryEntry(url: url, isDirectory: false)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}

private actor PreviewGate {
    private var nextID = 0
    private var requests: [Int: CheckedContinuation<TextPreview, any Error>] = [:]
    private var observers: [Int: CheckedContinuation<Void, any Error>] = [:]
    private var deadline: Task<Void, Never>?
    private var failure: CocoaError?

    deinit { deadline?.cancel() }

    func read(_ item: DirectoryEntry) async throws -> TextPreview {
        if let failure { throw failure }
        let id = nextID
        nextID += 1
        startDeadline()
        return try await withCheckedThrowingContinuation {
            requests[id] = $0
            observers.removeValue(forKey: id)?.resume()
        }
    }

    func waitForRequest(_ id: Int) async throws {
        if let failure { throw failure }
        if requests[id] != nil { return }
        startDeadline()
        try await withCheckedThrowingContinuation { observers[id] = $0 }
    }

    func finish(_ id: Int, result: Result<TextPreview, any Error>) throws {
        guard let request = requests.removeValue(forKey: id) else { throw CocoaError(.coderValueNotFound) }
        request.resume(with: result)
    }

    private func startDeadline() {
        guard deadline == nil else { return }
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            await self?.expire()
        }
    }

    private func expire() {
        deadline = nil
        guard !requests.isEmpty || !observers.isEmpty else { return }
        let error = CocoaError(.coderValueNotFound)
        failure = error
        Issue.record("Preview gate timed out: reads \(requests.keys.sorted()), observers \(observers.keys.sorted())")
        for request in requests.values { request.resume(throwing: error) }
        for observer in observers.values { observer.resume(throwing: error) }
        requests.removeAll()
        observers.removeAll()
    }
}
