import AppKit
import SwiftUI
import PanePeekCore

struct PreviewTextView: NSViewRepresentable {
    let text: String
    let documentID: UUID
    let saveRevision: UUID
    let mode: PreviewState.Mode
    let tokens: [SyntaxToken]
    let canChange: @MainActor () -> Bool
    let changed: (String) -> Void
    @ScaledMetric(relativeTo: .body) private var fontSize = NSFont.preferredFont(forTextStyle: .body, options: [:]).pointSize

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let view = EditorTextView(usingTextLayoutManager: true)
        view.isEditable = false
        view.delegate = context.coordinator
        view.allowsUndo = true
        view.isSelectable = true
        view.isRichText = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.drawsBackground = false
        view.textColor = .textColor
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
        coordinator.canChange = canChange
        coordinator.changed = changed
        guard let view = scroll.documentView as? NSTextView else { return }
        let documentChanged = coordinator.documentID != documentID
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
        let font = ["Operator Mono Lig", "JetBrains Mono"].lazy.compactMap {
            NSFontManager.shared.font(withFamily: $0, traits: [], weight: 5, size: fontSize)
        }.first ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if view.font != font { view.font = font }
        // Only replacement or explicit discard resets native selection, scroll and undo.
        if documentChanged {
            view.isEditable = false
            view.string = text
            view.setSelectedRange(NSRange(location: 0, length: 0))
            scroll.contentView.scroll(to: .zero)
            coordinator.documentID = documentID
        }
        if view.isEditable != (mode == .edit) { view.isEditable = mode == .edit }
        view.setAccessibilityLabel(mode == .edit ? "Text editor" : "Read-only text preview")
        view.setAccessibilityHelp("Text files are limited to 1 MiB. Changes remain in memory until you save or discard them.")
        // Colour changes must not interrupt input-method composition or enter undo history.
        if !view.hasMarkedText(), (documentChanged || coordinator.tokens != tokens),
           view.string.utf8.elementsEqual(text.utf8), let storage = view.textStorage {
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: NSColor.textColor,
                                 range: NSRange(location: 0, length: storage.length))
            for token in tokens where token.range.location >= 0 && NSMaxRange(token.range) <= storage.length {
                storage.addAttribute(.foregroundColor, value: PreviewColours.colour(for: token.kind), range: token.range)
            }
            storage.endEditing()
            coordinator.tokens = tokens
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var documentID: UUID?
        var saveRevision: UUID?
        var tokens: [SyntaxToken] = []
        var changed: (String) -> Void = { _ in }
        var canChange: @MainActor () -> Bool = { false }
        var applyingPresentation = false

        func textDidChange(_ notification: Notification) {
            guard !applyingPresentation, let view = notification.object as? NSTextView else { return }
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
    private var scrollOriginBeforeResize: NSPoint?
    override var undoManager: UndoManager? { history }

    override func setFrameSize(_ newSize: NSSize) {
        if newSize.width != frame.width {
            scrollOriginBeforeResize = enclosingScrollView?.contentView.bounds.origin
        }
        super.setFrameSize(newSize)
    }

    override func layout() {
        super.layout()
        // Reflow must not scroll a retained selection back into view.
        if let origin = scrollOriginBeforeResize, let scroll = enclosingScrollView {
            scrollOriginBeforeResize = nil
            scroll.contentView.scroll(to: origin)
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

@MainActor private enum PreviewColours {
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
