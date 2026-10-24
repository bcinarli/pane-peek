import AppKit
import SwiftUI
import PanePeekCore

/// Keeps the native editor beneath rendered previews so mode changes retain its selection and undo history.
struct PreviewDocument: View {
    let preview: PreviewState
    let text: String

    var body: some View {
        let rendered = preview.mode == .preview ? preview.markdown : nil
        let svg = preview.mode == .preview && SVGPreview.isSVG(preview.selection?.item.name ?? "")
        let html = preview.mode == .preview && HTMLPreviewState.isHTML(preview.selection?.item.name ?? "")
        PreviewTextView(text: text, documentID: preview.documentID, saveRevision: preview.saveRevision,
                        mode: preview.mode,
                        tokens: preview.tokens, highlightRevision: preview.highlightRevision,
                        hidden: rendered != nil || svg || html,
                        editingLocked: preview.isSaving || preview.isChangingLocation,
                        canChange: { [preview] in preview.canEdit && preview.mode == .edit },
                        changed: { [preview] in preview.updateText($0) })
            .overlay {
                if let rendered { MarkdownPreviewView(blocks: rendered) }
                if svg {
                    SVGPreviewView(text: text, name: preview.selection?.item.name ?? "SVG")
                        .id(preview.documentID)
                }
                if html {
                    HTMLPreviewView(text: text, name: preview.selection?.item.name ?? "HTML", selection: preview.selection)
                        .id(preview.documentID)
                }
            }
            .overlay(alignment: .topLeading) {
                if text.isEmpty, preview.mode == .preview, !svg, !html {
                    Text("Empty text file.")
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct PreviewTextView: NSViewRepresentable {
    let text: String
    let documentID: UUID
    let saveRevision: UUID
    let mode: PreviewState.Mode
    let tokens: [SyntaxToken]
    let highlightRevision: UUID?
    var hidden = false
    var editingLocked = false
    let canChange: @MainActor () -> Bool
    let changed: (String) -> Void
    @ScaledMetric(relativeTo: .body) private var fontSize = NSFont.preferredFont(forTextStyle: .body, options: [:]).pointSize

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let view = EditorTextView(usingTextLayoutManager: true)
        view.delegate = context.coordinator
        view.allowsUndo = true
        view.isRichText = false
        // The gutter does not use AppKit's paragraph-formatting ruler.
        view.usesRuler = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.textColor = .textColor
        let scroll = Self.scrollView(for: view)
        scroll.hasVerticalRuler = true
        scroll.verticalRulerView = EditorLineNumberRuler(scrollView: scroll)
        scroll.rulersVisible = false
        return scroll
    }

    /// Shared read-only presentation for the editor and rendered Markdown.
    static func scrollView(for view: NSTextView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 8, height: 10)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        // Hiding also removes the source from the key-view loop and accessibility while a rendered preview is visible.
        if scroll.isHidden != hidden { scroll.isHidden = hidden }
        coordinator.canChange = canChange
        coordinator.changed = changed
        guard let view = scroll.documentView as? NSTextView else { return }
        let documentChanged = coordinator.documentID != documentID
        if documentChanged { coordinator.highlighting = nil; coordinator.highlightRevision = nil }
        let undo = view.undoManager
        if documentChanged { undo?.removeAllActions() }
        // Typing after Save starts a new undo step without clearing earlier edits.
        if coordinator.saveRevision != saveRevision {
            view.breakUndoCoalescing()
            coordinator.saveRevision = saveRevision
        }
        coordinator.applyingPresentation = true
        undo?.disableUndoRegistration()
        defer {
            undo?.enableUndoRegistration()
            coordinator.applyingPresentation = false
        }
        let font = PreviewFonts.monospaced(size: fontSize)
        if view.font != font { view.font = font }
        // Only replacement or explicit discard resets native selection, scroll and undo.
        if documentChanged {
            view.isEditable = false
            view.string = text
            view.setSelectedRange(NSRange(location: 0, length: 0))
            scroll.contentView.scroll(to: .zero)
            coordinator.documentID = documentID
        }
        let editable = mode == .edit && !editingLocked
        if view.isEditable != editable { view.isEditable = editable }
        (scroll.verticalRulerView as? EditorLineNumberRuler)?.update(textChanged: documentChanged)
        if scroll.rulersVisible != (mode == .edit) { scroll.rulersVisible = mode == .edit }
        view.setAccessibilityLabel(mode == .edit ? "Text editor" : "Read-only text preview")
        view.setAccessibilityHelp(mode == .edit ? "Text files are limited to 1 MiB. Changes remain in memory until you save or discard them." : "Read-only text preview, limited to 1 MiB. Select and copy text.")
        let revision = highlightRevision ?? (documentChanged ? documentID : nil)
        coordinator.highlighting = revision.map { (text, highlightRevision == nil ? [] : tokens, $0) }
        coordinator.applyHighlighting(to: view)
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var documentID: UUID?
        var saveRevision: UUID?
        var highlightRevision: UUID?
        var highlighting: (text: String, tokens: [SyntaxToken], revision: UUID)?
        var changed: (String) -> Void = { _ in }
        var canChange: @MainActor () -> Bool = { false }
        var applyingPresentation = false

        func applyHighlighting(to view: NSTextView) {
            guard let highlighting, highlightRevision != highlighting.revision, !view.hasMarkedText(),
                  view.string.utf8.elementsEqual(highlighting.text.utf8), let storage = view.textStorage else { return }
            let undo = view.undoManager
            let wasApplying = applyingPresentation
            applyingPresentation = true
            undo?.disableUndoRegistration()
            defer { undo?.enableUndoRegistration(); applyingPresentation = wasApplying }
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: NSColor.textColor,
                                 range: NSRange(location: 0, length: storage.length))
            for token in highlighting.tokens where token.range.location >= 0 && NSMaxRange(token.range) <= storage.length {
                storage.addAttribute(.foregroundColor, value: PreviewColours.colour(for: token.kind), range: token.range)
            }
            storage.endEditing()
            highlightRevision = highlighting.revision
        }

        func textDidChange(_ notification: Notification) {
            guard !applyingPresentation, let view = notification.object as? NSTextView else { return }
            (view.enclosingScrollView?.verticalRulerView as? EditorLineNumberRuler)?.update(textChanged: true)
            changed(view.string)
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard canChange() else { return false }
            guard let replacementString else { return true }
            let candidate = (textView.string as NSString).replacingCharacters(in: affectedCharRange, with: replacementString)
            guard candidate.utf8.count <= TextPreview.maximumBytes else {
                NSSound.beep()
                return false
            }
            return true
        }
    }
}

@MainActor final class EditorTextView: NSTextView {
    private let history = UndoManager()
    private var scrollYBeforeResize: CGFloat?
    override var undoManager: UndoManager? { history }

