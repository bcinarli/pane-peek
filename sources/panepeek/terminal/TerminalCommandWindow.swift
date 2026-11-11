import AppKit
import PanePeekCore

@MainActor final class TerminalCommandWindow: NSPanel {
    private enum Action: Int, CaseIterable {
        case allowAccess, uninstall, installLauncher, installAndConfigure, configureZsh, refresh
        var title: String {
            switch self {
            case .allowAccess: "Allow Access…"
            case .uninstall: "Uninstall"
            case .installLauncher: "Install Launcher Only"
            case .installAndConfigure: "Install and Configure zsh"
            case .configureZsh: "Configure zsh"
            case .refresh: "Check Again"
            }
        }

        var configuresZsh: Bool { self == .installAndConfigure || self == .configureZsh }
    }

    private let setup: TerminalCommandSetup
    private let folderAccess: FolderAccess
    private let preferences: UserDefaults
    private let pasteboard: NSPasteboard
    private let supportsZshSetup: Bool
    private let stack = NSStackView()
    private let heading = NSTextField(wrappingLabelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let copyButton = NSButton()
    private let copyIcon = NSImage(named: "icon-copy")
        ?? NSImage(systemSymbolName: "square.on.square", accessibilityDescription: nil)
    private var buttons: [Action: NSButton] = [:]
    private var working = false
    private static let receiptKey = "terminalCommandOwnership"
    private static let copyLabel = "Copy shell profile command"
    private static let width: CGFloat = 520

    init(home: URL, folderAccess: FolderAccess, preferences: UserDefaults = .standard,
         pasteboard: NSPasteboard = .general) {
        setup = TerminalCommandSetup(home: home, app: Bundle.main.bundleURL)
        self.folderAccess = folderAccess
        self.preferences = preferences
        self.pasteboard = pasteboard
        supportsZshSetup = FolderAccess.accountShell == "/bin/zsh"
            && ProcessInfo.processInfo.environment["ZDOTDIR"] == nil
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 280),
                   styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Terminal Command"
        isReleasedWhenClosed = false
        isRestorable = false
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        tabbingMode = .disallowed
        autorecalculatesKeyViewLoop = true
        titlebarAppearsTransparent = true
        backgroundColor = UpdateDialogColours.background
        setAccessibilitySubrole(.dialog)

        let content = PanePeekDialogContent()
        contentView = content
        let icon = NSImageView(image: NSApplication.shared.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.textColor = UpdateDialogColours.text
        message.font = .preferredFont(forTextStyle: .body)
        message.textColor = UpdateDialogColours.text
        let path = NSTextField(wrappingLabelWithString: setup.command.path)
        path.font = .monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        path.textColor = UpdateDialogColours.secondaryText
        path.isSelectable = true
        path.lineBreakMode = .byCharWrapping
        path.setAccessibilityLabel("Command location")
        let usage = NSTextField(wrappingLabelWithString: "After setup, run panepeek or panepeek --help in Terminal.")
        usage.font = .preferredFont(forTextStyle: .body)
        usage.textColor = UpdateDialogColours.text
        var fields = [heading, message, path, usage]
        let commandRow: NSStackView?
        if let pathEntry = setup.manualPathEntry {
            let instructions = NSTextField(wrappingLabelWithString: "For manual Bash or zsh setup, add this to your shell profile after installing the launcher.")
            instructions.font = usage.font
            instructions.textColor = UpdateDialogColours.text
            fields.append(instructions)
            commandRow = makeCommandRow(pathEntry)
        } else {
            commandRow = nil
        }

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 8
        footer.alignment = .centerY
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        footer.addView(closeButton, in: .trailing)
        for action in Action.allCases {
            let button = NSButton(title: action.title, target: self, action: #selector(performAction(_:)))
            button.tag = action.rawValue
            buttons[action] = button
            footer.addView(button, in: .trailing)
        }
        for button in [closeButton] + Array(buttons.values) {
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .preferredFont(forTextStyle: .body)
        }
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(icon)
        for field in fields { stack.addArrangedSubview(field) }
        if let commandRow { stack.addArrangedSubview(commandRow) }
        stack.addArrangedSubview(footer)
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            footer.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
        for field in fields {
            field.preferredMaxLayoutWidth = Self.width - 48
            field.maximumNumberOfLines = 0
            field.setContentCompressionResistancePriority(.required, for: .vertical)
            field.widthAnchor.constraint(equalToConstant: Self.width - 48).isActive = true
        }
        present("Checking terminal command…", "", actions: [])
        center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeCommandRow(_ text: String) -> NSStackView {
        let buttonSize: CGFloat = 28
        let spacing: CGFloat = 8
        let boxWidth = Self.width - 48 - buttonSize - spacing
        copyButton.title = ""
        copyButton.imagePosition = .imageOnly
        copyButton.isBordered = false
        copyButton.contentTintColor = UpdateDialogColours.accent
        copyButton.focusRingType = .exterior
        copyButton.target = self
        copyButton.action = #selector(copyProfileEntry)
        copyButton.setAccessibilityLabel(Self.copyLabel)
        copyButton.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
        copyButton.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
        resetCopyFeedback()

        let row = NSStackView(views: [Self.makeCommandBox(text, width: boxWidth), copyButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = spacing
        return row
    }

    private static func makeCommandBox(_ text: String, width: CGFloat) -> NSBox {
        let horizontalInset: CGFloat = 12
        let verticalInset: CGFloat = 10
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = 8
        box.borderWidth = 1
        box.borderColor = .separatorColor
        box.fillColor = UpdateDialogColours.button
        box.widthAnchor.constraint(equalToConstant: width).isActive = true

        let entry = NSTextField(wrappingLabelWithString: text)
        entry.font = .monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
        entry.textColor = UpdateDialogColours.text
        entry.isSelectable = true
        entry.lineBreakMode = .byCharWrapping
        entry.maximumNumberOfLines = 0
        entry.preferredMaxLayoutWidth = width - 2 * horizontalInset
        entry.setContentCompressionResistancePriority(.required, for: .vertical)
        entry.setAccessibilityLabel("Shell profile entry")
        entry.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(entry)
        NSLayoutConstraint.activate([
            entry.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: horizontalInset),
            entry.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -horizontalInset),
            entry.topAnchor.constraint(equalTo: box.topAnchor, constant: verticalInset),
            entry.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -verticalInset)
        ])
        return box
    }

    func show() {
        resetCopyFeedback()
        makeKeyAndOrderFront(nil)
        perform(.refresh)
    }

    private func resetCopyFeedback() {
        copyButton.image = copyIcon
        copyButton.toolTip = Self.copyLabel
    }

    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    @objc private func closePanel() { performClose(nil) }
    @objc private func copyProfileEntry() {
        guard let entry = setup.manualPathEntry else { return }
        let copied = FileClipboard.writeText(entry, to: pasteboard)
        let feedback = copied ? "Command copied" : "Could not copy command"
        copyButton.image = NSImage(systemSymbolName: copied ? "checkmark" : "exclamationmark.circle", accessibilityDescription: nil)
        copyButton.toolTip = feedback
        if isVisible {
            NSAccessibility.post(element: copyButton, notification: .announcementRequested,
                userInfo: [.announcement: feedback,
                           .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
    }

    @objc private func performAction(_ button: NSButton) {
        guard let action = Action(rawValue: button.tag), !button.isHidden else { return }
        perform(action)
    }

    private func perform(_ action: Action) {
        guard !working, !action.configuresZsh || supportsZshSetup else { return }
        working = true
        let progress = switch action {
        case .installLauncher, .installAndConfigure: "Installing terminal launcher…"
        case .configureZsh: "Configuring zsh profile…"
        case .uninstall: "Removing terminal command…"
        case .allowAccess, .refresh: "Checking terminal command…"
        }
        present(progress, "", actions: [])
        Task {
            defer { working = false }
            do {
                guard let grant = try await access(allowChooser: action == .allowAccess) else {
                    present("Home folder access needed", "Allow access to manage the terminal launcher and optional zsh setup.", actions: [.allowAccess])
                    return
                }
                defer { withExtendedLifetime(grant) {} }
                var receipt = preferences.data(forKey: Self.receiptKey).flatMap { try? JSONDecoder().decode(TerminalCommandSetup.Ownership.self, from: $0) }
                switch action {
                case .installLauncher, .installAndConfigure, .configureZsh:
                    let installed = try await setup.install(ownership: receipt, configureZsh: action.configuresZsh)
                    preferences.set(try JSONEncoder().encode(installed), forKey: Self.receiptKey)
                    receipt = installed
                case .uninstall:
                    try await setup.uninstall(ownership: receipt)
                    preferences.removeObject(forKey: Self.receiptKey)
                    receipt = nil
                case .allowAccess, .refresh: break
                }
                describe(try await setup.status(ownership: receipt))
            } catch {
                present("Terminal command needs attention", error.localizedDescription, actions: [.refresh])
            }
        }
    }

    private func access(allowChooser: Bool) async throws -> DirectoryAccess? {
        if !FolderAccess.isSandboxed() { return DirectoryAccess(root: setup.home, mode: .readWrite) {} }
        return try await folderAccess.writeAccess(for: setup.home) { [self] initial in
            guard allowChooser, isVisible else { return nil }
            guard let chosen = try await FolderAccess.chooseFolder(initial: initial, window: self, purpose: .terminalCommand) else { return nil }
            guard chosen.standardizedFileURL.path == setup.home.standardizedFileURL.path else {
                chosen.stopAccessingSecurityScopedResource()
                throw CocoaError(.fileWriteNoPermission, userInfo: [NSLocalizedDescriptionKey: "Choose your Home folder to manage the terminal command."])
            }
            return chosen
        }
    }

    private func describe(_ status: TerminalCommandSetup.Status) {
        let configureMessage = "Install and Configure zsh also adds a PATH entry to ~/.zprofile."
        let installMessage = "Install the launcher for manual PATH setup."
        let manualMessage = "Add the launcher folder to PATH in your shell profile."
        switch status {
        case .absent:
            present("Terminal launcher is not installed", supportsZshSetup ? configureMessage : installMessage,
                    actions: supportsZshSetup ? [.installLauncher, .installAndConfigure] : [.installLauncher])
        case .launcherOnly:
            present("Terminal launcher installed", supportsZshSetup ? "Configure zsh adds a PATH entry to ~/.zprofile. \(manualMessage)" : manualMessage,
                    actions: supportsZshSetup ? [.uninstall, .configureZsh] : [.uninstall])
        case .installed:
            present("Terminal launcher installed", "PanePeek’s PATH entry is present in ~/.zprofile. Check panepeek in a new terminal window.", actions: [.uninstall])
        case .profileOnly:
            present("Terminal launcher is not installed", "PanePeek’s PATH entry is present in ~/.zprofile.", actions: [.uninstall, .installLauncher])
        case .profileUnavailable(let launcherInstalled):
            if launcherInstalled {
                present("Terminal launcher installed", manualMessage, actions: [.uninstall])
            } else {
                let detail = supportsZshSetup ? "PanePeek couldn’t use ~/.zprofile. \(installMessage)" : installMessage
                present("Terminal launcher is not installed", detail, actions: [.installLauncher])
            }
        case .moved:
            present("PanePeek has moved", "Uninstall the old command, then install it for this copy of PanePeek.", actions: [.uninstall])
        case .conflict:
            present("Command location is in use", "PanePeek left the existing item untouched.", actions: [.refresh])
        }
    }

    private func present(_ title: String, _ detail: String, actions: [Action]) {
        heading.stringValue = title
        message.stringValue = detail
        message.isHidden = detail.isEmpty
        for (action, button) in buttons { button.isHidden = !actions.contains(action) }
        let primary = actions.first { $0 == .installLauncher || $0 == .allowAccess }.flatMap { buttons[$0] }
        defaultButtonCell = (primary ?? closeButton).cell as? NSButtonCell
        initialFirstResponder = primary ?? closeButton
        if isKeyWindow, let button = firstResponder as? NSButton, button.isHidden {
            makeFirstResponder(primary ?? closeButton)
        }
        contentView?.layoutSubtreeIfNeeded()
        let top = frame.maxY
        setContentSize(NSSize(width: Self.width, height: stack.fittingSize.height + 48))
        setFrameOrigin(NSPoint(x: frame.minX, y: top - frame.height))
        if isVisible {
            NSAccessibility.post(element: self, notification: .announcementRequested,
                userInfo: [.announcement: [title, detail].filter { !$0.isEmpty }.joined(separator: ". "),
                           .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
    }
}
