import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct BrowserSplitViewTests {
    @Test func switchingFromRightRetainsHostsAndRestoresTheOtherBrowserOnTheRight() {
        _ = NSApplication.shared
        let controller = BrowserSplitView<Color, Color, Color>.Controller(
            left: Color.clear, right: Color.clear, details: Color.clear
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.setContentSize(NSSize(width: 800, height: 500))
        controller.sizing.toggleExpansion()
        controller.applyLayout([.right])
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(controller.splitViewItems.count == 2)
        #expect(controller.splitViewItems.first?.viewController === controller.right)
        #expect(controller.left.view.window == nil)
        #expect(abs(controller.details.view.frame.width - 528) < 1)
        let detailsDrag = ["NSSplitViewUserResizeKey": 1, "NSSplitViewDividerIndex": 0]
        NotificationCenter.default.post(name: NSSplitView.willResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: detailsDrag)
        controller.splitView.setPosition(800 - 380 - controller.splitView.dividerThickness, ofDividerAt: 0)
        controller.view.layoutSubtreeIfNeeded()
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: detailsDrag)
        #expect(!controller.sizing.isExpanded && abs(controller.sizing.preferredWidth - 380) < 1)
        controller.applyLayout([.right, .left])
        controller.view.layoutSubtreeIfNeeded()
        #expect(controller.splitViewItems.map(\.viewController) == [controller.right, controller.left, controller.details])
        #expect(abs(controller.details.view.frame.width - 298) < 1)
        #expect(abs(controller.sizing.preferredWidth - 380) < 1)
        controller.applyLayout([.right])
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 380) < 1)
    }

    @Test func hiddenBrowserKeepsItsNativeListScrollPosition() throws {
        _ = NSApplication.shared
        let controller = BrowserSplitView<Color, BrowserListFixture, Color>.Controller(
            left: Color.clear, right: BrowserListFixture(), details: Color.clear
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        controller.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let scroll = try #require(scrollView(in: controller.right.view))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 400))
        scroll.reflectScrolledClipView(scroll.contentView)
        let origin = scroll.contentView.bounds.origin
        #expect(origin.y > 0)
        controller.applyLayout([.left])
        controller.view.layoutSubtreeIfNeeded()
        controller.applyLayout([.left, .right])
        controller.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(scrollView(in: controller.right.view) === scroll)
        #expect(scroll.contentView.bounds.origin == origin)
    }

    @Test(arguments: [PaneID.left, .right])
    func singlePaneSizingTracksModeBoundsAndRecoversThePreferredWidth(pane: PaneID) {
        _ = NSApplication.shared
        let sizing = DetailsSizing()
        sizing.restorePreferredWidth(900)
        let controller = BrowserSplitView<Color, Color, Color>.Controller(
            left: .clear, right: .clear, details: .clear, sizing: sizing
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.setContentSize(NSSize(width: 1400, height: 500))
        controller.applyLayout([pane])
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 900) < 1)
        sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 924) < 1)
        #expect(sizing.preferredWidth == 900 && sizing.isExpanded)

        window.setContentSize(NSSize(width: 800, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 528) < 1)
        let other: PaneID = pane == .left ? .right : .left
        controller.applyLayout([pane, other])
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 298) < 1)
        window.setContentSize(NSSize(width: 1400, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 700) < 1)
        controller.applyLayout([pane])
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 924) < 1)
        sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 900) < 1)

        let drag = ["NSSplitViewUserResizeKey": 1, "NSSplitViewDividerIndex": 0]
        NotificationCenter.default.post(name: NSSplitView.willResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: drag)
        controller.splitView.setPosition(100, ofDividerAt: 0)
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 924) < 1)
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: drag)
        #expect(abs(sizing.preferredWidth - 924) < 1 && !sizing.isExpanded)
        window.setContentSize(NSSize(width: 800, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 528) < 1)
        #expect(abs(sizing.preferredWidth - 924) < 1)
        sizing.adjust(by: -10)
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 518) < 1)
    }

    @Test func repeatedExpansionAndRestoreKeepTheBrowserProportions() {
        _ = NSApplication.shared
        let controller = BrowserSplitView<Color, Color, Color>.Controller(
            left: Color.clear, right: Color.clear, details: Color.clear
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.setContentSize(NSSize(width: 1400, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        for _ in 0..<4 {
            controller.sizing.toggleExpansion()
            controller.applySizing()
            controller.view.layoutSubtreeIfNeeded()
            #expect(abs(controller.details.view.frame.width - 700) < 1)
            #expect(abs(controller.left.view.frame.width - controller.right.view.frame.width) < 1)
            controller.sizing.toggleExpansion()
            controller.applySizing()
            controller.view.layoutSubtreeIfNeeded()
            #expect(abs(controller.details.view.frame.width - 300) < 1)
            #expect(abs(controller.left.view.frame.width - controller.right.view.frame.width) < 1)
        }
        let drag = ["NSSplitViewUserResizeKey": 1, "NSSplitViewDividerIndex": 0]
        NotificationCenter.default.post(name: NSSplitView.willResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: drag)
        controller.splitView.setPosition(400, ofDividerAt: 0)
        controller.view.layoutSubtreeIfNeeded()
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: drag)
        let chosenRatio = controller.left.view.frame.width / controller.right.view.frame.width
        for _ in 0..<3 {
            controller.sizing.toggleExpansion()
            controller.applySizing()
            controller.view.layoutSubtreeIfNeeded()
            #expect(abs(controller.left.view.frame.width / controller.right.view.frame.width - chosenRatio) < 0.01)
            controller.sizing.toggleExpansion()
            controller.applySizing()
            controller.view.layoutSubtreeIfNeeded()
            #expect(abs(controller.left.view.frame.width - 400) < 1)
        }
        window.setContentSize(NSSize(width: 800, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 1400, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.left.view.frame.width - 400) < 1)
    }

    @Test func browserDividerLeavesExpansionIntactAndDetailsDragCapturesItsWidth() {
        _ = NSApplication.shared
        let controller = BrowserSplitView<Color, Color, Color>.Controller(
            left: Color.clear, right: Color.clear, details: Color.clear
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.setContentSize(NSSize(width: 1100, height: 500))
        controller.sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        let browserDrag = ["NSSplitViewUserResizeKey": 1, "NSSplitViewDividerIndex": 0]
        NotificationCenter.default.post(name: NSSplitView.willResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: browserDrag)
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: browserDrag)
        #expect(controller.sizing.isExpanded)
        #expect(controller.sizing.preferredWidth == 300)
        let detailsDrag = ["NSSplitViewUserResizeKey": 1, "NSSplitViewDividerIndex": 1]
        NotificationCenter.default.post(name: NSSplitView.willResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: detailsDrag)
        controller.splitView.setPosition(1100 - 420 - controller.splitView.dividerThickness, ofDividerAt: 1)
        controller.view.layoutSubtreeIfNeeded()
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification,
                                        object: controller.splitView, userInfo: detailsDrag)
        #expect(!controller.sizing.isExpanded)
        #expect(abs(controller.sizing.preferredWidth - 420) < 1)
        controller.sizing.toggleExpansion()
        controller.sizing.toggleExpansion()
        #expect(abs(controller.sizing.preferredWidth - 420) < 1)
    }

    @Test func resizingRetainsTheNativeDocumentSelectionScrollAndUndo() async throws {
        _ = NSApplication.shared
        let original = (0..<100).map { "Line \($0)\n" }.joined()
        let state = PreviewState(read: { _ in .text(original) })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/layout/sample.txt"),
                                                               isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let preview = PreviewTextView(text: state.text ?? "", documentID: state.documentID,
                                      saveRevision: state.saveRevision, mode: state.mode, tokens: [],
                                      highlightRevision: state.highlightRevision,
                                      canChange: { state.canEdit && state.mode == .edit }, changed: { state.updateText($0) })
        let controller = BrowserSplitView<Color, Color, PreviewTextView>.Controller(
            left: Color.clear, right: Color.clear, details: preview
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.setContentSize(NSSize(width: 1100, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        let editor = try #require(textView(in: controller.details.view))
        window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        editor.insertText("edited ", replacementRange: editor.selectedRange())
        editor.breakUndoCoalescing()
        editor.setSelectedRange(NSRange(location: 200, length: 6))
        let scroll = try #require(editor.enclosingScrollView)
        scroll.contentView.scroll(to: NSPoint(x: scroll.contentView.bounds.minX, y: 100))
        let origin = scroll.contentView.bounds.origin
        let documentID = state.documentID
        controller.sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        controller.applyLayout([.right])
        controller.view.layoutSubtreeIfNeeded()
        controller.applyLayout([.right, .left])
        controller.view.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 800, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        controller.sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(textView(in: controller.details.view) === editor)
        #expect(window.firstResponder === editor)
        #expect(state.documentID == documentID && state.isDirty && state.mode == .edit)
        #expect(editor.string == "edited " + original && state.text == editor.string)
        #expect(editor.selectedRange() == NSRange(location: 200, length: 6))
        #expect(scroll.contentView.bounds.origin == origin)
        #expect(editor.undoManager?.canUndo == true)
        editor.undo(nil)
        #expect(editor.string == original && state.text == original && !state.isDirty)
    }

    private func textView(in view: NSView) -> EditorTextView? {
        if let text = view as? EditorTextView { return text }
        for child in view.subviews {
            if let text = textView(in: child) { return text }
        }
        return nil
    }

    private func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        for child in view.subviews {
            if let scroll = scrollView(in: child) { return scroll }
        }
        return nil
    }

    private struct BrowserListFixture: View {
        var body: some View {
            List(0..<100, id: \.self) { index in
                Text("Row \(index)").frame(height: 30)
            }
        }
    }

    @Test func nativeExpansionAndWindowResizePreserveBoundsAndPreferredWidth() {
        _ = NSApplication.shared
        let controller = BrowserSplitView<Color, Color, Color>.Controller(
            left: Color.clear, right: Color.clear, details: Color.clear
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 500),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.setContentSize(NSSize(width: 1100, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 300) < 1)
        controller.sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 550) < 1)
        #expect(controller.left.view.frame.width >= 250)
        #expect(controller.right.view.frame.width >= 250)
        window.setContentSize(NSSize(width: 800, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 298) < 1)
        controller.sizing.toggleExpansion()
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 1400, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 300) < 1)
        controller.sizing.setWidthFromUser(620)
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 800, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 298) < 1)
        #expect(controller.sizing.preferredWidth == 620)
        controller.sizing.adjust(by: -10)
        #expect(controller.sizing.preferredWidth == 288)
        controller.applySizing()
        controller.view.layoutSubtreeIfNeeded()
        #expect(abs(controller.details.view.frame.width - 288) < 1)
    }
}
