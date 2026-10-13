import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor
struct WindowRecoveryTests {
    @Test(arguments: ["copy", "creation", "save"])
    func refreshesForeignPanesWithoutReplacingUnrelatedDrafts(action: String) async throws {
        let fixture = try RecoveryFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let draft = fixture.destination.appendingPathComponent("draft.txt")
        try Data("original".utf8).write(to: draft)
        let first = fixture.browser()
        let second = fixture.browser()
        await first.left.navigate(to: fixture.source)
        await first.right.navigate(to: fixture.destination)
        first.select([file], in: .left)
        await second.left.navigate(to: fixture.destination)
        second.select([draft], in: .left)
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("retained draft")?.value
        await second.left.sort(by: .name, direction: .descending)
        let revision = second.left.listingRevision
        switch action {
        case "copy": #expect(await first.copyToOtherPane(from: .left)?.succeeded == true)
        case "creation":
            await first.right.navigate(to: fixture.destination)
            first.focus(.right)
            first.beginCreation(.textFile)
            await first.submitCreation(named: "new.txt")
        default:
            await first.left.navigate(to: fixture.destination)
            first.select([draft], in: .left)
            await first.preview.load(first.detailsSelection)
            first.preview.setMode(.edit)
            await first.preview.updateText("saved by first")?.value
            #expect(await first.preview.save())
        }
        #expect(second.left.listingRevision != revision)
        if action != "save" {
            #expect(second.left.entries.contains { $0.name == (action == "copy" ? "source.txt" : "new.txt") })
        }
        await second.preview.load(second.detailsSelection)
        #expect(second.preview.isDirty && second.preview.text == "retained draft")
        #expect(second.left.selectedItems == [draft] && second.left.sortDirection == .descending)
        if action == "save" {
            #expect(!second.preview.isSaving)
            #expect(await second.preview.save() == false)
            #expect(try Data(contentsOf: draft) == Data("saved by first".utf8))
        }
    }

