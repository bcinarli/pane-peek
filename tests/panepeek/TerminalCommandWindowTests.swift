import AppKit
import PanePeekCore
import Testing
@testable import PanePeek

@MainActor struct TerminalCommandWindowTests {
    @Test func copyCommandWritesTheCompleteProfileEntry() throws {
        _ = NSApplication.shared
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let home = URL(fileURLWithPath: "/fixture/Home ü 'quoted'", isDirectory: true)
        let panel = TerminalCommandWindow(home: home, folderAccess: FolderAccess(), pasteboard: board)
        let content = try #require(panel.contentView)
        let button = try #require(copyButton(in: content))
        let setup = TerminalCommandSetup(home: home, app: Bundle.main.bundleURL)
        let entry = try #require(setup.manualPathEntry)

        #expect(button.title.isEmpty)
        #expect(button.image != nil)

        button.performClick(nil)

        #expect(board.string(forType: .string) == entry)
        #expect(button.toolTip == "Command copied")
    }

    private func copyButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.accessibilityLabel() == "Copy shell profile command" { return button }
        return view.subviews.lazy.compactMap { copyButton(in: $0) }.first
    }
}
