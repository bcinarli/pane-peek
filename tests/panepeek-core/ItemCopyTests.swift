import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite struct ItemCopyTests {
    @Test(arguments: ["file", "folder", "package", "link", "broken-link", "directory-link"])
    func copiesContentsAndListedLinksWithoutChangingSources(kind: String) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = fixture.source.appendingPathComponent(kind == "package" ? "sample.app" : "sample")
        let target = try fixture.file("target.txt")
        if kind == "folder" || kind == "package" {
            try FileManager.default.createDirectory(at: source.appendingPathComponent("nested"), withIntermediateDirectories: true)
            try Data("nested contents".utf8).write(to: source.appendingPathComponent("nested/child.txt"))
            try FileManager.default.createSymbolicLink(atPath: source.appendingPathComponent("nested/link").path,
                                                     withDestinationPath: "child.txt")
        } else if kind.contains("link") {
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath:
                kind == "broken-link" ? "missing" : (kind == "directory-link" ? fixture.destination.path : "target.txt"))
        } else { try Data("contents 👀".utf8).write(to: source) }
        let identity = try fixture.identity(source)
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let result = await request.copy()
        #expect(result.succeeded)
        #expect(try fixture.identity(source) == identity)
        #expect(try Data(contentsOf: target) == Data("original".utf8))
        let copied = request.destination
        #expect((try? fixture.identity(copied)) != nil)
        if kind == "folder" || kind == "package" {
            #expect((try? Data(contentsOf: copied.appendingPathComponent("nested/child.txt"))) == Data("nested contents".utf8))
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: copied.appendingPathComponent("nested/link").path)) == "child.txt")
        } else if kind.contains("link") {
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: copied.path))
                    == (try FileManager.default.destinationOfSymbolicLink(atPath: source.path)))
        } else { #expect((try? Data(contentsOf: copied)) == Data("contents 👀".utf8)) }
    }

    @Test(arguments: ["file", "folder", "broken-link"])
    func knownCollisionsRejectWithoutMutation(kind: String) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("occupied")
        let occupied = fixture.destination.appendingPathComponent("occupied")
        if kind == "folder" { try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: false) }
        else if kind == "broken-link" { try FileManager.default.createSymbolicLink(atPath: occupied.path, withDestinationPath: "missing") }
        else { try Data("destination".utf8).write(to: occupied) }
        let before = try fixture.identity(occupied)
        await #expect(throws: ItemName.ValidationError.collision) { try await ItemCopy.capture(source, to: fixture.destination) }
        #expect(try fixture.identity(occupied) == before)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test func rejectsSameItemAndSymlinkResolvedDescendants() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("same.txt")
        await #expect(throws: ItemName.ValidationError.collision) { try await ItemCopy.capture(source, to: fixture.source) }
        let child = fixture.source.appendingPathComponent("nested/child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let directory = fixture.source.appendingPathComponent("nested", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: child.path)
        for destination in [directory, child, alias] {
            await #expect(throws: ItemCopy.CopyError.ancestry) { try await ItemCopy.capture(directory, to: destination) }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: child.path).isEmpty)
    }

    @Test(arguments: [false, true])
    func rejectsReplacedSourceOrDestination(destinationChanged: Bool) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let replaced = destinationChanged ? fixture.destination : source
        try FileManager.default.moveItem(at: replaced, to: fixture.root.appendingPathComponent("old"))
        if destinationChanged { try FileManager.default.createDirectory(at: replaced, withIntermediateDirectories: false) }
        else { try Data("replacement".utf8).write(to: replaced) }
        let outcome = await request.copy()
        #expect(!outcome.succeeded)
        #expect(!FileManager.default.fileExists(atPath: request.destination.path))
    }

    @Test func lateDirectoryCollisionNeverMergesOrOverwrites() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = fixture.source.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        try Data("source".utf8).write(to: source.appendingPathComponent("child.txt"))
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let outcome = await request.copy(using: { source, destination in
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            try Data("winner".utf8).write(to: destination.appendingPathComponent("child.txt"))
            try FileManager.default.copyItem(at: source, to: destination)
        })
        #expect(!outcome.succeeded)
        #expect((try? Data(contentsOf: request.destination.appendingPathComponent("child.txt"))) == Data("winner".utf8))
        #expect(try Data(contentsOf: source.appendingPathComponent("child.txt")) == Data("source".utf8))
    }

    @Test func reportsFailedCopyAndAnIncompleteDestination() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let outcome = await request.copy(using: { _, destination in
            try Data("partial".utf8).write(to: destination)
            throw POSIXError(.ENOSPC)
        })
        #expect(!outcome.succeeded)
        #expect(outcome.message.contains(source.path) && outcome.message.contains(request.destination.path))
        #expect(outcome.message.contains("incomplete"))
        #expect((try? Data(contentsOf: request.destination)) == Data("partial".utf8))
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }
}

