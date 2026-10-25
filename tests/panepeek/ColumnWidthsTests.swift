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
        #expect(left.table.tableColumns[0].width == max(160, left.scroll.contentSize.width - 72 - 136))
        #expect(left.table.tableColumns[1].width == 72 && left.table.tableColumns[2].width == 136)
        #expect(right.table.tableColumns.map(\.width) == peerWidths)
        #expect(editor.string == "draft")
        #expect(window.firstResponder === editor && editor.selectedRange() == NSRange(location: 1, length: 2))
        panel.cancelOperation(nil)
        #expect(!panel.isVisible && panel.parent == nil)
        #expect(window.firstResponder === editor)
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
        return DirectoryTable<Text>.Coordinator(DirectoryTable(browser: browser, id: id, entries: [], selection: [], renameID: nil,
            row: { entry, _, _ in Text(entry.name) }))
    }

    private func show(_ content: NSView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.orderFront(nil)
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
