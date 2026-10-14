import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor
struct OperationCoordinationTests {
    @Test(arguments: ["move", "trash"])
    func confirmationLocksEveryAffectedEditorAndCancellationReleasesThem(action: String) async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let unrelated = try fixture.file("unrelated.txt")
        let operations = FileOperationCoordinator()
        var answer: (@MainActor (Bool) -> Void)?
        let first = BrowserState(operations: operations,
            confirmMove: { _, completion in answer = completion },
            confirmTrash: { _, completion in answer = completion })
        let second = BrowserState(operations: operations)
        let third = BrowserState(operations: operations)
        for (browser, item) in [(first, file), (second, file), (third, unrelated)] {
            try await fixture.prepare(browser, selecting: item)
            await browser.preview.load(browser.detailsSelection)
            browser.preview.setMode(.edit)
            #expect(browser.preview.canEdit)
        }
        let mutation = Task {
            if action == "move" { _ = await first.moveToOtherPane(from: .left) }
            else { _ = await first.moveToTrash() }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while answer == nil && ContinuousClock.now < deadline { await Task.yield() }
        let completion = try #require(answer)
        defer { completion(false) }
        #expect(!first.preview.canEdit && !second.preview.canEdit)
        #expect(!first.preview.canSave && !second.preview.canSave)
        #expect(third.preview.canEdit && !third.preview.canSave)
        #expect([first, second, third].allSatisfy { !$0.canCreate() })
        let edit = second.preview.updateText("blocked edit")
        #expect(edit == nil)
        await edit?.value
        #expect(second.preview.text == "original")
        completion(false)
        await mutation.value
        #expect(operations.canMutate)
        #expect([first, second, third].allSatisfy { $0.canCreate() })
        #expect([first, second, third].allSatisfy { $0.preview.canEdit && $0.preview.canSave })
        #expect(try Data(contentsOf: file) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func constructingAnUnattachedBrowserCannotInvalidateAPendingOperation() async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations)
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let second = BrowserState(operations: operations, confirmChanges: { _, completion in answer = completion })
        try await fixture.prepare(first, selecting: file)
        try await fixture.prepare(second, selecting: file)
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("foreign draft")?.value
        let copy = Task { await first.copyToOtherPane(from: .left) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while answer == nil && ContinuousClock.now < deadline { await Task.yield() }
        let completion = try #require(answer)
        let unattached = BrowserState(operations: operations)
        completion(.discard)
        #expect(await copy.value?.succeeded == true)
        #expect(unattached.preview.selection == nil)
    }

    @Test(arguments: [false, true])
    func laterCancelOrFailedSaveRetainsAllDraftsAndAbortsCopy(failedSave: Bool) async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations, confirmChanges: { _, completion in completion(.discard) })
        let secondPreview = PreviewState(write: { _, _, _ in throw CocoaError(.fileWriteNoPermission) })
        let second = BrowserState(operations: operations, preview: secondPreview, confirmChanges: { _, completion in
            completion(failedSave ? .save : .cancel)
        })
        for browser in [first, second] {
            try await fixture.prepare(browser, selecting: file)
            await browser.preview.load(browser.detailsSelection)
            browser.preview.setMode(.edit)
            await browser.preview.updateText(browser === first ? "first draft" : "second draft")?.value
        }
        #expect(await first.copyToOtherPane(from: .left) == nil)
        #expect(first.preview.isDirty && first.preview.text == "first draft")
        #expect(second.preview.isDirty && second.preview.text == "second draft")
        #expect((second.preview.errorMessage != nil) == failedSave)
        #expect(!operations.isBusy)
        #expect(try Data(contentsOf: file) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("source.txt").path))
    }

    @Test func foreignSaveUpdatesCapturedSourceAndCopyUsesSavedBytes() async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations)
        let second = BrowserState(operations: operations, confirmChanges: { _, completion in completion(.save) })
        try await fixture.prepare(first, selecting: file)
        try await fixture.prepare(second, selecting: file)
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("saved draft")?.value
        #expect(await first.copyToOtherPane(from: .left)?.succeeded == true)
        #expect(!second.preview.isDirty && second.preview.text == "saved draft")
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("source.txt")) == Data("saved draft".utf8))
    }

    @Test(arguments: ["rename", "move", "trash"], [false, true])
    func successfulSourceRemovalClosesForeignEditor(action: String, directory: Bool) async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file: URL
        let source: URL
        if directory {
            source = fixture.source.appendingPathComponent("folder", isDirectory: true)
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
            file = source.appendingPathComponent("child.txt")
            try Data("original".utf8).write(to: file)
        } else {
            file = try fixture.file("source.txt")
            source = file
        }
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations, confirmMove: { _, completion in completion(true) },
            trash: { item in
                do {
                    try FileManager.default.moveItem(at: item.source, to: fixture.destination.appendingPathComponent("trashed.txt"))
                    return ItemTrash.Outcome(succeeded: true, sourceRemoved: true, message: "removed in fixture")
                } catch { return ItemTrash.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription) }
            }, confirmTrash: { _, completion in completion(true) })
        let second = BrowserState(operations: operations, confirmChanges: { _, completion in completion(.discard) })
        try await fixture.prepare(first, selecting: source)
        operations.register(second)
        await second.left.navigate(to: file.deletingLastPathComponent())
        second.left.setSelection([file])
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("foreign draft")?.value
        switch action {
        case "rename":
            await first.beginRename()
            #expect(await first.submitRename(named: "renamed.txt") != nil)
        case "move": #expect(await first.moveToOtherPane(from: .left)?.succeeded == true)
        default: #expect(await first.moveToTrash()?.succeeded == true)
        }
        #expect(second.preview.selection == nil && !second.preview.isDirty && !second.preview.canEdit)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func copyingListedLinkRetainsItsTargetsForeignDraft() async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let target = try fixture.file("target.txt")
        let link = fixture.source.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "target.txt")
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations)
        var prompts = 0
        let second = BrowserState(operations: operations, confirmChanges: { _, completion in prompts += 1; completion(.cancel) })
        try await fixture.prepare(first, selecting: link)
        try await fixture.prepare(second, selecting: target)
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("target draft")?.value
        #expect(await first.copyToOtherPane(from: .left)?.succeeded == true)
        #expect(prompts == 0 && second.preview.isDirty && second.preview.text == "target draft")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.destination.appendingPathComponent("link.txt").path) == "target.txt")
        #expect(try Data(contentsOf: target) == Data("original".utf8))
    }

    @Test(arguments: ["rename", "move", "trash"])
    func failedSourceMutationRetainsForeignDiscardedDraft(action: String) async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations, rename: { _, _ in throw CocoaError(.fileWriteNoPermission) },
            move: { _ in ItemMove.Outcome(succeeded: false, sourceRemoved: false, message: "fixture failure") },
            confirmMove: { _, completion in completion(true) },
            trash: { _ in ItemTrash.Outcome(succeeded: false, sourceRemoved: false, message: "fixture failure") },
            confirmTrash: { _, completion in completion(true) })
        let second = BrowserState(operations: operations, confirmChanges: { _, completion in completion(.discard) })
        try await fixture.prepare(first, selecting: file)
        try await fixture.prepare(second, selecting: file)
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("foreign draft")?.value
        switch action {
        case "rename":
            await first.beginRename()
            #expect(await first.submitRename(named: "renamed.txt") == nil)
        case "move": #expect(await first.moveToOtherPane(from: .left)?.succeeded == false)
        default: #expect(await first.moveToTrash()?.succeeded == false)
        }
        #expect(second.preview.isDirty && second.preview.text == "foreign draft" && second.preview.canSave)
        #expect(!operations.isBusy)
        #expect(try Data(contentsOf: file) == Data("original".utf8))
    }

    @Test func partialMoveClosesOnlyCompletedForeignDocuments() async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let files = try ["a.txt", "b.txt", "c.txt"].map { try fixture.file($0) }
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations, move: { item in
            if item.source.lastPathComponent == "b.txt" {
                return ItemMove.Outcome(succeeded: false, sourceRemoved: false, message: "fixture failure")
            }
            return await item.move()
        }, confirmMove: { _, completion in completion(true) })
        try await fixture.prepare(first, selecting: files[0])
        first.left.setSelection(Set(files))
        var editors: [BrowserState] = []
        for file in files {
            let editor = BrowserState(operations: operations, confirmChanges: { _, completion in completion(.discard) })
            try await fixture.prepare(editor, selecting: file)
            await editor.preview.load(editor.detailsSelection)
            editor.preview.setMode(.edit)
            await editor.preview.updateText(file.lastPathComponent + " draft")?.value
            editors.append(editor)
        }
        let result = try #require(await first.moveToOtherPane(from: .left))
        #expect(!result.succeeded && result.relocated.map(\.source) == [files[0]])
        #expect(result.failed == files[1] && result.unattempted == [files[2]])
        #expect(editors[0].preview.selection == nil && !editors[0].preview.isDirty)
        for editor in editors {
            #expect(editor.left.entries.map(\.url) == Array(files.dropFirst()))
            #expect(editor.right.entries.map(\.name) == ["a.txt"])
        }
        for index in [1, 2] {
            #expect(editors[index].preview.isDirty && editors[index].preview.canSave)
            #expect(editors[index].preview.text == files[index].lastPathComponent + " draft")
            #expect(try Data(contentsOf: files[index]) == Data("original".utf8))
        }
    }

    @Test func anotherWindowsDirtyCancelAbortsCopyBeforeMutation() async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        var prompts = 0
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations)
        let second = BrowserState(operations: operations, confirmChanges: { _, completion in prompts += 1; completion(.cancel) })
        try await fixture.prepare(first, selecting: file)
        try await fixture.prepare(second, selecting: file)
        await second.preview.load(second.detailsSelection)
        second.preview.setMode(.edit)
        await second.preview.updateText("second draft")?.value

        let result = await first.copyToOtherPane(from: .left)
        #expect(result == nil)
        #expect(prompts == 1)
        #expect(second.preview.isDirty && second.preview.text == "second draft")
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("source.txt").path))
        #expect(try Data(contentsOf: file) == Data("original".utf8))
    }

    @Test(arguments: [false, true])
    func pendingCopyExcludesAnotherWindowsRenameOrSave(saving: Bool) async throws {
        let fixture = try CoordinationFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let gate = CoordinationGate()
        let operations = FileOperationCoordinator()
        let first = BrowserState(operations: operations, copy: { item in await gate.hold(); return await item.copy() })
        let second = BrowserState(operations: operations)
        try await fixture.prepare(first, selecting: file)
        let secondFile = saving ? try fixture.file("unrelated.txt") : file
        try await fixture.prepare(second, selecting: secondFile)
        await second.preview.load(second.detailsSelection)
        if saving {
            second.preview.setMode(.edit)
            await second.preview.updateText("second draft")?.value
        }
        let copy = Task { await first.copyToOtherPane(from: .left) }
        defer { Task { await gate.release() } }
        try await gate.waitUntilStarted()
        if saving {
            #expect(await second.preview.save() == false)
            #expect(second.preview.isDirty)
            #expect(second.preview.canEdit && !second.preview.canSave)
        } else {
            #expect(!second.preview.canEdit)
            await second.beginRename()
            #expect(await second.submitRename(named: "renamed.txt") == nil)
        }
        #expect(try Data(contentsOf: file) == Data("original".utf8))
        await gate.release()
        #expect(await copy.value?.succeeded == true)
    }
}

@MainActor private struct CoordinationFixture {
    let root: URL
    let source: URL
    let destination: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-coordination-" + UUID().uuidString)
        source = root.appendingPathComponent("source", isDirectory: true)
        destination = root.appendingPathComponent("destination", isDirectory: true)
        for directory in [source, destination] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }

    func file(_ name: String) throws -> URL {
        let file = source.appendingPathComponent(name)
        try Data("original".utf8).write(to: file)
        return file
    }

    func prepare(_ browser: BrowserState, selecting item: URL) async throws {
        browser.operations.register(browser)
        await browser.left.navigate(to: source)
        await browser.right.navigate(to: destination)
        browser.left.setSelection([item])
        #expect(browser.left.selectedItems == [item])
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

private actor CoordinationGate {
    private var continuation: CheckedContinuation<Void, Never>?
    func hold() async { await withCheckedContinuation { continuation = $0 } }
    func waitUntilStarted() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while continuation == nil && ContinuousClock.now < deadline { await Task.yield() }
        guard continuation != nil else { throw CocoaError(.coderValueNotFound) }
    }
    func release() { continuation?.resume(); continuation = nil }
}
