import AppKit
import PanePeekCore

@MainActor final class TransferCollisionSheet: NSPanel {
    let input: NSTextField
    let buttons: [NSButton]
    let message: NSTextField
    private(set) var choice: ItemMove.CollisionChoice = .cancel
    private var answered = false

    init(_ collision: ItemMove.Collision) {
        input = NSTextField(string: collision.suggestedName)
        let keep = NSButton(title: "Keep Both", target: nil, action: nil)
        let cancel = NSButton(title: "Cancel", target: nil, action: nil)
        let replace = NSButton(title: "Replace", target: nil, action: nil)
        buttons = collision.canReplace ? [keep, cancel, replace] : [keep, cancel]
        message = NSTextField(wrappingLabelWithString: (collision.canReplace
            ? "Replace the existing file, or choose a different name to keep both items."
            : "Choose a different name to keep both items.") + (collision.errorMessage.map { "\n\n" + $0 } ?? ""))
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 320), styleMask: [.titled], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        title = collision.operation == .copy ? "Copy item" : "Move item"
        backgroundColor = AppColours.floating
        titlebarAppearsTransparent = true
        contentView = CollisionSheetContent(frame: NSRect(origin: .zero, size: contentLayoutRect.size))

        let heading = NSTextField(wrappingLabelWithString: "“\(collision.destination.lastPathComponent)” already exists")
        heading.font = .preferredFont(forTextStyle: .headline)
        let paths = NSTextField(wrappingLabelWithString: "Source: \(collision.source.path)\nDestination: \(collision.destination.path)")
        paths.font = .preferredFont(forTextStyle: .caption1)
        paths.textColor = .secondaryLabelColor
        paths.isSelectable = true
        let nameLabel = NSTextField(labelWithString: "Keep both as:")
        input.setAccessibilityLabel(collision.operation == .copy ? "New name for copied item" : "New name for moved item")
        input.setAccessibilityHelp("Keep Both uses this name and retains the existing destination.")
        initialFirstResponder = input
        input.target = self
        input.action = #selector(keepBoth)

        let actions = NSStackView(views: buttons)
        actions.orientation = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 8
        for button in buttons {
            button.bezelStyle = .rounded
            button.target = self
        }
        keep.action = #selector(keepBoth)
        keep.keyEquivalent = "\r"
        keep.keyEquivalentModifierMask = []
        AppColours.styleAccentButton(keep)
        cancel.action = #selector(cancelTransfer)
        cancel.keyEquivalent = "\u{1b}"
        cancel.keyEquivalentModifierMask = []
        replace.action = #selector(replaceItem)

        let stack = NSStackView(views: [heading, message, paths, nameLabel, input, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ] + [heading, message, paths, input, actions].map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
        content.layoutSubtreeIfNeeded()
        setContentSize(NSSize(width: 560, height: stack.fittingSize.height + 40))
        content.layoutSubtreeIfNeeded()
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

private final class CollisionSheetContent: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        AppColours.floating.setFill()
        dirtyRect.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
