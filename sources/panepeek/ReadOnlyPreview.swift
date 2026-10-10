import AppKit
import SwiftUI
import PanePeekCore

struct ReadOnlyPreview: NSViewRepresentable {
    let text: String
    let selection: DetailsSelection
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
        if context.coordinator.selection != selection {
            view.string = text
            view.setSelectedRange(NSRange(location: 0, length: 0))
            scroll.contentView.scroll(to: .zero)
            context.coordinator.selection = selection
        }
    }

    final class Coordinator {
        var selection: DetailsSelection?
    }
}
