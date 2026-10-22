import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct WindowCreationTests {
    @Test func freshWindowFixturesKeepStateIndependentAndRetainDraftsThroughSharedFavourites() async throws {
        let domain = "panepeek-window-creation-" + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        defer { preferences.removePersistentDomain(forName: domain) }
        let favourites = Favourites(preferences: preferences)
        let lifecycle = BrowserLifecycle()
        let first = NativeBrowserWindow(lifecycle: lifecycle)
        defer { first.finish() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-new-window-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("draft.txt")
        try Data("original".utf8).write(to: file)
        await first.browser.right.navigate(to: root)
        first.browser.select([file], in: .right)
        await first.browser.preview.load(first.browser.detailsSelection)
        first.browser.preview.setMode(.edit)
        await first.browser.preview.updateText("first window draft")?.value
        first.browser.right.showHiddenFiles = true
        await first.browser.right.sort(by: .lastModified, direction: .descending)
        first.browser.setMode(.onePane)
        first.controller.applyLayout(first.browser.visiblePanes)
        first.controller.view.layoutSubtreeIfNeeded()
        first.resizeDetails(to: 420)

        let second = NativeBrowserWindow(lifecycle: lifecycle)
        defer { second.finish() }
        let fresh = second.browser
        #expect(fresh.operations === first.browser.operations)
        #expect(fresh.left.directory.path == fresh.homeDirectory.path && fresh.right.directory.path == fresh.homeDirectory.path)
        #expect(fresh.mode == .twoPanes && fresh.presentationOrder == [.left, .right] && fresh.focusedPane == .left)
        #expect(fresh.left.selectedItems.isEmpty && fresh.right.selectedItems.isEmpty && fresh.preview.selection == nil)
        #expect(!fresh.left.showHiddenFiles && !fresh.right.showHiddenFiles && !fresh.preview.isDirty)
        #expect(fresh.left.sortField == .name && fresh.left.sortDirection == .ascending)
        #expect(abs(second.controller.details.view.frame.width - 300) < 1)
        #expect(first.prompts.window === first.window && second.prompts.window === second.window)

        let document = first.browser.preview.documentID
        favourites.toggle(root)
        #expect(favourites.contains(root))
        fresh.setMode(.onePane)
        second.controller.applyLayout(fresh.visiblePanes)
        second.controller.sizing.toggleExpansion()
        second.controller.applySizing()
        second.controller.view.layoutSubtreeIfNeeded()
        #expect(second.controller.splitViewItems.count == 2)
        #expect(abs(second.controller.details.view.frame.width - 726) < 1)
        #expect(first.browser.mode == .onePane && first.browser.presentationOrder == [.right, .left])
        #expect(first.browser.right.directory.path == root.path && first.browser.right.selectedItems == [file])
        #expect(first.browser.right.showHiddenFiles && first.browser.right.sortField == .lastModified)
        #expect(first.browser.preview.isDirty && first.browser.preview.text == "first window draft")
        #expect(first.browser.preview.documentID == document)
        #expect(abs(first.controller.details.view.frame.width - 420) < 1)
        favourites.remove(root)
        #expect(!favourites.contains(root) && first.browser.preview.documentID == document && first.browser.preview.isDirty)
        #expect(fresh.preview.selection == nil && !fresh.preview.isDirty)

        let quit = Task { await lifecycle.prepareToQuit() }
        try await waitForWindow { first.window.attachedSheet != nil }
        #expect(second.window.attachedSheet == nil)
        let sheet = try #require(first.window.attachedSheet)
        first.window.endSheet(sheet, returnCode: .alertSecondButtonReturn)
        #expect(await quit.value == false)
        #expect(first.browser.preview.documentID == document && first.browser.preview.isDirty)
    }
}

@MainActor private final class NativeBrowserWindow {
    let window: NSWindow
    let browser: BrowserState
    let prompts = BrowserPrompts()
    let controller: BrowserSplitView<Color, Color, Color>.Controller
    private let guardView = BrowserWindowGuard.GuardView()

    init(lifecycle: BrowserLifecycle) {
        _ = NSApplication.shared
        browser = BrowserState(operations: lifecycle.operations,
                               resolveTransferCollision: prompts.resolveTransferCollision, confirmChanges: prompts.confirmChanges)
        controller = BrowserSplitView<Color, Color, Color>.Controller(left: .clear, right: .clear, details: .clear)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 650),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        guardView.browser = browser
        guardView.prompts = prompts
        guardView.lifecycle = lifecycle
        controller.view.addSubview(guardView)
        window.orderFront(nil)
        window.setContentSize(NSSize(width: 1100, height: 650))
        controller.view.layoutSubtreeIfNeeded()
    }

    func resizeDetails(to width: CGFloat) {
        let divider = controller.splitViewItems.count - 2
        let drag = ["NSSplitViewUserResizeKey": 1, "NSSplitViewDividerIndex": divider]
        NotificationCenter.default.post(name: NSSplitView.willResizeSubviewsNotification, object: controller.splitView, userInfo: drag)
        controller.splitView.setPosition(controller.splitView.bounds.width - width - controller.splitView.dividerThickness, ofDividerAt: divider)
        controller.view.layoutSubtreeIfNeeded()
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification, object: controller.splitView, userInfo: drag)
    }

    func finish() {
        guardView.uninstall()
        window.orderOut(nil)
        window.contentViewController = nil
        window.close()
    }
}

@MainActor private func waitForWindow(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    try #require(condition())
}
