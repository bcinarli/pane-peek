import AppKit
import PanePeekCore

@MainActor final class TerminalCommandWindow: NSPanel {
    private enum Action: Int, CaseIterable {
        case allowAccess, uninstall, install, refresh
        var title: String {
            switch self {
            case .allowAccess: "Allow Access…"
            case .uninstall: "Uninstall"
            case .install: "Install"
            case .refresh: "Check Again"
            }
        }
    }

    private let setup: TerminalCommandSetup
    private let folderAccess: FolderAccess
    private let preferences: UserDefaults
    private let supportsInstall: Bool
    private let stack = NSStackView()
    private let heading = NSTextField(wrappingLabelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private var buttons: [Action: NSButton] = [:]
    private var working = false
    private static let receiptKey = "terminalCommandOwnership"
    private static let width: CGFloat = 520

    init(home: URL, folderAccess: FolderAccess, preferences: UserDefaults = .standard) {
        setup = TerminalCommandSetup(home: home, app: Bundle.main.bundleURL)
        self.folderAccess = folderAccess
        self.preferences = preferences
        supportsInstall = FolderAccess.accountShell == "/bin/zsh"
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
        for view in [icon, heading, message, path, usage, footer] { stack.addArrangedSubview(view) }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            footer.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
        for field in [heading, message, path, usage] {
            field.preferredMaxLayoutWidth = Self.width - 48
            field.maximumNumberOfLines = 0
            field.setContentCompressionResistancePriority(.required, for: .vertical)
            field.widthAnchor.constraint(equalToConstant: Self.width - 48).isActive = true
        }
        present("Checking terminal command…", "", actions: [])
        center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        makeKeyAndOrderFront(nil)
        perform(.refresh)
    }

    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    @objc private func closePanel() { performClose(nil) }

    @objc private func performAction(_ button: NSButton) {
        guard let action = Action(rawValue: button.tag), !button.isHidden else { return }
        perform(action)
    }

    private func perform(_ action: Action) {
        guard !working, action != .install || supportsInstall else { return }
        working = true
        let progress = switch action {
        case .install: "Installing terminal command…"
        case .uninstall: "Removing terminal command…"
        case .allowAccess, .refresh: "Checking terminal command…"
        }
        present(progress, "", actions: [])
        Task {
            defer { working = false }
            do {
                guard let grant = try await access(allowChooser: action == .allowAccess) else {
                    present("Home folder access needed", "Allow access to check the command and manage its link and .zprofile entry.", actions: [.allowAccess])
                    return
                }
                defer { withExtendedLifetime(grant) {} }
                var receipt = preferences.data(forKey: Self.receiptKey).flatMap { try? JSONDecoder().decode(TerminalCommandSetup.Ownership.self, from: $0) }
                switch action {
                case .install:
                    let installed = try await setup.install(ownership: receipt)
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
        let installMessage = "Install adds the bundled command and a PanePeek PATH entry to .zprofile. Open a new Terminal window after installation."
        let unsupported = "Automatic setup supports the standard macOS zsh login shell. See the usage guide for manual setup."
        switch status {
        case .absent:
            present("Terminal command is not installed", supportsInstall ? installMessage : unsupported, actions: supportsInstall ? [.install] : [])
        case .installed:
            present("Terminal command installed", "Open a new Terminal window to use panepeek. An existing command with that name keeps its priority.", actions: [.uninstall])
        case .incomplete:
            present("Terminal setup is incomplete", supportsInstall ? installMessage : unsupported, actions: supportsInstall ? [.uninstall, .install] : [.uninstall])
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
        let primary = actions.first { $0 == .install || $0 == .allowAccess }.flatMap { buttons[$0] }
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