    override func unmarkText() {
        super.unmarkText()
        (delegate as? PreviewTextView.Coordinator)?.applyHighlighting(to: self)
    }

    override func setFrameSize(_ newSize: NSSize) {
        if newSize.width != frame.width {
            scrollYBeforeResize = enclosingScrollView?.contentView.bounds.minY
        }
        super.setFrameSize(newSize)
    }

    override func layout() {
        super.layout()
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
        // Reflow must not scroll a retained selection back into view.
        if let y = scrollYBeforeResize, let scroll = enclosingScrollView {
            scrollYBeforeResize = nil
            scroll.contentView.scroll(to: NSPoint(x: scroll.contentView.bounds.minX, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    private var canChangeText: Bool {
        isEditable && (delegate as? PreviewTextView.Coordinator)?.canChange() == true
    }

    @objc func undo(_ sender: Any?) {
        guard canChangeText, history.canUndo else { return }
        history.undo()
        didChangeText()
    }

    @objc func redo(_ sender: Any?) {
        guard canChangeText, history.canRedo else { return }
        history.redo()
        didChangeText()
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)): canChangeText && history.canUndo
        case #selector(redo(_:)): canChangeText && history.canRedo
        default: super.validateUserInterfaceItem(item)
        }
    }
}

@MainActor enum PreviewFonts {
    /// Installed coding fonts are optional and never bundled.
    static func monospaced(size: CGFloat) -> NSFont {
        ["Operator Mono Lig", "JetBrains Mono"].lazy.compactMap {
            NSFontManager.shared.font(withFamily: $0, traits: [], weight: 5, size: size)
        }.first ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

@MainActor enum PreviewColours {
    static let keyword = adaptive(light: 0x8255B6, dark: 0xC6A0F6)
    static let string = adaptive(light: 0x416838, dark: 0xA6DA95)
    static let number = adaptive(light: 0x995021, dark: 0xF5A97F)
    static let comment = adaptive(light: 0x66616C, dark: 0xA5ADCB)

    static func colour(for kind: SyntaxToken.Kind) -> NSColor {
        switch kind {
        case .keyword, .literal, .key, .section, .reference: keyword
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
