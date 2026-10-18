import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct AccentControlsTests {
    @Test func defaultButtonHandlesReturnAndRetainsItsDisabledGuard() throws {
        _ = NSApplication.shared
        var presses = 0
        let coordinator = AccentButton.Coordinator(title: "Go", action: { presses += 1 })
        let key = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        #expect(coordinator.button.performKeyEquivalent(with: key))
        #expect(presses == 1)
        coordinator.button.isEnabled = false
        _ = coordinator.button.performKeyEquivalent(with: key)
        #expect(presses == 1)
    }

    @Test func textModeActionsAndExternalChangesKeepTheSameDraft() async throws {
        _ = NSApplication.shared
        let preview = PreviewState(read: { _ in .text("original") })
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/fixture/draft.txt"), isDirectory: false)
        await preview.load(DetailsSelection(item: item, listingRevision: UUID()))
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        let document = preview.documentID
        let binding = Binding(get: { preview.mode }, set: { preview.setMode($0) })
        let coordinator = TextModeToggle.Coordinator(mode: binding)
        #expect(coordinator.control.selectedSegment == 1)
        let action = try #require(coordinator.control.action)
        coordinator.control.selectedSegment = 0
        #expect(coordinator.control.sendAction(action, to: coordinator.control.target))
        #expect(preview.mode == .preview && preview.text == "draft" && preview.isDirty)
        #expect(preview.documentID == document)
        coordinator.control.isEnabled = false
        coordinator.control.selectedSegment = 1
        _ = coordinator.control.sendAction(action, to: coordinator.control.target)
        #expect(preview.mode == .preview)
        coordinator.control.isEnabled = true
        preview.setMode(.edit)
        coordinator.update(binding)
        #expect(coordinator.control.selectedSegment == 1)
        #expect(preview.documentID == document && preview.text == "draft")
    }
}
