import AppKit
import SwiftUI
import Testing
@testable import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct BrowserColumnsTests {
    @Test(arguments: ["save", "discard", "cancel", "failed save"])
    func relevanceToggleResumesAfterResolvingTheOtherPanesDraft(choice: String) async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let preview = PreviewState(write: { snapshot, text, url in
            if choice == "failed save" { throw CocoaError(.fileWriteNoPermission) }
            return try await snapshot.save(text, to: url)
        })
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: fixture.root, preview: preview,
                                   confirmChanges: { _, completion in answer = completion })
        await browser.left.refresh()
        await browser.right.refresh()
        browser.search("sample", in: .right)
        await browser.right.waitForSearch()
        let file = fixture.root.appendingPathComponent("sample.txt")
        browser.select([file], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        let area = PaneArea(browser: browser,
            favourites: fixture.favourites, id: .right, accent: .purple,
            openInFinder: { _, _ in }, toggleFavourite: { _ in })
        area.searchRelevance.wrappedValue = false
        let complete = try #require(answer)
        #expect(browser.focusedPane == .left && browser.right.searchUsesRelevance)
        complete(choice == "discard" ? .discard : (choice == "cancel" ? .cancel : .save))
        let accepted = choice == "save" || choice == "discard"
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline,
              accepted ? browser.right.searchUsesRelevance : (choice == "failed save" && preview.errorMessage == nil) {
            try await Task.sleep(for: .milliseconds(5))
        }
        await Task.yield()
        #expect(browser.focusedPane == (accepted ? .right : .left))
        #expect(browser.right.searchUsesRelevance == !accepted)
        #expect(preview.isDirty == !accepted)
        #expect(try String(contentsOf: file, encoding: .utf8) == (choice == "save" ? "draft" : "sample"))
    }

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
        #expect(right.tableColumns.dropFirst().map(\.width) == Array(rightWidths.dropFirst()))
        let scroll = try #require(right.enclosingScrollView)
        let expected = max(160, scroll.contentSize.width - right.tableColumns.dropFirst().reduce(0) { $0 + $1.width } - 8)
        #expect(abs(right.tableColumns[0].width - expected) < 1)
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

    @Test(arguments: [true, false])
    func restoredNameUsesTheAppliedWindowAndSplitLayout(matchingViewport: Bool) async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let frame = NSRect(x: 60, y: 60, width: 1100, height: 650)
        fixture.preferences.set([
            "directories": [fixture.root.path, fixture.root.path], "mode": "onePane",
            "detailsWidth": 300, "detailsExpanded": false, "windowFrame": WindowGeometry.record(frame)
        ], forKey: "rememberedWindow")

        let firstLifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let first = await showBrowserWindow(firstLifecycle, fixture: fixture)
        defer { first.close() }
        let original = try await restoredTable(in: first)
        let originalViewport = try #require(original.enclosingScrollView?.contentSize.width)
        let manualWidth: CGFloat = 333
        firstLifecycle.activate(first)
        original.tableColumns[0].width = manualWidth
        original.tableColumns[1].width = 93
        #expect(firstLifecycle.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
        var record = try #require(fixture.preferences.dictionary(forKey: "rememberedWindow"))
        if !matchingViewport {
            var narrowerFrame = frame
            narrowerFrame.size.width = 960
            record["windowFrame"] = WindowGeometry.record(narrowerFrame)
            fixture.preferences.set(record, forKey: "rememberedWindow")
        }

        let nextLifecycle = BrowserLifecycle(preferences: fixture.preferences)
        let next = await showBrowserWindow(nextLifecycle, fixture: fixture)
        defer { next.close() }
        let restored = try await restoredTable(in: next)
        let viewport = try #require(restored.enclosingScrollView?.contentSize.width)
        #expect((abs(viewport - originalViewport) < 1) == matchingViewport)
        #expect(restored.browser?.mode == .onePane)
        #expect(restored.tableColumns[1].width == 93)
        #expect(abs(restored.tableColumns[0].width - (matchingViewport ? manualWidth : fittedNameWidth(in: restored))) < 1)

        next.setContentSize(NSSize(width: matchingViewport ? 960 : 1100, height: 550))
        await settle(next)
        #expect(abs(restored.tableColumns[0].width - fittedNameWidth(in: restored)) < 1)
        #expect(restored.tableColumns[0].width != manualWidth)
    }

    private func showBrowserWindow(_ lifecycle: BrowserLifecycle, fixture: Fixture) async -> NSWindow {
        _ = NSApplication.shared
        let controller = NSHostingController(rootView: BrowserWindow(title: "Column restoration",
            favourites: fixture.favourites, lifecycle: lifecycle))
        controller.view.layoutSubtreeIfNeeded()
        await Task.yield()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 450),
                              styleMask: [.titled, .resizable, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        return window
    }

    private func restoredTable(in window: NSWindow) async throws -> DirectoryTableView {
        let content = try #require(window.contentView)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            await settle(window)
            if let table = descendants(DirectoryTableView.self, in: content).first(where: {
                $0.window === window && $0.browser?.startupState == .ready && $0.restoredLayoutReady
            }) {
                return table
            }
            try await Task.sleep(for: .milliseconds(5))
        } while ContinuousClock.now < deadline
        throw NativeTestTimeout(event: "restored browser table layout")
    }

    private func fittedNameWidth(in table: DirectoryTableView) -> CGFloat {
        let viewport = table.enclosingScrollView?.contentSize.width ?? 0
        let metadataWidth = table.tableColumns.dropFirst().reduce(0) { $0 + $1.width }
        return max(table.tableColumns[0].minWidth, viewport - metadataWidth - 8)
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
