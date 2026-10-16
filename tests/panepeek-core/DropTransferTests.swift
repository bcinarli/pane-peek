import Foundation
import Testing
@testable import PanePeekCore

@MainActor struct DropTransferTests {
    @Test(arguments: [PaneID.left, .right])
    func copiesExternalSelectionIntoTheVisibleSingleBrowser(target: PaneID) async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let browser = BrowserState(homeDirectory: fixture.destination)
        await browser.left.refresh()
        await browser.right.refresh()
        browser.focus(target)
        browser.setMode(.onePane)
        let task = browser.submitDrop(sources, into: target, operation: .copy)
        #expect(task != nil && browser.isCopying)
        await task?.value
        #expect(browser.copyOutcome?.succeeded == true)
        #expect(browser.copyOutcome?.completed.count == sources.count)
        #expect(try String(contentsOf: fixture.destination.appendingPathComponent("space ü.txt"), encoding: .utf8) == "original")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.destination.appendingPathComponent("link").path) == "space ü.txt")
        #expect(sources.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        #expect(browser.pane(target).entries.count == sources.count)
        #expect(browser.mode == .onePane && browser.focusedPane == target)
    }

    @Test func rejectsHiddenInvalidAndDuplicateSubmissionsBeforeWork() async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let browser = BrowserState(homeDirectory: fixture.destination)
        browser.setMode(.onePane)
        #expect(browser.submitDrop(sources, into: .right, operation: .copy) == nil)
        #expect(browser.submitDrop([], into: .left, operation: .copy) == nil)
        #expect(browser.submitDrop([sources[0], URL(string: "https://example.com/file")!], into: .left, operation: .copy) == nil)
        #expect(browser.submitDrop([URL(string: "file://server/share/file")!], into: .left, operation: .move) == nil)
        let task = browser.submitDrop(sources, into: .left, operation: .copy)
        #expect(task != nil)
        #expect(browser.submitDrop(sources, into: .left, operation: .move) == nil)
        #expect(!browser.canRename() && !browser.canTrash())
        await task?.value
    }

    @Test func capturesDestinationBeforeQueuedWorkAndLaterNavigation() async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let browser = BrowserState(homeDirectory: fixture.destination)
        await browser.left.refresh()
        let task = browser.submitDrop(sources, into: .left, operation: .copy)
        await browser.navigate(to: fixture.other, in: .left)
        browser.setMode(.onePane)
        await task?.value
        #expect(browser.copyOutcome?.succeeded == true)
        #expect(FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("space ü.txt").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.other.path).isEmpty)
        #expect(browser.left.directory.path == fixture.other.path)
    }

    @Test func movesIncomingSelectionDirectlyToItsCapturedDestination() async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let browser = BrowserState(homeDirectory: fixture.destination)
        await browser.left.refresh()
        browser.setMode(.onePane)
        let moving = browser.submitDrop(sources, into: .left, operation: .move)
        await browser.navigate(to: fixture.other, in: .left)
        await moving?.value
        #expect(browser.moveOutcome?.succeeded == true)
        #expect(browser.moveOutcome?.completed.map(\.lastPathComponent) == sources.map(\.lastPathComponent))
        #expect(sources.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).count == sources.count)
        #expect(browser.left.directory.path == fixture.other.path && browser.left.entries.isEmpty)
    }

    @Test func knownCollisionRejectsTheWholeIncomingBatch() async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let winner = fixture.destination.appendingPathComponent("folder")
        try Data("winner".utf8).write(to: winner)
        let browser = BrowserState(homeDirectory: fixture.destination)
        await browser.submitDrop(sources, into: .left, operation: .copy)?.value
        #expect(browser.copyOutcome?.succeeded == false && browser.copyOutcome?.completed.isEmpty == true)
        #expect(try Data(contentsOf: winner) == Data("winner".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path) == ["folder"])
    }

    @Test func copyFailureRetainsCompletedFailedAndUnattemptedPaths() async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let browser = BrowserState(homeDirectory: fixture.destination, copy: { item in
            if item.source.lastPathComponent == "folder" { return ItemCopy.Outcome(succeeded: false, message: "Injected copy failure", failed: item.source) }
            return await item.copy()
        })
        await browser.left.refresh()
        await browser.submitDrop(sources, into: .left, operation: .copy)?.value
        #expect(browser.copyOutcome?.completed.map(\.lastPathComponent) == ["space ü.txt"])
        #expect(browser.copyOutcome?.failed?.lastPathComponent == "folder")
        #expect(browser.copyOutcome?.unattempted.map(\.lastPathComponent) == ["link"])
        #expect(browser.left.entries.map(\.name) == ["space ü.txt"])
    }

    @Test(arguments: [BrowserState.DropOperation.copy, .move], [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func affectedDirtySourceIsResolvedBeforeAnyIncomingMutation(operation: BrowserState.DropOperation, choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.destination, confirmChanges: { _, answer in
            prompts += 1
            #expect((try? FileManager.default.contentsOfDirectory(atPath: fixture.destination.path))?.isEmpty == true)
            answer(choice)
        })
        await browser.right.navigate(to: fixture.source)
        browser.select([sources[0]], in: .right)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.submitDrop(sources, into: .left, operation: operation)?.value
        #expect(prompts == 1)
        if choice == .cancel {
            #expect(browser.preview.isDirty && browser.preview.text == "draft")
            #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
        } else {
            let copied = fixture.destination.appendingPathComponent("space ü.txt")
            #expect(try String(contentsOf: copied, encoding: .utf8) == (choice == .save ? "draft" : "original"))
            if operation == .move { #expect(browser.preview.selection == nil) }
        }
    }

    @Test(arguments: [BrowserState.DropOperation.copy, .move])
    func failedSaveAbortsIncomingBatchAndRetainsDraft(operation: BrowserState.DropOperation) async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let browser = BrowserState(homeDirectory: fixture.destination, confirmChanges: { _, answer in answer(.save) })
        await browser.right.navigate(to: fixture.source)
        browser.select([sources[0]], in: .right)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        try Data("external change".utf8).write(to: sources[0])
        await browser.submitDrop(sources, into: .left, operation: operation)?.value
        #expect(browser.preview.isDirty && browser.preview.text == "draft")
        #expect(browser.preview.errorMessage != nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func incomingMoveRecoversBrowsersInsideAnUnlistedSourceFolder() async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let sources = try fixture.sources()
        let browser = BrowserState(homeDirectory: fixture.destination)
        await browser.right.navigate(to: sources[1])
        await browser.submitDrop([sources[1]], into: .left, operation: .move)?.value
        #expect(browser.moveOutcome?.succeeded == true)
        #expect(browser.right.directory.path == fixture.destination.appendingPathComponent("folder").path)
        #expect(browser.right.entries.map(\.name) == ["child.txt"])
    }

    @Test(arguments: ["package", "directory-link", "broken-link"])
    func movedExternalItemsKeepTheirClassificationWhenRefreshFails(kind: String) async throws {
        let fixture = try DropFixture()
        defer { fixture.remove() }
        let source = fixture.source.appendingPathComponent(kind == "package" ? "Sample.app" : kind)
        if kind == "package" {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        } else {
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: kind == "directory-link" ? fixture.other.path : "missing")
        }
        let browser = BrowserState(homeDirectory: fixture.destination, load: { _ in throw CocoaError(.fileReadNoPermission) })
        await browser.submitDrop([source], into: .left, operation: .move)?.value
        #expect(browser.moveOutcome?.succeeded == true && browser.moveOutcome?.message.contains("refresh") == true)
        let entry = try #require(browser.left.entries.first)
        #expect(entry.isPackage == (kind == "package"))
        #expect(entry.isSymbolicLink == (kind != "package"))
        #expect(entry.isDirectory == (kind == "directory-link"))
    }
}

private struct DropFixture {
    let root: URL
    let source: URL
    let destination: URL
    let other: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-drop-\(UUID())")
        source = root.appendingPathComponent("source")
        destination = root.appendingPathComponent("destination")
        other = root.appendingPathComponent("other")
        for directory in [source, destination, other] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    func sources() throws -> [URL] {
        let file = source.appendingPathComponent("space ü.txt")
        let folder = source.appendingPathComponent("folder")
        let link = source.appendingPathComponent("link")
        try Data("original".utf8).write(to: file)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: folder.appendingPathComponent("child.txt"))
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "space ü.txt")
        return [file, folder, link]
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
