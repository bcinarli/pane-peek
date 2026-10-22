import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct BrowserFileCommandsTests {
    private let copy = NSSelectorFromString("copy:")
    private let cut = NSSelectorFromString("cut:")
    private let paste = NSSelectorFromString("paste:")
    private let move = NSSelectorFromString("moveItemHere:")
    private let trash = NSSelectorFromString("moveSelectionToTrash:")

    @Test(arguments: ["copy", "cut", "move"])
    func sameFolderPasteNumbersOnlyCopies(command: String) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("report.txt")
        try Data("original".utf8).write(to: source)
        let browser = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        browser.setMode(.onePane)
        browser.select([source], in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        coordinator.table.filePasteboard = board
        coordinator.table.perform(command == "cut" ? cut : copy, with: nil)
        coordinator.table.perform(command == "move" ? move : paste, with: nil)
        try await wait { !browser.isCopying && !browser.isMoving }
        let duplicate = root.appendingPathComponent("report (2).txt")
        if command == "copy" {
            #expect(browser.copyOutcome?.succeeded == true)
            #expect((try? Data(contentsOf: duplicate)) == Data("original".utf8))
        } else {
            #expect(browser.moveOutcome?.succeeded == false && browser.copyOutcome == nil)
            #expect(!FileManager.default.fileExists(atPath: duplicate.path))
        }
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(FileDrop.sources(from: board) == [source])
    }

    @Test func copiesListedSelectionAsFileURLsAndLeavesClipboardAloneWithoutSelection() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("space ü.txt")
        let link = root.appendingPathComponent("link")
        try Data("contents".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        let browser = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        browser.select([file, link], in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        coordinator.table.filePasteboard = board
        try #require(coordinator.table.responds(to: copy), "Browser selection must handle the native Copy command")
        #expect(enabled(copy, in: coordinator.table))
        coordinator.table.perform(copy, with: nil)
        let expected = browser.left.entries.filter { browser.left.selectedItems.contains($0.url) }.map(\.url)
        #expect(FileDrop.sources(from: board) == expected)
        #expect(try Data(contentsOf: file) == Data("contents".utf8))
        let revision = board.changeCount
        browser.select([], in: .left)
        #expect(!enabled(copy, in: coordinator.table))
        #expect(!enabled(cut, in: coordinator.table))
        coordinator.table.perform(copy, with: nil)
        coordinator.table.perform(cut, with: nil)
        #expect(board.changeCount == revision)
    }

    @Test(arguments: [false, true])
    func pastesIntoCapturedSinglePaneDirectoryAndRejectsDuplicateSubmission(moving: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        let later = root.appendingPathComponent("later")
        for directory in [destination, later] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let source = root.appendingPathComponent("source.txt")
        try Data("clipboard transfer".utf8).write(to: source)
        let browser = BrowserState(homeDirectory: destination)
        await browser.left.refresh()
        browser.setMode(.onePane)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.writeObjects([source as NSURL])
        coordinator.table.filePasteboard = board
        let action = moving ? move : paste
        try #require(coordinator.table.responds(to: action), "Browser must handle clipboard transfers")
        #expect(enabled(action, in: coordinator.table))
        coordinator.table.perform(action, with: nil)
        #expect(!enabled(action, in: coordinator.table))
        coordinator.table.perform(action, with: nil)
        await browser.navigate(to: later, in: .left)
        try await wait { !browser.isCopying && !browser.isMoving }
        #expect(moving ? browser.moveOutcome?.succeeded == true : browser.copyOutcome?.succeeded == true)
        #expect(try Data(contentsOf: destination.appendingPathComponent("source.txt")) == Data("clipboard transfer".utf8))
        #expect(!FileManager.default.fileExists(atPath: later.appendingPathComponent("source.txt").path))
        #expect(FileManager.default.fileExists(atPath: source.path) == !moving)
    }

    @Test func rejectsTextMixedClipboardAndHiddenPaneWithoutMutation() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let browser = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        coordinator.table.filePasteboard = board
        try #require(coordinator.table.responds(to: paste))
        board.setString("/some/path.txt", forType: .string)
        #expect(!enabled(paste, in: coordinator.table) && !enabled(move, in: coordinator.table))
        coordinator.table.perform(paste, with: nil)
        #expect(!browser.isCopying && browser.copyOutcome == nil)
        board.clearContents()
        let source = root.appendingPathComponent("source.txt")
        try Data().write(to: source)
        let text = NSPasteboardItem()
        text.setString("text", forType: .string)
        board.writeObjects([source as NSURL, text])
        #expect(!enabled(paste, in: coordinator.table))
        coordinator.table.perform(paste, with: nil)
        #expect(!browser.isCopying && browser.copyOutcome == nil)
        board.clearContents()
        board.writeObjects([source as NSURL])
        browser.focus(.right)
        browser.setMode(.onePane)
        #expect(!enabled(paste, in: coordinator.table) && !enabled(move, in: coordinator.table))
        coordinator.table.perform(move, with: nil)
        #expect(!browser.isMoving && browser.moveOutcome == nil)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test(arguments: [false, true])
    func collisionCancellationAndStaleClipboardPreserveExistingFiles(moving: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.txt")
        let existing = destination.appendingPathComponent("source.txt")
        try Data("source".utf8).write(to: source)
        try Data("existing".utf8).write(to: existing)
        var prompts = 0
        let browser = BrowserState(homeDirectory: destination, resolveTransferCollision: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.writeObjects([source as NSURL])
        coordinator.table.filePasteboard = board
        let action = moving ? move : paste
        try #require(coordinator.table.responds(to: action))
        coordinator.table.perform(action, with: nil)
        try await wait { !browser.isCopying && !browser.isMoving }
        #expect(prompts == 1)
        #expect(try Data(contentsOf: source) == Data("source".utf8))
        #expect(try Data(contentsOf: existing) == Data("existing".utf8))
        board.clearContents()
        board.writeObjects([root.appendingPathComponent("missing.txt") as NSURL])
        coordinator.table.perform(action, with: nil)
        try await wait { !browser.isCopying && !browser.isMoving }
        #expect(moving ? browser.moveOutcome?.succeeded == false : browser.copyOutcome?.succeeded == false)
        #expect(try Data(contentsOf: existing) == Data("existing".utf8))
    }

    @Test func trashCommandPreservesDirtyDraftWhenCancelled() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("draft.txt")
        try Data("original".utf8).write(to: source)
        var prompts = 0
        let browser = BrowserState(homeDirectory: root, confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        browser.preview.updateText("unsaved")
        let coordinator = table(browser)
        try #require(coordinator.table.responds(to: trash))
        #expect(enabled(trash, in: coordinator.table))
        coordinator.table.perform(trash, with: nil)
        try await wait { prompts == 1 && !browser.isTrashing }
        #expect(browser.preview.text == "unsaved" && browser.preview.isDirty)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test(arguments: [false, true])
    func clipboardTransferProtectsDirtySourceInAnotherWindow(moving: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("draft.txt")
        try Data("original".utf8).write(to: source)
        let operations = FileOperationCoordinator()
        var prompts = 0
        let editor = BrowserState(homeDirectory: root, operations: operations, confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        let receiver = BrowserState(homeDirectory: destination, operations: operations)
        for browser in [editor, receiver] { operations.register(browser); await browser.left.refresh() }
        editor.select([source], in: .left)
        await editor.preview.load(editor.detailsSelection)
        editor.preview.setMode(.edit)
        editor.preview.updateText("unsaved")
        let coordinator = table(receiver)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.writeObjects([source as NSURL])
        coordinator.table.filePasteboard = board
        coordinator.table.perform(moving ? move : paste, with: nil)
        try await wait { !receiver.isCopying && !receiver.isMoving }
        #expect(prompts == 1 && editor.preview.isDirty && editor.preview.text == "unsaved")
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("draft.txt").path))
    }

    @Test func fileMenuTracksNativeFocusClipboardAndSelection() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.txt")
        try Data().write(to: source)
        let browser = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        browser.select([source], in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.writeObjects([source as NSURL])
        coordinator.table.filePasteboard = board
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        coordinator.scroll.frame = NSRect(x: 0, y: 0, width: 300, height: 300)
        content.addSubview(coordinator.scroll)
        let text = NSTextView(frame: NSRect(x: 300, y: 0, width: 300, height: 300))
        content.addSubview(text)
        let window = NSWindow(contentRect: content.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = content
        let menu = BrowserFileMenuState()
        try #require(window.makeFirstResponder(coordinator.table))
        menu.refresh(in: window)
        #expect(menu.canMove && menu.canTrash)
        try #require(window.makeFirstResponder(text))
        menu.refresh(in: window)
        #expect(!menu.canMove && !menu.canTrash)
        try #require(window.makeFirstResponder(coordinator.table))
        board.clearContents()
        board.setString("text clipboard", forType: .string)
        browser.select([], in: .left)
        menu.refresh(in: window)
        #expect(!menu.canMove && !menu.canTrash)
    }

    @Test(arguments: [false, true])
    func cutDefersMutationAndMovesAcrossWindowsOnce(explicitMove: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.txt")
        let link = root.appendingPathComponent("link")
        try Data("cut contents".utf8).write(to: source)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        let sender = BrowserState(homeDirectory: root)
        let receiver = BrowserState(homeDirectory: destination)
        await sender.left.refresh()
        await receiver.left.refresh()
        sender.select([source, link], in: .left)
        let outgoing = table(sender)
        let incoming = table(receiver)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        outgoing.table.filePasteboard = board
        incoming.table.filePasteboard = board
        try #require(outgoing.table.responds(to: cut), "Browser must handle native Cut without moving files yet")
        #expect(enabled(cut, in: outgoing.table))
        outgoing.table.perform(cut, with: nil)
        #expect(try Data(contentsOf: source) == Data("cut contents".utf8))
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == source.path)
        #expect(!sender.isMoving && !receiver.isMoving)
        incoming.table.perform(explicitMove ? move : paste, with: nil)
        try #require(receiver.isMoving && !receiver.isCopying)
        outgoing.table.perform(paste, with: nil)
        #expect(!sender.isMoving && !sender.isCopying)
        try await wait { !receiver.isMoving }
        #expect(receiver.moveOutcome?.succeeded == true)
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: destination.appendingPathComponent("source.txt")) == Data("cut contents".utf8))
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: destination.appendingPathComponent("link").path) == source.path)
        #expect(FileDrop.sources(from: board) == nil)
        #expect(!enabled(paste, in: incoming.table))
    }

    @Test(arguments: [false, true])
    func copyOrExternalClipboardReplacementCancelsCutIntent(external: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.txt")
        try Data("copy after cut".utf8).write(to: source)
        let browser = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        browser.select([source], in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        coordinator.table.filePasteboard = board
        try #require(coordinator.table.responds(to: cut))
        coordinator.table.perform(cut, with: nil)
        if external {
            board.clearContents()
            board.writeObjects([source as NSURL])
        } else { coordinator.table.perform(copy, with: nil) }
        await browser.navigate(to: destination, in: .left)
        coordinator.table.perform(paste, with: nil)
        try #require(browser.isCopying && !browser.isMoving)
        try await wait { !browser.isCopying }
        #expect(browser.copyOutcome?.succeeded == true)
        #expect(try Data(contentsOf: source) == Data("copy after cut".utf8))
    }

    @Test func cancelledCutPasteRetainsIntentForAnotherDestination() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        let other = root.appendingPathComponent("other")
        for directory in [destination, other] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let source = root.appendingPathComponent("source.txt")
        try Data("cut source".utf8).write(to: source)
        try Data("existing".utf8).write(to: destination.appendingPathComponent("source.txt"))
        var prompts = 0
        let browser = BrowserState(homeDirectory: root, resolveTransferCollision: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        browser.select([source], in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        coordinator.table.filePasteboard = board
        try #require(coordinator.table.responds(to: cut))
        coordinator.table.perform(cut, with: nil)
        let revision = board.changeCount
        await browser.navigate(to: destination, in: .left)
        coordinator.table.perform(paste, with: nil)
        try await wait { !browser.isMoving && !browser.isCopying }
        #expect(prompts == 1 && board.changeCount == revision)
        #expect(try Data(contentsOf: source) == Data("cut source".utf8))
        await browser.navigate(to: other, in: .left)
        coordinator.table.perform(paste, with: nil)
        try #require(browser.isMoving)
        try await wait { !browser.isMoving }
        #expect(browser.moveOutcome?.succeeded == true && FileDrop.sources(from: board) == nil)
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }

    @Test func partialCutMoveLeavesOnlyUnmovedSourcesOnClipboard() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let sources = ["a.txt", "b.txt", "c.txt"].map { root.appendingPathComponent($0) }
        for source in sources { try Data(source.lastPathComponent.utf8).write(to: source) }
        let browser = BrowserState(homeDirectory: root, move: { operation in
            if operation.source.lastPathComponent == "b.txt" {
                try? Data("late collision".utf8).write(to: operation.destination)
            }
            return await operation.move()
        })
        await browser.left.refresh()
        browser.select(Set(sources), in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        coordinator.table.filePasteboard = board
        try #require(coordinator.table.responds(to: cut))
        coordinator.table.perform(cut, with: nil)
        await browser.navigate(to: destination, in: .left)
        coordinator.table.perform(paste, with: nil)
        try await wait { !browser.isMoving && !browser.isCopying }
        #expect(browser.moveOutcome?.succeeded == false)
        #expect(browser.moveOutcome?.relocated.map(\.source) == [sources[0]])
        #expect(FileDrop.sources(from: board) == Array(sources.dropFirst()))
        #expect(!FileManager.default.fileExists(atPath: sources[0].path))
        #expect(try Data(contentsOf: sources[1]) == Data("b.txt".utf8))
        #expect(try Data(contentsOf: sources[2]) == Data("c.txt".utf8))
    }

    @Test func cutPasteRetainsPendingIntentWhenDirtySourceIsCancelled() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("draft.txt")
        try Data("original".utf8).write(to: source)
        let operations = FileOperationCoordinator()
        var prompts = 0
        var discard = false
        let sender = BrowserState(homeDirectory: root, operations: operations, confirmChanges: { _, answer in
            prompts += 1
            answer(discard ? .discard : .cancel)
        })
        let receiver = BrowserState(homeDirectory: destination, operations: operations)
        for browser in [sender, receiver] { operations.register(browser); await browser.left.refresh() }
        sender.select([source], in: .left)
        await sender.preview.load(sender.detailsSelection)
        sender.preview.setMode(.edit)
        sender.preview.updateText("unsaved")
        let outgoing = table(sender)
        let incoming = table(receiver)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        outgoing.table.filePasteboard = board
        incoming.table.filePasteboard = board
        outgoing.table.perform(cut, with: nil)
        #expect(prompts == 0 && sender.preview.isDirty)
        incoming.table.perform(paste, with: nil)
        try await wait { !receiver.isMoving }
        #expect(prompts == 1 && sender.preview.isDirty)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        discard = true
        incoming.table.perform(paste, with: nil)
        try #require(receiver.isMoving)
        try await wait { !receiver.isMoving }
        #expect(prompts == 2 && receiver.moveOutcome?.succeeded == true)
        #expect(FileDrop.sources(from: board) == nil)
        #expect(try Data(contentsOf: destination.appendingPathComponent("draft.txt")) == Data("original".utf8))
    }

    @Test func finishingCutMoveDoesNotClearANewerClipboard() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.txt")
        try Data("cut source".utf8).write(to: source)
        let (release, gate) = AsyncStream<Void>.makeStream()
        let browser = BrowserState(homeDirectory: root, move: { operation in
            for await _ in release { }
            return await operation.move()
        })
        await browser.left.refresh()
        browser.select([source], in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); gate.finish() }
        coordinator.table.filePasteboard = board
        try #require(coordinator.table.responds(to: cut))
        coordinator.table.perform(cut, with: nil)
        await browser.navigate(to: destination, in: .left)
        coordinator.table.perform(paste, with: nil)
        try #require(browser.isMoving)
        board.clearContents()
        board.setString("new clipboard", forType: .string)
        gate.finish()
        try await wait { !browser.isMoving }
        #expect(browser.moveOutcome?.succeeded == true)
        #expect(board.string(forType: .string) == "new clipboard")
    }

    private func enabled(_ action: Selector, in table: DirectoryTableView) -> Bool {
        table.validateUserInterfaceItem(NSMenuItem(title: "File command", action: action, keyEquivalent: ""))
    }

    private func table(_ browser: BrowserState) -> DirectoryTable<Text>.Coordinator {
        _ = NSApplication.shared
        return DirectoryTable<Text>.Coordinator(DirectoryTable(browser: browser, id: .left,
            entries: browser.left.entries, selection: browser.left.selectedItems, renameID: nil, row: { entry, _ in Text(entry.name) }))
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-clipboard-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func wait(_ completed: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while !completed() {
            try #require(ContinuousClock.now < deadline, "Timed out waiting for clipboard operation")
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
