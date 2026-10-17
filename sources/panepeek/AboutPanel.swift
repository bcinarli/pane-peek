import AppKit

@MainActor enum AboutPanel {
    static func show() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: options())
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
