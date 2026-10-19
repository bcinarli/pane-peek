import AppKit
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor struct UnsavedChangesPromptTests {
    @Test(arguments: ["Save", "Discard", "Cancel"])
    func nativeSheetRoutesTheFirstChoiceWithATrailingDefault(action: String) async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 450),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let prompts = BrowserPrompts()
        prompts.window = window
        var results: [BrowserState.UnsavedChoice] = []
        prompts.confirmChanges("notes.md") { results.append($0) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while window.attachedSheet == nil && ContinuousClock.now < deadline { await Task.yield() }
        let sheet = try #require(window.attachedSheet as? UnsavedChangesSheet)
        let content = try #require(sheet.contentView)
        content.layoutSubtreeIfNeeded()
        let buttons = sheet.buttons
        #expect(buttons.map(\.title) == ["Cancel", "Discard", "Save"])
        let frames = buttons.map { $0.convert($0.bounds, to: content) }
        #expect(Set(frames.map(\.minY)).count == 1)
        #expect(frames[0].maxX < frames[1].minX && frames[1].maxX < frames[2].minX)
        #expect(frames.allSatisfy { $0.width > 80 && $0.height > 0 })
        let save = try #require(buttons.first { $0.title == "Save" })
        let cancel = try #require(buttons.first { $0.title == "Cancel" })
        #expect(sheet.defaultButtonCell === save.cell)
        #expect(cancel.keyEquivalent == "\u{1b}")
        if action == "Cancel" {
            let escape = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: sheet.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false, keyCode: 53))
            #expect(sheet.performKeyEquivalent(with: escape))
        } else {
            try #require(buttons.first { $0.title == action }).performClick(nil)
        }
        (action == "Save" ? cancel : save).performClick(nil)
        while results.isEmpty && ContinuousClock.now < deadline { await Task.yield() }
        let expected: BrowserState.UnsavedChoice = switch action {
        case "Save": .save
        case "Discard": .discard
        default: .cancel
        }
        #expect(results == [expected])
        #expect(window.attachedSheet == nil)
    }

    @Test func changedOwnerCancelsWithoutPresentingOnTheReplacementWindow() async {
        _ = NSApplication.shared
        let first = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let second = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        first.isReleasedWhenClosed = false
        second.isReleasedWhenClosed = false
        defer { first.close(); second.close() }
        var presented = false
        let prompts = BrowserPrompts(present: { _, _, _ in presented = true })
        prompts.window = first
        var result: BrowserState.UnsavedChoice?
        prompts.confirmChanges("notes.md") { result = $0 }
        prompts.window = second
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while result == nil && ContinuousClock.now < deadline { await Task.yield() }
        #expect(result == .cancel && !presented)
    }
}
