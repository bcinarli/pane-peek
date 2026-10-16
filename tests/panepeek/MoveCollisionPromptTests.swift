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
        let prompts = BrowserPrompts(present: { alert, owner, answer in
            presented += 1
            #expect(owner === window)
            #expect(alert.buttons.map(\.title) == ["Keep Both", "Cancel"])
            let stack = alert.accessoryView as? NSStackView
            let field = stack?.arrangedSubviews.compactMap { $0 as? NSTextField }.first { $0.isEditable }
            #expect(field?.stringValue == "report (2).pdf")
            #expect(alert.informativeText.contains("Choose another name"))
            #expect(alert.window.initialFirstResponder === field)
            field?.stringValue = "custom name.pdf"
            answer(.alertFirstButtonReturn)
            answer(.alertSecondButtonReturn)
        })
        prompts.window = window
        var results: [ItemMove.CollisionChoice] = []
        let collision = ItemMove.Collision(source: URL(fileURLWithPath: "/source/report.pdf"),
            destination: URL(fileURLWithPath: "/destination/report.pdf"), suggestedName: "report (2).pdf", errorMessage: "Choose another name")
        prompts.resolveMoveCollision(collision) { results.append($0) }
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
        let prompts = BrowserPrompts(present: { _, _, _ in presented += 1 })
        prompts.window = first
        var results: [ItemMove.CollisionChoice] = []
        let collision = ItemMove.Collision(source: URL(fileURLWithPath: "/source/a.txt"),
            destination: URL(fileURLWithPath: "/destination/a.txt"), suggestedName: "a (2).txt")
        prompts.resolveMoveCollision(collision) { results.append($0) }
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
        let prompts = BrowserPrompts(present: { alert, _, answer in
            #expect(alert.buttons.map(\.title) == ["Keep Both", "Cancel", "Replace"])
            #expect(alert.informativeText.contains("Replace"))
            answer(.alertThirdButtonReturn)
        })
        prompts.window = window
        var result: ItemMove.CollisionChoice?
        let collision = ItemMove.Collision(source: URL(fileURLWithPath: "/source/a.txt"),
            destination: URL(fileURLWithPath: "/destination/a.txt"), suggestedName: "a (2).txt", canReplace: true)
        prompts.resolveMoveCollision(collision) { result = $0 }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while result == nil && ContinuousClock.now < deadline { await Task.yield() }
        #expect(result == .replace)
    }

}
