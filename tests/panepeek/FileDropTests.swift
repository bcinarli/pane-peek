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
