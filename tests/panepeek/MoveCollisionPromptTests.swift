import AppKit
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor struct MoveCollisionPromptTests {
    @Test func collisionPromptReturnsTheEditedNameOnlyOnce() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        var presented = 0
        let prompts = BrowserPrompts(presentCollision: { alert, owner, answer in
            presented += 1
            #expect(owner === window)
            #expect(alert.buttons.map(\.title) == ["Cancel", "Keep Both"])
            let field: NSTextField? = alert.input
            #expect(field?.stringValue == "report (2).pdf")
            #expect(alert.message.stringValue.contains("Choose another name"))
            #expect(alert.initialFirstResponder === field)
            field?.stringValue = "custom name.pdf"
            answer(.keepBoth(alert.input.stringValue))
            answer(.cancel)
        })
        prompts.window = window
        var results: [ItemMove.CollisionChoice] = []
        let collision = ItemMove.Collision(source: URL(fileURLWithPath: "/source/report.pdf"),
            destination: URL(fileURLWithPath: "/destination/report.pdf"), suggestedName: "report (2).pdf", errorMessage: "Choose another name")
        prompts.resolveTransferCollision(collision) { results.append($0) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while results.isEmpty && ContinuousClock.now < deadline { await Task.yield() }
        #expect(presented == 1 && results.count == 1 && results[0] == .keepBoth("custom name.pdf"))
    }

    @Test func changedOwnerCancelsWithoutShowingThePromptOnAnotherWindow() async throws {
        _ = NSApplication.shared
        let first = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let second = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        first.isReleasedWhenClosed = false
        second.isReleasedWhenClosed = false
        defer { first.close(); second.close() }
        var presented = 0
        let prompts = BrowserPrompts(presentCollision: { _, _, _ in presented += 1 })
        prompts.window = first
        var results: [ItemMove.CollisionChoice] = []
        let collision = ItemMove.Collision(source: URL(fileURLWithPath: "/source/a.txt"),
            destination: URL(fileURLWithPath: "/destination/a.txt"), suggestedName: "a (2).txt")
        prompts.resolveTransferCollision(collision) { results.append($0) }
        prompts.window = second
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while results.isEmpty && ContinuousClock.now < deadline { await Task.yield() }
        #expect(presented == 0 && results.count == 1 && results[0] == .cancel)
    }
    @Test func regularFileCollisionExposesAnExplicitReplaceChoice() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let prompts = BrowserPrompts(presentCollision: { alert, _, answer in
            #expect(alert.buttons.map(\.title) == ["Cancel", "Replace", "Keep Both"])
            alert.contentView?.layoutSubtreeIfNeeded()
            let frames = alert.buttons.map(\.frame)
            #expect(Set(frames.map(\.minY)).count == 1 && frames.allSatisfy { $0.width > 80 && $0.height > 0 })
            #expect(frames[0].maxX < frames[1].minX && frames[1].maxX < frames[2].minX)
            #expect(alert.message.stringValue.contains("Replace"))
            answer(.replace)
        })
        prompts.window = window
        var result: ItemMove.CollisionChoice?
        let collision = ItemMove.Collision(source: URL(fileURLWithPath: "/source/a.txt"),
            destination: URL(fileURLWithPath: "/destination/a.txt"), suggestedName: "a (2).txt", canReplace: true)
        prompts.resolveTransferCollision(collision) { result = $0 }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while result == nil && ContinuousClock.now < deadline { await Task.yield() }
        #expect(result == .replace)
    }

    @Test(arguments: [false, true])
    func nativeSheetRoutesNameSubmissionAndEscapeToItsOwningWindow(cancel: Bool) async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 450), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let prompts = BrowserPrompts()
        prompts.window = window
        var result: ItemMove.CollisionChoice?
        let collision = ItemMove.Collision(source: URL(fileURLWithPath: "/source/a.txt"),
            destination: URL(fileURLWithPath: "/destination/a.txt"), suggestedName: "a (2).txt", canReplace: true, operation: .copy)
        prompts.resolveTransferCollision(collision) { result = $0 }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while window.attachedSheet == nil && ContinuousClock.now < deadline { await Task.yield() }
        let sheet = try #require(window.attachedSheet as? TransferCollisionSheet)
        #expect(sheet.title == "Copy item" && sheet.sheetParent === window)
        #expect(sheet.defaultButtonCell === sheet.buttons.last?.cell)
        sheet.input.stringValue = "custom.txt"
        let key = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: sheet.windowNumber, context: nil, characters: cancel ? "\u{1b}" : "\r",
            charactersIgnoringModifiers: cancel ? "\u{1b}" : "\r", isARepeat: false, keyCode: cancel ? 53 : 36))
        if cancel { #expect(sheet.performKeyEquivalent(with: key)) }
        else {
            #expect(sheet.input.sendAction(sheet.input.action, to: sheet.input.target))
            sheet.buttons.first { $0.title == "Cancel" }?.performClick(nil)
        }
        while result == nil && ContinuousClock.now < deadline { await Task.yield() }
        #expect(result == (cancel ? .cancel : .keepBoth("custom.txt")))
        #expect(window.attachedSheet == nil)
    }

}
