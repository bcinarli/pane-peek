import AppKit
import SwiftUI
import Testing
@testable import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct BrowserColumnsTests {
    @Test func switchingFromRightRetainsBothTablesWidthsAndHorizontalAlignment() async throws {
        let fixture = try Fixture(itemCount: 100)
        defer { fixture.cleanUp() }
        let browser = fixture.browser
        await browser.left.refresh()
        await browser.right.refresh()
        let controller = BrowserSplitView<PaneArea, PaneArea, Color>.Controller(
            left: fixture.pane(.left), right: fixture.pane(.right), details: .clear
        )
        let window = show(controller)
        defer { window.orderOut(nil) }
        let left = try #require(descendants(DirectoryTableView.self, in: controller.left.view).first)
        let right = try #require(descendants(DirectoryTableView.self, in: controller.right.view).first)
        try #require(left.tableColumns.count == 3 && right.tableColumns.count == 3)
        for (column, width) in zip(left.tableColumns, [500.0, 100.0, 180.0]) { column.width = width }
        for (column, width) in zip(right.tableColumns, [340.0, 85.0, 140.0]) { column.width = width }
        left.scrollRowToVisible(80)
        left.scrollColumnToVisible(2)
        let origin = try #require(left.enclosingScrollView?.contentView.bounds.origin)
        #expect(origin.x > 0 && origin.y > 0)
        let widths = left.tableColumns.map(\.width)
        let rightWidths = right.tableColumns.map(\.width)
        browser.focus(.right)
        browser.setMode(.onePane)
        controller.applyLayout(browser.visiblePanes)
        window.contentView?.layoutSubtreeIfNeeded()
        #expect(left.window == nil)
        browser.setMode(.twoPanes)
        controller.applyLayout(browser.visiblePanes)
        await settle(window)
        #expect(controller.splitViewItems.first?.viewController === controller.right)
        #expect(descendants(DirectoryTableView.self, in: controller.left.view).first === left)
        #expect(left.tableColumns.map(\.width) == widths)
        #expect(right.tableColumns.map(\.width) == rightWidths)
        #expect(left.enclosingScrollView?.contentView.bounds.origin == origin)
        let header = try #require(left.headerView)
        for index in left.tableColumns.indices {
            let heading = header.convert(header.headerRect(ofColumn: index), to: window.contentView)
            let cell = left.convert(left.rect(ofColumn: index), to: window.contentView)
            #expect(abs(heading.minX - cell.minX) < 1)
        }
    }

    @Test func resizingTheNameColumnRetainsTheNativeRenameDraftAndCaret() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let browser = fixture.browser
        await browser.left.refresh()
        let item = try #require(browser.left.entries.first)
        browser.select([item.url], in: .left)
        let controller = NSHostingController(rootView: fixture.pane(.left))
        controller.sizingOptions = [.minSize, .maxSize]
        let window = show(controller)
        defer { window.orderOut(nil) }
        let table = try #require(descendants(DirectoryTableView.self, in: controller.view).first)
        try #require(table.view(atColumn: 0, row: 0, makeIfNecessary: true) != nil)
        table.display()
        table.tableColumns[0].width = 1200
        table.scrollColumnToVisible(2)
        try #require(table.enclosingScrollView!.contentView.bounds.minX > 0)
        await browser.beginRename(in: .left)
        try #require(browser.renameRequest != nil)
        controller.rootView = fixture.pane(.left)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while descendants(InlineRenameTextField.self, in: controller.view).isEmpty, ContinuousClock.now < deadline {
            await settle(window)
            try await Task.sleep(for: .milliseconds(5))
        }
        let field = try #require(descendants(InlineRenameTextField.self, in: controller.view).first)
        #expect(table.enclosingScrollView?.contentView.bounds.minX == 0)
        if field.currentEditor() == nil { window.makeFirstResponder(field) }
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("draft", replacementRange: editor.selectedRange())
        let draft = editor.string
        let caret = editor.selectedRange()
        try #require(table.tableColumns.count == 3)
        for width in [160.0, 380.0, 200.0] {
            table.tableColumns[0].width = width
            await settle(window)
            #expect(field.currentEditor() === editor)
            #expect(editor.string == draft && editor.selectedRange() == caret)
            #expect(browser.renameName == draft)
        }
        table.tableColumns[0].width = 160
        await browser.submitRename(named: "bad/name")
        try #require(browser.renameError != nil)
        await settle(window)
        let narrowHeight = table.rect(ofRow: 0).height
        #expect(narrowHeight > 70)
        table.tableColumns[0].width = 380
        await settle(window)
        #expect(table.rect(ofRow: 0).height < narrowHeight)
    }

    @Test func everyColumnRetainsTheContextTarget() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let browser = fixture.browser
        await browser.left.refresh()
        let item = try #require(browser.left.entries.first)
        let controller = NSHostingController(rootView: fixture.pane(.left))
        controller.sizingOptions = [.minSize, .maxSize]
        let window = show(controller)
        defer { window.orderOut(nil) }
        await settle(window)
        let table = try #require(descendants(DirectoryTableView.self, in: controller.view).first)
        try #require(table.tableColumns.count == 3)
        for column in table.tableColumns.indices {
            let cell = try #require(table.view(atColumn: column, row: 0, makeIfNecessary: true))
            await settle(window)
            let menu = try #require(descendants(ItemPathContextMenuView.self, in: cell).first)
            browser.select([], in: .left)
            var path: String?
            menu.paths { absolute, _ in path = absolute }
            #expect(path == item.url.path)
            #expect(browser.left.selectedItems == [item.url] && browser.left.primaryItemURL == item.url)
            #expect(window.firstResponder === table)
        }
    }

    private func show(_ controller: NSViewController) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        window.setContentSize(NSSize(width: 1100, height: 500))
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }

    private func settle(_ window: NSWindow) async {
        for _ in 0..<5 {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            await Task.yield()
        }
    }

    private func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(type, in: $0) }
    }

    @MainActor private struct Fixture {
        let root: URL
        let preferences: UserDefaults
        let suite = "panepeek-columns-\(UUID())"
        let browser: BrowserState
        let favourites: Favourites

        init(itemCount: Int = 1) throws {
            _ = NSApplication.shared
            root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-columns-\(UUID())").resolvingSymlinksInPath()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Data("sample".utf8).write(to: root.appendingPathComponent("sample.txt"))
            for index in 1..<itemCount { try Data().write(to: root.appendingPathComponent("item-\(index).txt")) }
            preferences = UserDefaults(suiteName: suite)!
            favourites = Favourites(preferences: preferences)
            browser = BrowserState(homeDirectory: root)
        }

        func pane(_ id: PaneID) -> PaneArea {
            PaneArea(browser: browser, favourites: favourites, id: id, accent: .purple,
                     openInFinder: { _, _ in }, toggleFavourite: { _ in })
        }

        func cleanUp() {
            preferences.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }
}