    @Test(arguments: ["rename", "move"])
    func followsForeignDescendantsAndRetainsCachedPathsWhenRefreshFails(action: String) async throws {
        let fixture = try RecoveryFixture()
        defer { fixture.remove() }
        let folder = fixture.source.appendingPathComponent("folder", isDirectory: true)
        let child = folder.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let file = child.appendingPathComponent("file.txt")
        try Data("original".utf8).write(to: file)
        let first = fixture.browser()
        let second = fixture.browser(load: { url in
            if !url.path.hasPrefix(folder.path) { throw CocoaError(.fileReadNoPermission) }
            return try await DirectoryListing.read(url)
        })
        await first.left.navigate(to: fixture.source)
        await first.right.navigate(to: fixture.destination)
        first.select([folder], in: .left)
        await second.left.navigate(to: child)
        second.select([file], in: .left)
        if action == "rename" {
            await first.beginRename()
            #expect(await first.submitRename(named: "renamed") != nil)
        } else { #expect(await first.moveToOtherPane(from: .left)?.succeeded == true) }
        let newFolder = action == "rename" ? fixture.source.appendingPathComponent("renamed") : fixture.destination.appendingPathComponent("folder")
        #expect(second.left.directory.path == newFolder.appendingPathComponent("child").path)
        #expect(second.left.entries.map(\.url.path) == [newFolder.appendingPathComponent("child/file.txt").path])
        #expect(second.left.selectedItems.map(\.path) == [newFolder.appendingPathComponent("child/file.txt").path])
        #expect(second.left.errorMessage != nil)
        #expect(first.renameError != nil || first.moveOutcome?.message.contains("refresh") == true)
    }

    @Test(arguments: [BrowserState.DropOperation.copy, .move])
    func acceptsCrossWindowDragWithoutRedirectingItsCapturedDestination(operation: BrowserState.DropOperation) async throws {
        let fixture = try RecoveryFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let first = fixture.browser()
        let second = fixture.browser()
        await first.left.navigate(to: fixture.source)
        first.select([file], in: .left)
        await second.left.navigate(to: fixture.destination)
        let exported = try #require(first.beginDrag(in: .left, items: [file]))
        let transfer = try #require(second.submitDrop(exported, into: .left, operation: operation))
        first.endDrag(external: true)
        #expect(first.dragNotice == nil)
        await second.left.navigate(to: fixture.source)
        await transfer.value
        #expect(second.left.directory == fixture.source)
        #expect(FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("source.txt").path))
        if operation == .move { #expect(first.left.entries.isEmpty) }
        else { #expect(second.copyOutcome?.succeeded == true) }
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel], [false, true])
    func foreignDirtyContainerMustBeResolvedBeforeOutgoingDrag(choice: BrowserState.UnsavedChoice, failedSave: Bool) async throws {
        let fixture = try RecoveryFixture()
        defer { fixture.remove() }
        let folder = fixture.source.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let file = folder.appendingPathComponent("child.txt")
        try Data("original".utf8).write(to: file)
        let first = fixture.browser()
        var prompts = 0
        let second = fixture.browser(confirmChanges: { _, answer in prompts += 1; answer(choice) })
        await first.left.navigate(to: fixture.source)
        first.select([folder], in: .left)
        await second.left.navigate(to: folder)
        second.select([file], in: .left)
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("foreign draft")?.value
        if failedSave { try Data("external".utf8).write(to: file) }
        #expect(first.beginDrag(in: .left, items: [folder]) == nil)
        try await waitForRecovery { !fixture.operations.isBusy }
        #expect(prompts == 1 && !first.isDragging)
        if choice == .cancel || (choice == .save && failedSave) {
            #expect(second.preview.isDirty && second.preview.text == "foreign draft")
        } else {
            #expect(!second.preview.isDirty)
            #expect(first.beginDrag(in: .left, items: [folder]) == [folder])
            #expect(!second.preview.canEdit && !second.preview.canSave)
            #expect(!second.canRename() && !second.canTrash() && !second.canCopy(in: .left))
            first.endDrag()
            #expect(second.preview.canEdit)
        }
    }

    @Test func trashRecoversForeignDescendantToNearestAccessibleParent() async throws {
        let fixture = try RecoveryFixture()
        defer { fixture.remove() }
        let folder = fixture.source.appendingPathComponent("folder", isDirectory: true)
        let child = folder.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let first = BrowserState(operations: fixture.operations, trash: { item in
            do {
                try FileManager.default.moveItem(at: item.source, to: fixture.destination.appendingPathComponent("trashed"))
                return ItemTrash.Outcome(succeeded: true, sourceRemoved: true, message: "fixture removal")
            } catch { return ItemTrash.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription) }
        }, confirmTrash: { _, answer in answer(true) })
        fixture.operations.register(first)
        let second = fixture.browser(load: { url in
            if url == fixture.source { throw CocoaError(.fileReadNoPermission) }
            return try await DirectoryListing.read(url)
        })
        await first.left.navigate(to: fixture.source)
        first.select([folder], in: .left)
        await second.left.navigate(to: child)
        #expect(await first.moveToTrash()?.succeeded == true)
        #expect(second.left.directory.path == fixture.root.path)
        #expect(second.left.recoveryMessage?.contains("The browsed folder was trashed") == true)
        #expect(first.trashOutcome?.message.contains("The browsed folder was trashed") == true)
        #expect(second.left.entries.allSatisfy { !$0.url.path.hasPrefix(folder.path) })
    }

    @Test func movedFolderInvalidatesAForeignPendingReadEvenInAHiddenPane() async throws {
        let fixture = try RecoveryFixture()
        defer { fixture.remove() }
        let folder = fixture.source.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let file = folder.appendingPathComponent("child.txt")
        try Data("original".utf8).write(to: file)
        let gate = RecoveryReadGate()
        let first = fixture.browser()
        let second = fixture.browser(load: { url in
            let listing = try await DirectoryListing.read(url)
            if url.path == folder.path { await gate.hold() }
            return listing
        })
        await first.left.navigate(to: fixture.source)
        await first.right.navigate(to: fixture.destination)
        first.select([folder], in: .left)
        second.setMode(.onePane)
        let oldRead = Task { await second.right.navigate(to: folder) }
        defer { Task { await gate.release() } }
        try await gate.waitUntilStarted()
        #expect(await first.moveToOtherPane(from: .left)?.succeeded == true)
        let moved = fixture.destination.appendingPathComponent("folder")
        #expect(second.right.directory.path == moved.path)
        await gate.release()
        await oldRead.value
        #expect(second.right.directory.path == moved.path)
        #expect(second.right.entries.map(\.url.path) == [moved.appendingPathComponent("child.txt").path])
        #expect(second.mode == .onePane && second.focusedPane == .left)
    }
}

@MainActor private func waitForRecovery(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
    try #require(condition())
}

@MainActor private struct RecoveryFixture {
    let root: URL
    let source: URL
    let destination: URL
    let operations = FileOperationCoordinator()

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-window-recovery-" + UUID().uuidString)
        source = root.appendingPathComponent("source", isDirectory: true)
        destination = root.appendingPathComponent("destination", isDirectory: true)
        for directory in [source, destination] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }

    func file(_ name: String) throws -> URL {
        let file = source.appendingPathComponent(name)
        try Data("original".utf8).write(to: file)
        return file
    }

    func browser(load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read,
                 confirmChanges: @escaping @MainActor (String, @escaping @MainActor (BrowserState.UnsavedChoice) -> Void) -> Void = { _, answer in answer(.cancel) }) -> BrowserState {
        let browser = BrowserState(load: load, operations: operations, confirmMove: { _, answer in answer(true) }, confirmChanges: confirmChanges)
        operations.register(browser)
        return browser
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

private actor RecoveryReadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    func hold() async { await withCheckedContinuation { continuation = $0 } }
    func waitUntilStarted() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while continuation == nil && ContinuousClock.now < deadline { await Task.yield() }
        try #require(continuation != nil)
    }
    func release() { continuation?.resume(); continuation = nil }
}
