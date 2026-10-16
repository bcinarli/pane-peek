import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@MainActor
struct BrowserLayoutToggleTests {
    @Test func segmentActionsRetainTheActiveBrowserAndRestoreItsPeer() throws {
        let browser = BrowserState()
        browser.focus(.right)
        let coordinator = BrowserLayoutToggle.Coordinator(mode: Binding(
            get: { browser.mode }, set: { browser.setMode($0) }
        ))
        let control = coordinator.control
        let action = try #require(control.action)
        for _ in 0..<2 {
            control.selectedSegment = 0
            #expect(control.sendAction(action, to: control.target))
            #expect(browser.mode == .onePane)
            #expect(browser.visiblePanes == [.right] && browser.focusedPane == .right)
        }
        control.selectedSegment = 1
        #expect(control.sendAction(action, to: control.target))
        #expect(browser.mode == .twoPanes)
        #expect(browser.visiblePanes == [.right, .left] && browser.focusedPane == .right)
    }

    @Test func externalModeChangesUpdateSelectionWithoutWritingBack() {
        var mode = BrowserMode.twoPanes
        var writes = 0
        let binding = Binding(get: { mode }, set: { mode = $0; writes += 1 })
        let coordinator = BrowserLayoutToggle.Coordinator(mode: binding)
        mode = .onePane
        coordinator.update(binding)
        #expect(coordinator.control.selectedSegment == 0)
        mode = .twoPanes
        coordinator.update(binding)
        #expect(coordinator.control.selectedSegment == 1)
        #expect(writes == 0)
    }
}
