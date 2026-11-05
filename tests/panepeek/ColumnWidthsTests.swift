import AppKit
import SwiftUI
import Testing
@testable import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct ColumnWidthsTests {
    @Test func labelledControlsShareNativeWidthsAndRejectInvalidInput() throws {
        let coordinator = table(BrowserState())
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        let columns = coordinator.table.tableColumns
        columns[0].width = 300
        let panel = try openPanel(coordinator.table, in: window)
        defer { panel.close() }
        let content = try #require(panel.contentView)
        let field = try #require(descendants(NSTextField.self, in: content).first { $0.accessibilityLabel() == "Name column width" })
        let stepper = try #require(descendants(NSStepper.self, in: content).first { $0.accessibilityLabel() == "Name column width" })
        #expect(field.doubleValue == 300 && stepper.doubleValue == 300)
        columns[0].width = 340
        #expect(field.doubleValue == 340 && stepper.doubleValue == 340)
        stepper.doubleValue += stepper.increment
        stepper.sendAction(stepper.action, to: stepper.target)
        #expect(columns[0].width == 350 && field.doubleValue == 350)
        field.stringValue = "1"
        field.sendAction(field.action, to: field.target)
        #expect(columns[0].width == columns[0].minWidth && stepper.doubleValue == columns[0].minWidth)
        let width = columns[0].width
        field.stringValue = "invalid"
        field.delegate?.controlTextDidEndEditing?(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        field.sendAction(field.action, to: field.target)
        #expect(columns[0].width == width && field.doubleValue == width)
        let message = try #require(descendants(NSTextField.self, in: content).first { $0.accessibilityLabel() == "Width input error" })
        #expect(!message.stringValue.isEmpty)
        #expect(!message.isHidden)
        field.stringValue = "1e300"
        field.sendAction(field.action, to: field.target)
        #expect(columns[0].width == width && !message.isHidden)
    }

    @Test func restoreDefaultsAffectsOnlyItsCapturedPaneAndRetainsEditorFocus() throws {
        let browser = BrowserState()
        let left = table(browser)
        let right = table(browser, id: .right)
        let editor = EditorTextView(usingTextLayoutManager: true)
        let editorScroll = PreviewTextView.scrollView(for: editor)
        editor.isEditable = true
        editor.string = "draft"
        let split = NSSplitView()
        split.isVertical = true
        split.addArrangedSubview(left.scroll)
        split.addArrangedSubview(right.scroll)
        split.addArrangedSubview(editorScroll)
        let window = show(split)
        defer {
            window.makeFirstResponder(nil)
            window.contentView = NSView()
            window.orderOut(nil)
        }
        window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 1, length: 2))
        for column in left.table.tableColumns { column.width = 450 }
        right.table.tableColumns[0].width = 500
        let peerWidths = right.table.tableColumns.map(\.width)
        let panel = try openPanel(left.table, in: window)
        try #require(browser.focus(.right))
        let content = try #require(panel.contentView)
        let restore = try #require(descendants(NSButton.self, in: content).first { $0.title == "Restore Defaults" })
        restore.sendAction(restore.action, to: restore.target)
        #expect(left.table.tableColumns[0].width == max(160, left.scroll.contentSize.width - 72 - 136 - 8))
        #expect(left.table.tableColumns[1].width == 72 && left.table.tableColumns[2].width == 136)
        #expect(right.table.tableColumns.map(\.width) == peerWidths)
        #expect(editor.string == "draft")
        #expect(window.firstResponder === editor && editor.selectedRange() == NSRange(location: 1, length: 2))
        panel.cancelOperation(nil)
        #expect(!panel.isVisible && panel.parent == nil)
        #expect(window.firstResponder === editor)
    }

    @Test func cachedPanelHeadingFollowsItsCapturedBrowsersCurrentPosition() async throws {
        let browser = BrowserState()
        let coordinator = table(browser, id: .right)
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        let panel = try openPanel(coordinator.table, in: window)
        defer { panel.close() }
        let heading = try #require(descendants(NSTextField.self, in: panel.contentView!).first { $0.stringValue == "Right directory pane" })
        panel.close()
        try #require(browser.focus(.right))
        browser.setMode(.onePane)
        browser.setMode(.twoPanes)
        let reopened = try openPanel(coordinator.table, in: window)
        #expect(reopened === panel && heading.stringValue == "Left directory pane")
        browser.setMode(.onePane)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while heading.stringValue != "Directory pane", ContinuousClock.now < deadline { await Task.yield() }
        #expect(heading.stringValue == "Directory pane")
    }

    @Test func wideBrowserDefaultsAndControlsUseAvailableSpace() async throws {
        let browser = BrowserState(homeDirectory: URL(fileURLWithPath: "/columns"),
                                   load: { DirectoryListing(directory: $0, entries: []) })
        let coordinator = table(browser)
        let window = show(coordinator.scroll, width: 2000)
        defer { window.orderOut(nil) }
        let name = coordinator.table.tableColumns[0]
        let available = coordinator.scroll.contentSize.width - 72 - 136 - 8
        try #require(available > 1000)
        #expect(name.width > 1000)
        let panel = try openPanel(coordinator.table, in: window)
        defer { panel.close() }
        let content = try #require(panel.contentView)
        name.width = 300
        let restore = try #require(descendants(NSButton.self, in: content).first { $0.title == "Restore Defaults" })
        restore.sendAction(restore.action, to: restore.target)
        #expect(name.width == available)
        let field = try #require(descendants(NSTextField.self, in: content).first { $0.accessibilityLabel() == "Name column width" })
        field.stringValue = "1500"
        field.sendAction(field.action, to: field.target)
        #expect(name.width == 1500)
        let stepper = try #require(descendants(NSStepper.self, in: content).first { $0.accessibilityLabel() == "Name column width" })
        stepper.doubleValue += stepper.increment
        stepper.sendAction(stepper.action, to: stepper.target)
        #expect(name.width == 1510 && field.doubleValue == 1510)
        await browser.left.navigate(to: browser.left.directory.appendingPathComponent("child"))
        coordinator.update(DirectoryTable(browser: browser, id: .left, entries: [], selection: [], renameID: nil,
                                          row: { entry, _, _ in Text(entry.name) }))
        window.contentView?.layoutSubtreeIfNeeded()
        #expect(name.width == 1510 && field.doubleValue == 1510)
        window.setContentSize(NSSize(width: 1000, height: 300))
        window.contentView?.layoutSubtreeIfNeeded()
        let fitted = coordinator.scroll.contentSize.width - 72 - 136 - 8
        #expect(abs(name.width - fitted) < 1)
        #expect(abs(field.doubleValue - fitted) < 1)
        #expect(abs(stepper.doubleValue - fitted) < 1)
    }

    @Test func rememberedWidthsFollowBrowserIdentityAcrossReopeningAndFreshWindows() async throws {
        let suite = "panepeek-column-restoration-\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        func makeBrowser() -> BrowserState {
            BrowserState(homeDirectory: URL(fileURLWithPath: "/columns"),
                         load: { DirectoryListing(directory: $0, entries: []) })
        }
        let restoration = WindowRestoration(preferences: preferences)
        let browser = makeBrowser()
        await restoration.start(browser, sizing: DetailsSizing())
        let left = table(browser)
        let leftWindow = show(left.scroll, width: 900)
        defer { leftWindow.orderOut(nil) }
        let right = table(browser, id: .right)
        let rightWindow = show(right.scroll, width: 900)
        defer { rightWindow.orderOut(nil) }
        for (column, width) in zip(left.table.tableColumns, [420.0, 100.0, 180.0]) { column.width = width }
        for (column, width) in zip(right.table.tableColumns, [390.0, 86.0, 154.0]) { column.width = width }
        browser.setMode(.twoPanes)
        try #require(browser.focus(.right))
        browser.setMode(.onePane)
        restoration.remember(browser, sizing: DetailsSizing())

        let fresh = makeBrowser()
        await restoration.start(fresh, sizing: DetailsSizing())
        let freshTable = table(fresh)
        let freshWindow = show(freshTable.scroll, width: 900)
        defer { freshWindow.orderOut(nil) }
        #expect(freshTable.table.tableColumns.map(\.width) == [684, 72, 136])

        restoration.reopen()
        let reopened = makeBrowser()
        await restoration.start(reopened, sizing: DetailsSizing())
        #expect(reopened.visiblePanes == [.right] && reopened.presentationOrder == [.right, .left])
        let reopenedRight = table(reopened, id: .right)
        let reopenedWindow = show(reopenedRight.scroll, width: 900)
        defer { reopenedWindow.orderOut(nil) }
        #expect(reopenedRight.table.tableColumns.map(\.width) == [390, 86, 154])
        reopened.setMode(.twoPanes)
        let reopenedLeft = table(reopened)
        let hiddenWindow = show(reopenedLeft.scroll, width: 900)
        defer { hiddenWindow.orderOut(nil) }
        #expect(reopenedLeft.table.tableColumns.map(\.width) == [420, 100, 180])

        reopenedWindow.setContentSize(NSSize(width: 550, height: 300))
        reopenedWindow.contentView?.layoutSubtreeIfNeeded()
        #expect(reopenedRight.table.tableColumns.map(\.width) == [302, 86, 154])
        restoration.remember(reopened, sizing: DetailsSizing())
        let relaunched = makeBrowser()
        let relaunchedRight = table(relaunched, id: .right)
        let relaunchedWindow = show(relaunchedRight.scroll, width: 900)
        defer { relaunchedWindow.orderOut(nil) }
        await WindowRestoration(preferences: preferences).start(relaunched, sizing: DetailsSizing())
        relaunchedRight.update(tableInput(relaunched, id: .right))
        #expect(relaunchedRight.table.tableColumns.map(\.width) == [390, 86, 154])

        let panel = try openPanel(relaunchedRight.table, in: relaunchedWindow)
        defer { panel.close() }
        let restore = try #require(descendants(NSButton.self, in: panel.contentView!).first { $0.title == "Restore Defaults" })
        restore.sendAction(restore.action, to: restore.target)
        restoration.remember(relaunched, sizing: DetailsSizing())
        let reset = makeBrowser()
        await WindowRestoration(preferences: preferences).start(reset, sizing: DetailsSizing())
        #expect(reset.right.columnWidths == BrowserColumnWidths())
        #expect(reset.left.columnWidths.size == 100 && reset.left.columnWidths.modified == 180)
    }

    @Test func detachingTheTargetClosesItsPanelAndRejectsStaleActions() throws {
        let coordinator = table(BrowserState())
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        let panel = try openPanel(coordinator.table, in: window)
        let field = try #require(descendants(NSTextField.self, in: panel.contentView!).first { $0.accessibilityLabel() == "Size column width" })
        let widths = coordinator.table.tableColumns.map(\.width)
        window.contentView = NSView()
        #expect(!panel.isVisible)
        field.stringValue = "200"
        field.sendAction(field.action, to: field.target)
        #expect(coordinator.table.tableColumns.map(\.width) == widths)
    }

    @Test func menuTargetUsesItsOwnWindowEvenWhenAnotherWindowIsKey() throws {
        let browser = BrowserState()
        let first = table(browser)
        let secondBrowser = BrowserState()
        let second = table(secondBrowser)
        let firstWindow = show(first.scroll)
        let secondWindow = show(second.scroll)
        secondWindow.makeKey()
        defer { firstWindow.orderOut(nil); secondWindow.orderOut(nil) }
        ColumnWidthsPanel.show(in: firstWindow, browser: browser)
        try #require(firstWindow.childWindows?.isEmpty == false)
        let panel = firstWindow.childWindows![0]
        defer { panel.close() }
        #expect(secondWindow.childWindows?.isEmpty != false)
        #expect(panel.parent === firstWindow)
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func enlargedControlTextFitsItsPanel(appearance: NSAppearance.Name) throws {
        let coordinator = table(BrowserState())
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        let panel = try openPanel(coordinator.table, in: window)
        defer { panel.close() }
        panel.appearance = NSAppearance(named: appearance)
        let content = try #require(panel.contentView)
        for field in descendants(NSTextField.self, in: content) {
            if let font = field.font { field.font = .systemFont(ofSize: font.pointSize * 2) }
        }
        let restore = try #require(descendants(NSButton.self, in: content).first { $0.title == "Restore Defaults" })
        restore.sendAction(restore.action, to: restore.target)
        content.layoutSubtreeIfNeeded()
        for field in descendants(NSTextField.self, in: content) where field.isEditable {
            let bounds = field.convert(field.bounds, to: content)
            #expect(content.bounds.contains(bounds))
            let textSize = (field.stringValue as NSString).size(withAttributes: [.font: field.font!])
            #expect(bounds.width >= textSize.width + 8)
        }
    }

    private func table(_ browser: BrowserState, id: PaneID = .left) -> DirectoryTable<Text>.Coordinator {
        _ = NSApplication.shared
        return DirectoryTable<Text>.Coordinator(tableInput(browser, id: id))
    }

    private func tableInput(_ browser: BrowserState, id: PaneID) -> DirectoryTable<Text> {
        DirectoryTable(browser: browser, id: id, entries: [], selection: [], renameID: nil,
                       row: { entry, _, _ in Text(entry.name) })
    }

    private func show(_ content: NSView, width: CGFloat = 900) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.orderFront(nil)
        window.setContentSize(NSSize(width: width, height: 300))
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }

    private func openPanel(_ table: DirectoryTableView, in window: NSWindow) throws -> NSWindow {
        let action = NSSelectorFromString("showColumnWidths:")
        try #require(table.responds(to: action))
        table.perform(action, with: nil)
        return try #require(window.childWindows?.first)
    }

    private func descendants<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(type, in: $0) }
    }
}
