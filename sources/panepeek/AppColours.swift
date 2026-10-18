import AppKit

@MainActor enum AppColours {
    static let paper = adaptive(light: .textBackgroundColor, dark: 0x24273A)
    static let chrome = adaptive(light: .underPageBackgroundColor, dark: 0x1E2030)
    static let frame = adaptive(light: .windowBackgroundColor, dark: 0x181926)
    static let floating = adaptive(light: .windowBackgroundColor, dark: 0x1E2030)
    static let divider = adaptive(light: .separatorColor, dark: 0x363A4F)
    static let accentInk = adaptive(light: .white, dark: 0x24273A)
    static let accent = NSColor(named: "accent") ?? adaptive(light: colour(0x8255B6), dark: 0xC6A0F6)

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func styleAccentButton(_ button: NSButton) {
        button.bezelColor = accent
        let ink = NSColor(name: nil) { [weak button] _ in
            guard let button, button.isEnabled else { return .disabledControlTextColor }
            // Inactive windows use neutral bezels instead of the accent fill.
            guard NSApp.isActive, button.window?.isKeyWindow == true else { return .controlTextColor }
            return accentInk
        }
        button.attributedTitle = NSAttributedString(string: button.title, attributes: [
            .font: button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: ink
        ])
    }

    private static func adaptive(light: NSColor, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in isDark(appearance) ? colour(dark) : light }
    }

    private static func colour(_ hex: Int) -> NSColor {
        NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
                green: Double((hex >> 8) & 255) / 255,
                blue: Double(hex & 255) / 255, alpha: 1)
    }
}
