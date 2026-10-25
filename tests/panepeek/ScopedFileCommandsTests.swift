import AppKit
import SwiftUI
import Synchronization
import Testing
@testable import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor struct ScopedFileCommandsTests {
    @Test(arguments: [false, true])
    func clipboardOwnsCopiedAndCutScopesUntilReplacement(cutting: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let released = Mutex(0)
        let browser = browser(root, released: { released.withLock { $0 += 1 } })
        await browser.left.refresh()
        browser.select(Set(browser.left.entries.map(\.url)), in: .left)
        let coordinator = table(browser)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        coordinator.table.filePasteboard = board
        let action = NSSelectorFromString(cutting ? "cut:" : "copy:")
        try #require(coordinator.table.validateUserInterfaceItem(NSMenuItem(title: "Transfer", action: action, keyEquivalent: "")))
        coordinator.table.perform(action, with: nil)
        try #require(FileClipboard.sources(from: board)?.count == 1)
        browser.left.releaseAccess()
        #expect(released.withLock { $0 } == 0)
        board.clearContents()
        #expect(FileClipboard.sources(from: board) == nil)
        #expect(released.withLock { $0 } == 1)
    }

    @Test(arguments: [false, true])
    func exportedNativeDragKeepsScopeAndExclusionAfterItsWindowCloses(nativeCallback: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let released = Mutex(0)
        let browser = browser(root, released: { released.withLock { $0 += 1 } })
        await browser.left.refresh()
        browser.select(Set(browser.left.entries.map(\.url)), in: .left)
        var coordinator: DirectoryTable<Text>.Coordinator? = table(browser)
        try #require(coordinator?.table.canDragRows(with: IndexSet(integer: 0), at: .zero) == true)
        try #require(coordinator?.tableView(coordinator!.table, pasteboardWriterForRow: 0) != nil)
        var nativeReceipt = coordinator?.table.dragAccess
        try #require(nativeReceipt != nil)
        browser.operations.unregister(browser)
        browser.left.releaseAccess()
        #expect(released.withLock { $0 } == 0 && !browser.operations.canMutate)
        #expect(coordinator?.tableView(coordinator!.table, pasteboardWriterForRow: 0) != nil)
        if nativeCallback { coordinator?.finishDrag() }
        coordinator = nil
        #expect(nativeReceipt != nil)
        nativeReceipt = nil
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while released.withLock({ $0 }) == 0 && ContinuousClock.now < deadline { await Task.yield() }
        #expect(released.withLock { $0 } == 1 && browser.operations.canMutate)
    }

    @Test func clipboardReplacementReleasesAccessWithoutAnotherPanePeekCommand() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let released = Mutex(0)
        FileClipboard.write([root.appendingPathComponent("source.txt")],
            access: [DirectoryAccess(root: root) { released.withLock { $0 += 1 } }], to: board)
        board.clearContents()
        board.setString("replacement", forType: .string)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while released.withLock({ $0 }) == 0 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(released.withLock { $0 } == 1)
        #expect(board.string(forType: .string) == "replacement")
    }

    @Test func anOldNativeReceiptCannotEndANewerDrag() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let browser = browser(root, released: {})
        await browser.left.refresh()
        browser.select(Set(browser.left.entries.map(\.url)), in: .left)
        try #require(browser.beginDrag(in: .left, items: browser.left.selectedItems) != nil)
        var first = browser.retainDragAccess()
        try #require(first != nil)
        browser.endDrag()
        try #require(browser.beginDrag(in: .left, items: browser.left.selectedItems) != nil)
        first = nil
        for _ in 0..<10 { await Task.yield() }
        #expect(browser.isDragging && !browser.operations.canMutate)
        browser.endDrag()
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-scoped-commands-" + UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try Data("sample".utf8).write(to: root.appendingPathComponent("source.txt"))
        return root
    }
    private func browser(_ root: URL, released: @escaping @Sendable () -> Void) -> BrowserState {
        BrowserState(homeDirectory: root, requiresFolderAccess: true, acquireOperationAccess: { directory, mode in
            DirectoryAccess(root: directory, mode: mode) {}
        }, load: { directory in
            let listing = try await DirectoryListing.read(directory, followingLinks: false)
            return DirectoryListing(directory: directory, entries: listing.entries, access: DirectoryAccess(root: directory, release: released))
        })
    }
    private func table(_ browser: BrowserState) -> DirectoryTable<Text>.Coordinator {
        _ = NSApplication.shared
        return DirectoryTable<Text>.Coordinator(DirectoryTable(browser: browser, id: .left, entries: browser.left.entries,
            selection: browser.left.selectedItems, renameID: nil, row: { entry, _, _ in Text(entry.name) }))
    }
}