@Suite @MainActor struct BrowserCopyTests {
    @Test(arguments: [PaneID.left, .right])
    func copiesInEitherDirectionAndRefreshesWithoutChangingSelection(from: PaneID) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        let destinationID: PaneID = from == .left ? .right : .left
        await browser.pane(from).refresh()
        await browser.pane(destinationID).navigate(to: fixture.destination)
        browser.select([source], in: from)
        let sourceRevision = browser.pane(from).listingRevision
        let targetRevision = browser.pane(destinationID).listingRevision
        let outcome = await browser.copyToOtherPane(from: from)
        #expect(outcome?.succeeded == true)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data("original".utf8))
        #expect(browser.pane(from).selectedItems == [source] && browser.focusedPane == from)
        #expect(browser.pane(from).listingRevision != sourceRevision && browser.pane(destinationID).listingRevision != targetRevision)
    }

    @Test(arguments: [false, true])
    func capturedTargetsSurviveNavigationAndLayoutWhileDuplicateMutationsAreRejected(saveDraft: Bool) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let gate = CopyGate()
        let browser = BrowserState(homeDirectory: fixture.source, copy: { operation in
            await gate.pause()
            return await operation.copy()
        }, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        if saveDraft { await browser.preview.updateText("saved draft")?.value }
        let copying = Task { await browser.copyToOtherPane(from: .left) }
        try await waitForCopy { browser.isCopying }
        await gate.waitForRequest()
        #expect(browser.isCopying && !browser.canCopy(in: .left) && !browser.canRename())
        #expect(!browser.preview.canEdit)
        browser.beginCreation(.folder)
        #expect(browser.creationRequest == nil)
        #expect(await browser.copyToOtherPane(from: .left) == nil)
        await browser.navigate(to: fixture.root, in: .right)
        let revision = browser.right.listingRevision
        browser.setMode(.onePane)
        #expect(await browser.copyToOtherPane(from: .right) == nil)
        await gate.finish()
        let outcome = await copying.value
        #expect(outcome?.succeeded == true && !browser.isCopying)
        #expect(browser.right.directory == fixture.root && browser.right.listingRevision == revision)
        #expect(browser.mode == .onePane && browser.focusedPane == .right)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data((saveDraft ? "saved draft" : "original").utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("source.txt").path))
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func dirtyChoicesResolveBeforeCopy(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in prompts += 1; answer(choice) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        let outcome = await browser.copyToOtherPane(from: .left)
        #expect(prompts == 1)
        if choice == .cancel {
            #expect(outcome == nil && browser.preview.isDirty && browser.preview.text == "draft")
            #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("source.txt").path))
        } else {
            #expect(outcome?.succeeded == true && !browser.preview.isDirty)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
        #expect(try Data(contentsOf: source) == Data((choice == .save ? "draft" : "original").utf8))
    }

    @Test(arguments: [false, true])
    func failedSaveOrPreflightRetainsTheDraft(preflight: Bool) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        if preflight { try Data("occupied".utf8).write(to: fixture.destination.appendingPathComponent("source.txt")) }
        let preview = PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) })
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, preview: preview,
                                   confirmChanges: { _, answer in prompts += 1; answer(.save) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        let outcome = await browser.copyToOtherPane(from: .left)
        #expect(outcome?.succeeded != true)
        #expect(prompts == (preflight ? 0 : 1))
        #expect(preview.isDirty && preview.text == "draft" && preview.canEdit)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        if !preflight { #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("source.txt").path)) }
    }

    @Test func staleMenuSinglePaneAndMultipleSelectionCannotCopy() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let first = try fixture.file("first.txt")
        let second = try fixture.file("second.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([first], in: .left)
        #expect(browser.canCopy(in: .left))
        browser.select([second], in: .left)
        #expect(await browser.copyToOtherPane(from: .left, item: first) == nil)
        browser.select([first, second], in: .left)
        #expect(!browser.canCopy(in: .left))
        #expect(await browser.copyToOtherPane(from: .left) == nil)
        browser.select([first], in: .left)
        browser.setMode(.onePane)
        #expect(!browser.canCopy(in: .left) && !browser.canCopy(in: .right))
        #expect(await browser.copyToOtherPane(from: .left) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func completionRefreshRetainsAnUnrelatedDraftWithoutPrompting() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let other = try fixture.file("other.txt")
        let gate = CopyGate()
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, copy: { operation in
            await gate.pause()
            return await operation.copy()
        }, confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        let copying = Task { await browser.copyToOtherPane(from: .left) }
        try await waitForCopy { browser.isCopying }
        await gate.waitForRequest()
        browser.select([other], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("unrelated draft")?.value
        let document = browser.preview.documentID
        let revision = browser.left.listingRevision
        await gate.finish()
        let result = await copying.value
        #expect(result?.succeeded == true && prompts == 0)
        #expect(browser.preview.documentID == document && browser.preview.isDirty && browser.preview.text == "unrelated draft")
        #expect(browser.left.listingRevision != revision && browser.left.primaryItemURL == other)
    }

    @Test func successfulCopyWithFailedRefreshReportsActualDiskSuccess() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let reads = CopyReadGate()
        let browser = BrowserState(homeDirectory: fixture.source, load: { try await reads.read($0) }, copy: { operation in
            let result = await operation.copy()
            await reads.fail()
            return result
        })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        let outcome = await browser.copyToOtherPane(from: .left)
        #expect(outcome?.succeeded == true)
        #expect(outcome?.message.contains("refresh") == true)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data("original".utf8))
        #expect(browser.left.selectedItems == [source] && browser.right.directory == fixture.destination)
    }
}

@MainActor private func waitForCopy(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
}

private actor CopyGate {
    private var entered = false
    private var waiting: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    func pause() async {
        entered = true
        waiting?.resume(); waiting = nil
        await withCheckedContinuation { release = $0 }
    }
    func waitForRequest() async {
        if !entered { await withCheckedContinuation { waiting = $0 } }
    }
    func finish() { release?.resume(); release = nil }
}

private actor CopyReadGate {
    private var failed = false
    func fail() { failed = true }
    func read(_ directory: URL) async throws -> DirectoryListing {
        if failed { throw POSIXError(.EACCES) }
        return try await DirectoryListing.read(directory)
    }
}

private struct CopyFixture: Sendable {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    var source: URL { root.appendingPathComponent("source", isDirectory: true) }
    var destination: URL { root.appendingPathComponent("destination", isDirectory: true) }
    init() throws {
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
    }
    func file(_ name: String) throws -> URL {
        let url = source.appendingPathComponent(name)
        try Data("original".utf8).write(to: url)
        return url
    }
    func identity(_ url: URL) throws -> ino_t {
        var attributes = stat()
        guard lstat(url.path, &attributes) == 0 else { throw POSIXError(.ENOENT) }
        return attributes.st_ino
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
