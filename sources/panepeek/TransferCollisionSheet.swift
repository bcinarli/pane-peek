import AppKit
import PanePeekCore

@MainActor final class TransferCollisionSheet: ConfirmationSheet {
    let input: NSTextField
    let message: NSTextField
    private(set) var choice: ItemMove.CollisionChoice = .cancel
    private var answered = false

    init(_ collision: ItemMove.Collision) {
        input = NSTextField(string: collision.suggestedName)
        let keep = NSButton(title: "Keep Both", target: nil, action: nil)
        let cancel = NSButton(title: "Cancel", target: nil, action: nil)
        let replace = NSButton(title: "Replace", target: nil, action: nil)
        message = NSTextField(wrappingLabelWithString: (collision.canReplace
            ? "Replace the existing file, or choose a different name to keep both items."
            : "Choose a different name to keep both items.") + (collision.errorMessage.map { "\n\n" + $0 } ?? ""))
        let heading = NSTextField(wrappingLabelWithString: "“\(collision.destination.lastPathComponent)” already exists")
        heading.font = .preferredFont(forTextStyle: .headline)
        let paths = NSTextField(wrappingLabelWithString: "Source: \(collision.source.path)\nDestination: \(collision.destination.path)")
        paths.font = .preferredFont(forTextStyle: .caption1)
        paths.textColor = .secondaryLabelColor
        paths.isSelectable = true
        let nameLabel = NSTextField(labelWithString: "Keep both as:")
        input.setAccessibilityLabel(collision.operation == .copy ? "New name for copied item" : "New name for moved item")
        input.setAccessibilityHelp("Keep Both uses this name and retains the existing destination.")
        super.init(title: collision.operation == .copy ? "Copy item" : "Move item",
            content: [heading, message, paths, nameLabel, input],
            buttons: collision.canReplace ? [cancel, replace, keep] : [cancel, keep], primary: keep)
        initialFirstResponder = input
        input.target = self
        input.action = #selector(keepBoth)
        buttons.forEach { $0.target = self }
        keep.action = #selector(keepBoth)
        cancel.action = #selector(cancelTransfer)
        cancel.keyEquivalent = "\u{1b}"
        cancel.keyEquivalentModifierMask = []
        replace.action = #selector(replaceItem)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func keepBoth() { finish(.keepBoth(input.stringValue)) }
    @objc private func cancelTransfer() { finish(.cancel) }
    @objc private func replaceItem() { finish(.replace) }

    private func finish(_ answer: ItemMove.CollisionChoice) {
        guard !answered else { return }
        answered = true
        choice = answer
        sheetParent?.endSheet(self)
    }
}
