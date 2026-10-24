import AppKit
import Observation

@MainActor final class UpdateWindow: NSPanel, NSWindowDelegate {
    private let updates: AppUpdates
    private let installedVersion: String?
    let heading = NSTextField(wrappingLabelWithString: "")
    let message = NSTextField(wrappingLabelWithString: "")
    private let progress = UpdateDialogProgress()
    private let stack = NSStackView()
    private let footer = NSStackView()
    private var displayedPhase: AppUpdates.Phase?
    private var displayedAutomatic = false
    private var actions: [() -> Void] = []
    private(set) var actionButtons: [NSButton] = []

    init(updates: AppUpdates, installedVersion: String? = nil) {
        self.updates = updates
        self.installedVersion = installedVersion ?? Self.installedVersion()
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
                   styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "PanePeek Updates"
        isReleasedWhenClosed = false
        isRestorable = false
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        tabbingMode = .disallowed
        titlebarAppearsTransparent = true
        backgroundColor = UpdateDialogColours.background
        delegate = self
        setAccessibilitySubrole(.dialog)

        let content = UpdateDialogContent()
        contentView = content
        let icon = NSImageView(image: NSApplication.shared.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.textColor = UpdateDialogColours.text
        message.font = .preferredFont(forTextStyle: .body)
        message.textColor = UpdateDialogColours.secondaryText
        for field in [heading, message] {
            field.preferredMaxLayoutWidth = 432
            field.maximumNumberOfLines = 0
            field.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        progress.heightAnchor.constraint(equalToConstant: 8).isActive = true
        progress.setAccessibilityElement(true)
        progress.setAccessibilityRole(.progressIndicator)
        progress.setAccessibilityLabel("Update download")
        progress.setAccessibilityMinValue(0)
        progress.setAccessibilityMaxValue(1)
        footer.orientation = .horizontal
        footer.spacing = 8
        footer.alignment = .centerY
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in [icon, heading, message, progress, footer] { stack.addArrangedSubview(view) }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            heading.widthAnchor.constraint(equalToConstant: 432),
            message.widthAnchor.constraint(equalTo: heading.widthAnchor),
            progress.widthAnchor.constraint(equalTo: heading.widthAnchor),
            footer.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
        content.onAppearanceChange = { [weak self] in self?.refreshButtons() }
        observe()
        center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        guard updates.isEnabled else { return }
        let wasVisible = isVisible
        updates.check(reusingResult: wasVisible)
        makeKeyAndOrderFront(nil)
        if !wasVisible, let operation = updates.operation, operation.isCancelled {
            Task { [weak self] in
                await operation.value
                guard let self, isVisible else { return }
                updates.check()
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        updates.closeWindow()
    }

    override func cancelOperation(_ sender: Any?) { performClose(sender) }

    private func observe() {
        withObservationTracking { refresh() } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func refresh() {
        let phase = updates.phase
        let automatic = updates.isAutomaticPresentation
        if automatic {
            if updates.isReminderPresented {
                if !isVisible { orderFront(nil) }
            } else if isVisible { orderOut(nil) }
        }
        switch phase {
        case .hidden, .checking:
            heading.stringValue = "Checking for updates…"
            message.stringValue = ""
        case .current:
            heading.stringValue = "You’re up to date!"
            message.stringValue = installedVersion.map { "PanePeek \($0) is installed. No newer version is available." }
                ?? "No newer version of PanePeek is available."
        case .available:
            heading.stringValue = "PanePeek \(updates.offer?.version ?? "") is available"
            message.stringValue = updates.offer.map { "Installed version: \($0.installedVersion)" } ?? ""
        case .downloading:
            heading.stringValue = updates.offer?.progressTitle ?? "Preparing update…"
            message.stringValue = ""
        case .opening:
            heading.stringValue = "Preparing update…"
            message.stringValue = ""
        case .completed:
            heading.stringValue = updates.completion?.title ?? "Update ready"
            message.stringValue = updates.completion?.message ?? ""
        case .failed:
            heading.stringValue = "Update needs attention"
            message.stringValue = updates.errorMessage ?? ""
        }
        message.isHidden = message.stringValue.isEmpty
        progress.isHidden = phase != .downloading
        progress.fraction = updates.progress
        standardWindowButton(.closeButton)?.isEnabled = phase != .opening
        if displayedPhase != phase || displayedAutomatic != automatic {
            displayedPhase = phase
            displayedAutomatic = automatic
            rebuildActions()
            contentView?.layoutSubtreeIfNeeded()
            let size = NSSize(width: 480, height: stack.fittingSize.height + 48)
            let top = frame.maxY
            setContentSize(size)
            setFrameOrigin(NSPoint(x: frame.minX, y: top - frame.height))
            if isVisible {
                NSAccessibility.post(element: self, notification: .announcementRequested,
                    userInfo: [.announcement: [heading.stringValue, message.stringValue].filter { !$0.isEmpty }.joined(separator: ". "),
                               .priority: NSAccessibilityPriorityLevel.medium.rawValue])
            }
        }
        refreshButtons()
    }

    private func rebuildActions() {
        for button in actionButtons { footer.removeArrangedSubview(button); button.removeFromSuperview() }
        actionButtons = []
        actions = []
        defaultButtonCell = nil
        switch updates.phase {
        case .hidden, .checking: addButton("Cancel", close: true)
        case .current: addButton("OK", primary: true, close: true)
        case .available:
            if updates.isAutomaticPresentation { addButton("Skip this version", action: updates.skipVersion) }
            addButton("Later", close: true)
            if let offer = updates.offer { addButton(offer.actionTitle, primary: true, help: offer.actionHelp, action: updates.download) }
        case .downloading: addButton("Cancel", action: updates.cancel)
        case .opening: break
        case .completed:
            addButton("Done", close: true)
            if let completion = updates.completion { addButton(completion.reopenTitle, primary: true, action: updates.reopen) }
        case .failed:
            addButton("Later", close: true)
            addButton("Try again", primary: true, action: updates.retry)
        }
    }

    private func addButton(_ title: String, primary: Bool = false, close: Bool = false, help: String? = nil, action: (() -> Void)? = nil) {
        let button = NSButton(title: title, target: self, action: #selector(performAction(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = .preferredFont(forTextStyle: .body)
        button.toolTip = help
        button.tag = actions.count
        if primary { button.keyEquivalent = "\r"; button.keyEquivalentModifierMask = []; defaultButtonCell = button.cell as? NSButtonCell }
        actions.append(close ? { [weak self] in self?.performClose(nil) } : action ?? {})
        actionButtons.append(button)
        footer.addView(button, in: .trailing)
    }

    private func refreshButtons() {
        for button in actionButtons {
            let primary = button.keyEquivalent == "\r"
            button.isEnabled = !updates.isBusy || updates.phase == .checking || updates.phase == .downloading
            button.bezelColor = primary ? UpdateDialogColours.accent : UpdateDialogColours.button
            let colour = NSColor(name: nil) { [weak button] _ in
                guard let button, button.isEnabled else { return .disabledControlTextColor }
                guard primary, NSApp.isActive, button.window?.isKeyWindow == true else { return UpdateDialogColours.text }
                return UpdateDialogColours.accentInk
            }
            button.attributedTitle = NSAttributedString(string: button.title,
                attributes: [.font: button.font ?? NSFont.preferredFont(forTextStyle: .body), .foregroundColor: colour])
        }
    }

    @objc private func performAction(_ button: NSButton) {
        guard button.isEnabled, actions.indices.contains(button.tag) else { return }
        actions[button.tag]()
    }

    private static func installedVersion(in bundle: Bundle = .main) -> String? {
        guard let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, !version.isEmpty else { return nil }
        if let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String, !build.isEmpty { return "\(version) (\(build))" }
        return version
    }
}

@MainActor enum UpdateDialogColours {
    static let background = adaptive(light: 0xEFF1F5, dark: 0x24273A)
    static let text = adaptive(light: 0x4C4F69, dark: 0xCAD3F5)
    static let secondaryText = adaptive(light: 0x5C5F77, dark: 0xB8C0E0)
    static let button = adaptive(light: 0xE6E9EF, dark: 0x363A4F)
    static let accent = adaptive(light: 0x8839EF, dark: 0xC6A0F6)
    static let accentInk = adaptive(light: 0xEFF1F5, dark: 0x24273A)

    private static func adaptive(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let hex = AppColours.isDark(appearance) ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
}

private final class UpdateDialogContent: NSView {
    var onAppearanceChange: (() -> Void)?
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) { UpdateDialogColours.background.setFill(); dirtyRect.fill() }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        onAppearanceChange?()
    }
}

private final class UpdateDialogProgress: NSView {
    var fraction: Double? {
        didSet {
            setAccessibilityValue(fraction)
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        UpdateDialogColours.button.setFill()
        track.fill()
        guard let fraction else { return }
        let filled = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width * min(1, max(0, fraction)), height: bounds.height)
        UpdateDialogColours.accent.setFill()
        NSBezierPath(roundedRect: filled, xRadius: 4, yRadius: 4).fill()
    }
}
