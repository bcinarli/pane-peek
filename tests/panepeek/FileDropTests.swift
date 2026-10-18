import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct FileDropTests {
    @Test func readsEveryLocalFileInPasteboardOrderWithoutResolvingListedLinks() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let urls = [URL(fileURLWithPath: "/drop-fixture/space ü.txt"), URL(fileURLWithPath: "/drop-fixture/listed-link")]
        board.writeObjects(urls.map { $0 as NSURL })
        #expect(FileDrop.sources(from: board) == urls)
    }

    @Test(arguments: ["https://example.com/file", "file://server/share/file", "file:///tmp/file?query", "file:///tmp/file#fragment", "not-a-url"])
    func rejectsUnsupportedURLsWithoutAcceptingTheGoodSubset(raw: String) {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let good = NSPasteboardItem()
        good.setString("file:///tmp/good", forType: .fileURL)
        let bad = NSPasteboardItem()
        bad.setString(raw, forType: .fileURL)
        board.writeObjects([good, bad])
        #expect(FileDrop.sources(from: board) == nil)
    }

    @Test func rejectsEmptyTextMixedAndRepeatedPayloads() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        #expect(FileDrop.sources(from: board) == nil)
        let good = NSPasteboardItem()
        good.setString("file:///tmp/good", forType: .fileURL)
        let text = NSPasteboardItem()
        text.setString("plain text", forType: .string)
        board.writeObjects([good, text])
        #expect(FileDrop.sources(from: board) == nil)
        board.clearContents()
        board.writeObjects([URL(fileURLWithPath: "/tmp/good") as NSURL, URL(fileURLWithPath: "/tmp/good") as NSURL])
        #expect(FileDrop.sources(from: board) == nil)
    }

    @Test func choosesCopyFirstAndCommandMoveOnlyWhenPermitted() {
        #expect(FileDrop.operation(allowed: [.copy, .move], modifiers: []) == .copy)
        #expect(FileDrop.operation(allowed: [.copy, .move], modifiers: .command) == .move)
        #expect(FileDrop.operation(allowed: .copy, modifiers: .command) == .copy)
        #expect(FileDrop.operation(allowed: .move, modifiers: []) == [])
        #expect(FileDrop.operation(allowed: .move, modifiers: .command) == .move)
        #expect(FileDrop.operation(allowed: [.link, .generic], modifiers: .command) == [])
        #expect(FileDrop.operation(allowed: [], modifiers: []) == [])
    }

    @Test func nativeTableDropsOnItsDirectoryAndRejectsAHiddenTarget() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-native-drop-\(UUID())")
        let source = root.appendingPathComponent("source.txt")
        let destination = root.appendingPathComponent("destination")
        let rowFolder = destination.appendingPathComponent("row-folder")
        try FileManager.default.createDirectory(at: rowFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("native drop".utf8).write(to: source)
        let browser = BrowserState(homeDirectory: destination)
        await browser.left.refresh()
        let coordinator = DirectoryTable<Text>.Coordinator(DirectoryTable(browser: browser, id: .left,
            entries: browser.left.entries, selection: [], renameID: nil, row: { entry, _ in Text(entry.name) }))
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.writeObjects([source as NSURL])
        let info = FileDropInfo(board)
        #expect(coordinator.tableView(coordinator.table, validateDrop: info, proposedRow: 0, proposedDropOperation: .on) == .copy)
        #expect(coordinator.tableView(coordinator.table, acceptDrop: info, row: 0, dropOperation: .on))
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while browser.isCopying && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
        #expect(!browser.isCopying && browser.copyOutcome?.succeeded == true)
        #expect(try Data(contentsOf: destination.appendingPathComponent("source.txt")) == Data("native drop".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: rowFolder.path).isEmpty)
        browser.focus(.right)
        browser.setMode(.onePane)
        #expect(coordinator.tableView(coordinator.table, validateDrop: info, proposedRow: 0, proposedDropOperation: .on) == [])
        #expect(!coordinator.tableView(coordinator.table, acceptDrop: info, row: 0, dropOperation: .on))
    }

    @Test func nativeSourceWritersRetainCapturedURLsThroughReordering() async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/native-source-fixture", isDirectory: true)
        let entries = ["a-link", "z.txt"].map { DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false, isSymbolicLink: $0 == "a-link") }
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: entries) })
        await browser.left.refresh()
        browser.select(Set(entries.map(\.url)), in: .left)
        let input = DirectoryTable<Text>(browser: browser, id: .left, entries: browser.left.entries,
            selection: browser.left.selectedItems, renameID: nil, row: { entry, _ in Text(entry.name) })
        let coordinator = DirectoryTable<Text>.Coordinator(input)
        #expect(!coordinator.table.canDragRows(with: IndexSet(integer: 0), at: .zero))
        try #require(coordinator.table.canDragRows(with: IndexSet([0, 1]), at: .zero))
        #expect(browser.isDragging)
        await browser.left.sort(by: .name, direction: .descending)
        coordinator.update(DirectoryTable(browser: browser, id: .left, entries: browser.left.entries,
            selection: browser.left.selectedItems, renameID: nil, row: { entry, _ in Text(entry.name) }))
        try #require(coordinator.table.canDragRows(with: IndexSet([0, 1]), at: .zero))
        let writers = try [0, 1].map { try #require(coordinator.tableView(coordinator.table, pasteboardWriterForRow: $0)) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); browser.endDrag() }
        board.writeObjects(writers)
        #expect(FileDrop.sources(from: board) == entries.map(\.url))
        coordinator.table.finishUnusedDrag()
        #expect(browser.isDragging)
        #expect(coordinator.tableView(coordinator.table, pasteboardWriterForRow: 0) != nil)
        coordinator.finishDrag()
        #expect(!browser.isDragging && browser.canCreate())
        #expect(coordinator.tableView(coordinator.table, pasteboardWriterForRow: 0) == nil)
    }

    @Test(arguments: [false, true])
    func nativeDragCanStartBeforeTheClickedRowIsSelected(hasPreviousSelection: Bool) async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/native-source-fixture", isDirectory: true)
        let entries = ["a.txt", "b.txt"].map { DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false) }
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: entries) })
        await browser.left.refresh()
        if hasPreviousSelection { browser.select([entries[1].url], in: .left) }
        let coordinator = DirectoryTable<Text>.Coordinator(DirectoryTable(browser: browser, id: .left, entries: browser.left.entries,
            selection: browser.left.selectedItems, renameID: nil, row: { entry, _ in Text(entry.name) }))
        defer { coordinator.table.finishUnusedDrag() }
        prepareClick(on: 0, in: coordinator.table)
        try #require(coordinator.table.canDragRows(with: IndexSet(integer: 0), at: .zero))
        #expect(browser.left.selectedItems == [entries[0].url])
        #expect(browser.draggedSources == [entries[0].url])
        coordinator.table.finishUnusedDrag()
        #expect(!browser.isDragging && browser.canCreate())
    }

    @Test(arguments: [0, 1])
    func nativeDirtyAttemptExportsNoWriterBeforeSuccessfulResolution(clickedRow: Int) async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/native-source-fixture", isDirectory: true)
        let entry = DirectoryEntry(url: directory.appendingPathComponent("draft.txt"), isDirectory: false)
        let other = DirectoryEntry(url: directory.appendingPathComponent("other.txt"), isDirectory: false)
        var prompts = 0
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: [entry, other]) },
            preview: PreviewState(read: { _ in .text("original") }), confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        browser.select([entry.url], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        browser.preview.updateText("draft")
        let coordinator = DirectoryTable<Text>.Coordinator(DirectoryTable(browser: browser, id: .left, entries: browser.left.entries,
            selection: browser.left.selectedItems, renameID: nil, row: { entry, _ in Text(entry.name) }))
        prepareClick(on: clickedRow, in: coordinator.table)
        #expect(!coordinator.table.canDragRows(with: IndexSet(integer: clickedRow), at: .zero))
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while browser.operations.isBusy && ContinuousClock.now < deadline { await Task.yield() }
        #expect(prompts == 1 && browser.preview.isDirty && !browser.isDragging)
        #expect(browser.left.selectedItems == [entry.url])
        #expect(coordinator.tableView(coordinator.table, pasteboardWriterForRow: 0) == nil)
    }

    @Test func nativeCapturedDragDropsIntoAnotherBrowserAndRefreshesBoth() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-native-cross-window-" + UUID().uuidString)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.txt")
        try Data("native cross-window".utf8).write(to: source)
        let operations = FileOperationCoordinator()
        let first = BrowserState(homeDirectory: root, operations: operations)
        let second = BrowserState(homeDirectory: destination, operations: operations)
        for browser in [first, second] { operations.register(browser); await browser.left.refresh() }
        first.select([source], in: .left)
        await first.preview.load(first.detailsSelection)
        let sender = DirectoryTable<Text>.Coordinator(DirectoryTable(browser: first, id: .left, entries: first.left.entries,
            selection: first.left.selectedItems, renameID: nil, row: { entry, _ in Text(entry.name) }))
        let receiver = DirectoryTable<Text>.Coordinator(DirectoryTable(browser: second, id: .left, entries: second.left.entries,
            selection: [], renameID: nil, row: { entry, _ in Text(entry.name) }))
        let row = try #require(first.left.entries.firstIndex { $0.url == source })
        try #require(sender.table.canDragRows(with: IndexSet(integer: row), at: .zero))
        let writer = try #require(sender.tableView(sender.table, pasteboardWriterForRow: row))
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); first.endDrag() }
        board.writeObjects([writer])
        let info = FileDropInfo(board)
        #expect(receiver.tableView(receiver.table, validateDrop: info, proposedRow: -1, proposedDropOperation: .on) == .copy)
        try #require(receiver.tableView(receiver.table, acceptDrop: info, row: -1, dropOperation: .on))
        first.endDrag(external: true)
        #expect(first.dragNotice == nil)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while second.isCopying && ContinuousClock.now < deadline { await Task.yield() }
        #expect(second.copyOutcome?.succeeded == true)
        #expect(second.left.entries.map(\.name) == ["source.txt"])
        #expect(first.left.selectedItems == [source] && first.preview.canEdit)
        #expect(try Data(contentsOf: destination.appendingPathComponent("source.txt")) == Data("native cross-window".utf8))
    }

    private func prepareClick(on row: Int, in table: DirectoryTableView) {
        table.frame.size = NSSize(width: 500, height: 200)
        let point = table.convert(NSPoint(x: 20, y: table.rect(ofRow: row).midY), to: nil)
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                      windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        table.prepareInteraction(event)
    }
}

@MainActor private final class FileDropInfo: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    init(_ pasteboard: NSPasteboard) { draggingPasteboard = pasteboard }
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    nonisolated var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    nonisolated override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?,
                                classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any],
                                using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}
