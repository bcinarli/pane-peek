import SwiftUI
import AppKit

/// Handles context clicks without intercepting the list's normal selection gestures.
struct ItemPathContextMenu: NSViewRepresentable {
    let duplicate: () -> (() -> Void)?
    let copyToOtherPane: () -> (() -> Void)?
    let moveToOtherPane: () -> (() -> Void)?
    let moveToTrash: () -> (() -> Void)?
    let openInFinder: () -> (() -> Void)?
    let rename: () -> (() -> Void)?
    var openContainingFolder: () -> (() -> Void)? = { nil }
    let paths: (@escaping (String, String) -> Void) -> Void

    func makeNSView(context: Context) -> ItemPathContextMenuView {
        ItemPathContextMenuView()
    }

    func updateNSView(_ view: ItemPathContextMenuView, context: Context) {
        view.paths = paths
        view.duplicate = duplicate
        view.copyToOtherPane = copyToOtherPane
        view.moveToOtherPane = moveToOtherPane
        view.moveToTrash = moveToTrash
        view.openInFinder = openInFinder
        view.rename = rename
        view.openContainingFolder = openContainingFolder
    }
}

final class ItemPathContextMenuView: NSView {
    var paths: (@escaping (String, String) -> Void) -> Void = { _ in }
    var duplicate: () -> (() -> Void)? = { nil }
    private var duplicateAction: (() -> Void)?
    var copyToOtherPane: () -> (() -> Void)? = { nil }
    private var copyAction: (() -> Void)?
    var moveToOtherPane: () -> (() -> Void)? = { nil }
    private var moveAction: (() -> Void)?
    var moveToTrash: () -> (() -> Void)? = { nil }
    private var trashAction: (() -> Void)?
    var rename: () -> (() -> Void)? = { nil }
    var openInFinder: () -> (() -> Void)? = { nil }
    var openContainingFolder: () -> (() -> Void)? = { nil }
    private var containingFolderAction: (() -> Void)?
    private var finderAction: (() -> Void)?
    private var renameAction: (() -> Void)?
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

    func showMenu(with event: NSEvent? = nil) {
        paths { [weak self] absolutePath, relativePath in
            guard let self, !absolutePath.isEmpty else { return }
            self.absolutePaths = absolutePath
            self.relativePaths = relativePath
            let menu = NSMenu()
            menu.autoenablesItems = false
            self.finderAction = self.openInFinder()
            let finder = menu.addItem(withTitle: "Reveal in Finder", action: #selector(self.openFinder), keyEquivalent: "")
            finder.target = self
            finder.isEnabled = self.finderAction != nil
            self.containingFolderAction = self.openContainingFolder()
            if self.containingFolderAction != nil {
                let containing = menu.addItem(withTitle: "Open Containing Folder", action: #selector(self.openParent), keyEquivalent: "")
                containing.target = self
            }
            self.duplicateAction = self.duplicate()
            let duplicate = menu.addItem(withTitle: "Duplicate", action: #selector(self.duplicateItem), keyEquivalent: "")
            duplicate.target = self
            duplicate.isEnabled = self.duplicateAction != nil
            self.renameAction = self.rename()
            let rename = menu.addItem(withTitle: "Rename", action: #selector(self.beginRename), keyEquivalent: "")
            rename.target = self
            rename.isEnabled = self.renameAction != nil
            menu.addItem(.separator())
            let absolute = menu.addItem(withTitle: "Copy Absolute Path", action: #selector(self.copyAbsolute), keyEquivalent: "")
            absolute.target = self
            let relative = menu.addItem(withTitle: "Copy Relative Path", action: #selector(self.copyRelative), keyEquivalent: "")
            relative.target = self
            menu.addItem(.separator())
            self.copyAction = self.copyToOtherPane()
            let copy = menu.addItem(withTitle: "Copy to Other Pane", action: #selector(self.copyItem), keyEquivalent: "")
            copy.target = self
            copy.isEnabled = self.copyAction != nil
            self.moveAction = self.moveToOtherPane()
            let move = menu.addItem(withTitle: "Move to Other Pane", action: #selector(self.moveItem), keyEquivalent: "")
            move.target = self
            move.isEnabled = self.moveAction != nil
            menu.addItem(.separator())
            self.trashAction = self.moveToTrash()
            let trash = menu.addItem(withTitle: "Move to Trash", action: #selector(self.trashItem), keyEquivalent: "")
            trash.target = self
            trash.isEnabled = self.trashAction != nil
            // Publish selection and finish any discard sheet before native menu tracking.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                if let event { NSMenu.popUpContextMenu(menu, with: event, for: self) }
                else { menu.popUp(positioning: nil, at: NSPoint(x: bounds.minX + 10, y: bounds.midY), in: self) }
            }
        }
    }

    @objc private func copyAbsolute() {
        PathClipboard.copy(absolutePaths)
    }

    @objc private func copyRelative() {
        PathClipboard.copy(relativePaths)
    }

    @objc private func copyItem() { copyAction?() }
    @objc private func duplicateItem() { duplicateAction?() }
    @objc private func moveItem() { moveAction?() }
    @objc private func trashItem() { trashAction?() }

    @objc private func beginRename() { renameAction?() }
    @objc private func openParent() { containingFolderAction?() }
    @objc private func openFinder() { finderAction?() }
}
