import AppKit

@MainActor enum AboutPanel {
    private static var window: AboutWindow?

    static func show() {
        let panel = window ?? AboutWindow(options: options())
        window = panel
        panel.makeKeyAndOrderFront(nil)
    }

    static func options(in bundle: Bundle = .main) -> [NSApplication.AboutPanelOptionKey: Any] {
        func value(_ key: String) -> String? {
            guard let text = bundle.object(forInfoDictionaryKey: key) as? String, !text.isEmpty else { return nil }
            return text
        }
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 4
        let credits = NSMutableAttributedString(string: """
        Browse and preview your documents.
        Edit text inline and copy absolute paths
        to share with AI agents.

        """ + "\n")
        func link(_ title: String, _ url: URL?) {
            credits.append(NSAttributedString(string: title, attributes: url.map { [.link: $0] } ?? [:]))
        }
        let project = "https://github.com/bcinarli/pane-peek"
        link("GitHub", URL(string: project))
        credits.append(NSAttributedString(string: " · "))
        link("Release Notes", URL(string: project + "/blob/main/CHANGELOG.md"))
        credits.append(NSAttributedString(string: " · "))
        link("Report an Issue", URL(string: project + "/issues"))
        credits.append(NSAttributedString(string: "\n"))
        let privacy = bundle.url(forResource: "Privacy", withExtension: "txt")
        let acknowledgements = bundle.url(forResource: "Acknowledgements", withExtension: "txt")
        link("Privacy", privacy)
        credits.append(NSAttributedString(string: " · "))
        link("Acknowledgements", acknowledgements)
        if privacy == nil || acknowledgements == nil {
            credits.append(NSAttributedString(string: "\n\nOffline notices are unavailable in this unbundled build."))
        }
        credits.addAttributes([.font: NSFont.preferredFont(forTextStyle: .body), .foregroundColor: NSColor.labelColor,
                               .paragraphStyle: style], range: NSRange(location: 0, length: credits.length))
        return [.applicationName: "PanePeek", .applicationVersion: value("CFBundleShortVersionString") ?? "Development build",
                .version: value("CFBundleVersion") ?? "", .init(rawValue: "Copyright"): value("NSHumanReadableCopyright") ?? "",
                .credits: credits]
    }
}

private final class AboutWindow: NSPanel, NSTextViewDelegate {
    init(options: [NSApplication.AboutPanelOptionKey: Any]) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
                   styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        title = "About PanePeek"
        isReleasedWhenClosed = false
        isRestorable = false
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        tabbingMode = .disallowed
        titlebarAppearsTransparent = true
        backgroundColor = AppColours.floating
        contentMinSize = NSSize(width: 340, height: 320)
        let content = AboutContent(frame: NSRect(origin: .zero, size: contentLayoutRect.size))
        contentView = content

        let icon = NSImageView(image: NSApplication.shared.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        icon.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(icon)

        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 428, height: 300))
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.isHorizontallyResizable = false
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainerInset = NSSize(width: 12, height: 8)
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 428, height: CGFloat.greatestFiniteMagnitude)
        text.linkTextAttributes = [.foregroundColor: AppColours.accent, .underlineStyle: NSUnderlineStyle.single.rawValue]
        text.setAccessibilityLabel("About PanePeek")
        text.textStorage?.setAttributedString(Self.information(options))
        text.delegate = self

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = text
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            icon.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 96),
            icon.heightAnchor.constraint(equalTo: icon.widthAnchor),
            scroll.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
        initialFirstResponder = text
        center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func cancelOperation(_ sender: Any?) { performClose(sender) }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        return NSWorkspace.shared.open(url)
    }

    private static func information(_ options: [NSApplication.AboutPanelOptionKey: Any]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 8
        func append(_ value: String, font: NSFont, colour: NSColor = .labelColor) {
            output.append(NSAttributedString(string: value + "\n", attributes: [
                .font: font, .foregroundColor: colour, .paragraphStyle: style
            ]))
        }
        append(options[.applicationName] as? String ?? "PanePeek", font: .preferredFont(forTextStyle: .title1))
        let version = options[.applicationVersion] as? String ?? "Development build"
        let build = options[.version] as? String ?? ""
        append(build.isEmpty ? version : "Version \(version) (\(build))", font: .preferredFont(forTextStyle: .body))
        if let copyright = options[.init(rawValue: "Copyright")] as? String, !copyright.isEmpty {
            append(copyright, font: .preferredFont(forTextStyle: .caption1), colour: .secondaryLabelColor)
        }
        output.append(NSAttributedString(string: "\n"))
        if let credits = options[.credits] as? NSAttributedString { output.append(credits) }
        return output
    }
}

private final class AboutContent: NSView {
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
