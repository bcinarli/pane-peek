import SwiftUI
import AppKit

/// Handles context clicks without intercepting the list's normal selection gestures.
struct ItemPathContextMenu: NSViewRepresentable {
    let paths: () -> (absolute: String, relative: String)

    func makeNSView(context: Context) -> ItemPathContextMenuView {
        ItemPathContextMenuView()
    }

    func updateNSView(_ view: ItemPathContextMenuView, context: Context) {
        view.paths = paths
    }
}

final class ItemPathContextMenuView: NSView {
    var paths: () -> (absolute: String, relative: String) = { ("", "") }
    private var absolutePaths = ""
    private var relativePaths = ""

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent,
              event.type == .rightMouseDown
                || (event.type == .leftMouseDown && event.modifierFlags.contains(.control)) else {
            return nil
        }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        showMenu(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        showMenu(with: event)
    }

    private func showMenu(with event: NSEvent) {
        let copiedPaths = paths()
        guard !copiedPaths.absolute.isEmpty else { return }
        absolutePaths = copiedPaths.absolute
        relativePaths = copiedPaths.relative
        let menu = NSMenu()
        let absolute = menu.addItem(withTitle: "Copy Absolute Path", action: #selector(copyAbsolute), keyEquivalent: "")
        absolute.target = self
        let relative = menu.addItem(withTitle: "Copy Relative Path", action: #selector(copyRelative), keyEquivalent: "")
        relative.target = self
        // Publish the targeted selection before entering native menu tracking.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    @objc private func copyAbsolute() {
        PathClipboard.copy(absolutePaths)
    }

    @objc private func copyRelative() {
        PathClipboard.copy(relativePaths)
    }
}
