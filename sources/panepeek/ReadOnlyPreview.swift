import AppKit
import SwiftUI
import PanePeekCore

struct ReadOnlyPreview: NSViewRepresentable {
    let text: String
    let selection: DetailsSelection
    let tokens: [SyntaxToken]
    @ScaledMetric(relativeTo: .body) private var fontSize = NSFont.preferredFont(forTextStyle: .body, options: [:]).pointSize

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let view = NSTextView(usingTextLayoutManager: true)
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.drawsBackground = false
        view.textColor = .textColor
        view.textContainerInset = NSSize(width: 8, height: 10)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.setAccessibilityLabel("Read-only text preview")
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        let font = ["Operator Mono Lig", "JetBrains Mono"].lazy.compactMap {
            NSFontManager.shared.font(withFamily: $0, traits: [], weight: 5, size: fontSize)
        }.first ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if view.font != font { view.font = font }
        // Metadata updates must not reset native text selection or scroll position.
        let selectionChanged = context.coordinator.selection != selection
        if selectionChanged {
            view.string = text
            view.setSelectedRange(NSRange(location: 0, length: 0))
            scroll.contentView.scroll(to: .zero)
            context.coordinator.selection = selection
        }
        if selectionChanged || context.coordinator.tokens != tokens, let storage = view.textStorage {
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: NSColor.textColor,
                                 range: NSRange(location: 0, length: storage.length))
            for token in tokens {
                storage.addAttribute(.foregroundColor, value: PreviewColours.colour(for: token.kind), range: token.range)
            }
            storage.endEditing()
            context.coordinator.tokens = tokens
        }
    }

    final class Coordinator {
        var selection: DetailsSelection?
        var tokens: [SyntaxToken] = []
    }
}

@MainActor private enum PreviewColours {
    static let keyword = adaptive(light: 0x8255B6, dark: 0xC6A0F6)
    static let string = adaptive(light: 0x416838, dark: 0xA6DA95)
    static let number = adaptive(light: 0x995021, dark: 0xF5A97F)
    static let comment = adaptive(light: 0x66616C, dark: 0xA5ADCB)

    static func colour(for kind: SyntaxToken.Kind) -> NSColor {
        switch kind {
        case .keyword, .literal: keyword
        case .string: string
        case .number: number
        case .comment: comment
        }
    }

    private static func adaptive(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
                           green: Double((hex >> 8) & 255) / 255,
                           blue: Double(hex & 255) / 255, alpha: 1)
        }
    }
}
