import Foundation
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1))) @MainActor
struct OperationAvailabilityTests {
    private let allActions: Set<String> = ["copy", "move", "duplicate", "trash", "rename", "create", "drop"]

    @Test(arguments: [BrowserMode.onePane, .twoPanes], [0, 1, 2])
    func visiblePaneAndSelectionDetermineAvailableActions(mode: BrowserMode, count: Int) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let files = try [fixture.file("first.txt"), fixture.file("second.txt")]
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.setMode(mode)
        browser.select(Set(files.prefix(count)), in: .left)
        var expected: Set<String> = ["create", "drop"]
        if count > 0 { expected.formUnion(["duplicate", "trash"]) }
        if count == 1 { expected.insert("rename") }
        if count > 0 && mode == .twoPanes { expected.formUnion(["copy", "move"]) }
        #expect(availableActions(browser, in: .left) == expected)
        if mode == .onePane { #expect(availableActions(browser, in: .right).isEmpty) }
    }

    @Test(arguments: ["rename", "create"])
    func aNamingPromptExcludesItsWindowAndCancellationRestoresIt(action: String) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let first = BrowserState(homeDirectory: fixture.source)
        let second = BrowserState(homeDirectory: fixture.source, operations: first.operations)
        for browser in [first, second] {
            first.operations.register(browser)
            try await fixture.prepare(browser, selecting: file)
        }
        if action == "rename" { await first.beginRename() }
        else { first.beginCreation(.folder) }
        #expect(first.renameRequest != nil || first.creationRequest != nil)
        #expect(availableActions(first).isEmpty)
        #expect(availableActions(second) == allActions)
        first.cancelRename()
        first.cancelCreation()
        #expect(availableActions(first) == allActions)
    }

    @Test(arguments: [false, true])
    func operationAndSaveExcludeBothWindowsAndRejectStaleCommands(saving: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let other = try fixture.file("other.txt")
        try await withOperationGate { gate in
            let preview = PreviewState(write: { snapshot, text, url in
                try await gate.pause()
                return try await snapshot.save(text, to: url)
            })
            let first = BrowserState(homeDirectory: fixture.source, preview: preview, copy: { item in
                do { try await gate.pause(); return await item.copy() }
                catch { return ItemCopy.Outcome(succeeded: false, message: error.localizedDescription) }
            })
            let second = BrowserState(homeDirectory: fixture.source, operations: first.operations)
            for (browser, source) in [(first, file), (second, other)] {
                first.operations.register(browser)
                try await fixture.prepare(browser, selecting: source, dirty: saving && browser === first)
            }
            let operation = Task {
                if saving { return await first.preview.save() }
                return await first.copyToOtherPane(from: .left)?.succeeded == true
            }
            gate.track(operation)
            try await gate.waitForRequest()
            #expect(availableActions(first).isEmpty && availableActions(second).isEmpty)
            #expect(await second.copyToOtherPane(from: .left) == nil)
            #expect(await second.moveToOtherPane(from: .left) == nil)
            #expect(await second.duplicate(from: .left) == nil)
            #expect(await second.moveToTrash() == nil)
            await second.beginRename()
            second.beginCreation(.folder)
            #expect(second.renameRequest == nil && second.creationRequest == nil)
            #expect(second.submitDrop([other], into: .right, operation: .copy) == nil)
            #expect(second.beginDrag(in: .left, items: [other]) == nil)
            try await gate.finish()
            #expect(await operation.value)
            #expect(availableActions(first) == allActions && availableActions(second) == allActions)
            #expect(try Data(contentsOf: other) == Data("original".utf8))
        }
    }

    @Test func aPendingDirtyTransitionAllowsRenamePreparationButRejectsSubmission() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let first = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, completion in answer = completion })
        let second = BrowserState(homeDirectory: fixture.source, operations: first.operations)
        for browser in [first, second] {
            first.operations.register(browser)
            try await fixture.prepare(browser, selecting: file, dirty: browser === first)
        }
        #expect(!first.resolveChangesIfNeeded())
        let completion = try #require(answer)
        defer { completion(.cancel) }
        #expect(availableActions(first) == ["rename"])
        #expect(availableActions(second) == allActions)
        await first.preview.updateText("original")?.value
        #expect(!first.preview.isDirty && availableActions(first) == ["rename"])
        await first.beginRename()
        try #require(first.renameRequest != nil)
        #expect(await first.submitRename(named: "renamed.txt") == nil)
        #expect(try Data(contentsOf: file) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.source.appendingPathComponent("renamed.txt").path))
        completion(.cancel)
        #expect(availableActions(first) == allActions)
    }

    @Test func capturedDragRetainsOnlyItsMatchingDropRouteAcrossWindows() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("source.txt")
        let other = try fixture.file("other.txt")
        let first = BrowserState(homeDirectory: fixture.source)
        let second = BrowserState(homeDirectory: fixture.source, operations: first.operations)
        for (browser, source) in [(first, file), (second, other)] {
            first.operations.register(browser)
            try await fixture.prepare(browser, selecting: source)
        }
        try #require(first.beginDrag(in: .left, items: [file]) == [file])
        defer { first.endDrag() }
        for browser in [first, second] {
            #expect(availableActions(browser) == ["drop"])
            #expect(browser.canReceiveDrop(into: .right, sources: [file]))
            #expect(!browser.canReceiveDrop(into: .right, sources: [other]))
        }
        first.endDrag()
        #expect(availableActions(first) == allActions && availableActions(second) == allActions)
    }

    private func availableActions(_ browser: BrowserState, in pane: PaneID = .left) -> Set<String> {
        Set([("copy", browser.canCopy(in: pane)), ("move", browser.canMove(in: pane)),
             ("duplicate", browser.canDuplicate(in: pane)), ("trash", browser.canTrash(in: pane)),
             ("rename", browser.canRename(in: pane)), ("create", browser.canCreate(in: pane)),
             ("drop", browser.canReceiveDrop(into: pane))].filter { $0.1 }.map { $0.0 })
    }
}
