import AppKit

@MainActor class ConfirmationSheet: NSPanel {
    let buttons: [NSButton]

    init(title: String, content: [NSView], buttons: [NSButton], primary: NSButton) {
        self.buttons = buttons
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.titled], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        self.title = title
        backgroundColor = AppColours.floating
        titlebarAppearsTransparent = true
        contentView = ConfirmationSheetContent(frame: NSRect(origin: .zero, size: contentLayoutRect.size))

        let actions = NSStackView(views: buttons)
        actions.orientation = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 8
        buttons.forEach { $0.bezelStyle = .rounded }
        primary.keyEquivalent = "\r"
        primary.keyEquivalentModifierMask = []
        AppColours.styleAccentButton(primary)

        let stack = NSStackView(views: content + [actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = contentView!
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ] + (content + [actions]).map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
        container.layoutSubtreeIfNeeded()
        setContentSize(NSSize(width: 560, height: stack.fittingSize.height + 40))
        container.layoutSubtreeIfNeeded()
        defaultButtonCell = primary.cell as? NSButtonCell
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class ConfirmationSheetContent: NSView {
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
