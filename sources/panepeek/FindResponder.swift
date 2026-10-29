import AppKit
import ObjectiveC

/// Samples native focus and clients without changing document or Find-bar ownership.
@MainActor enum FindResponder {
    static let documentContainerIdentifier = NSUserInterfaceItemIdentifier("PanePeekDocumentFind")
    private static let action = #selector(NSResponder.performTextFinderAction(_:))

    struct Ownership {
        weak var view: NSView?
        weak var bar: NSView?
        let documentIdentity: FindPresentation.Identity?
    }

    struct Context {
        let focus: FindRouting.Focus
        let presentation: FindPresentation
        let document: NSView?
        let native: NSResponder?
    }

    static func capture(in window: NSWindow, ownership: Ownership?, previousFocus: FindRouting.Focus) -> Context {
        let presentation = presentation(in: window.contentView) ?? .unavailable
        let document = document(in: window.contentView)
        func context(_ focus: FindRouting.Focus, document owned: NSView? = nil, native: NSResponder? = nil) -> Context {
            Context(focus: focus, presentation: presentation, document: owned ?? document, native: native)
        }
        let responder = window.firstResponder
        let text = responder as? NSTextView
        let focused = text?.isFieldEditor == true ? (text?.delegate as? NSView) ?? text : responder as? NSView
        if text?.isFieldEditor == true {
            if focused is FolderSearchField.SearchInput { return context(.browser) }
            if let ownership, let bar = ownership.bar, let focused, focused.isDescendant(of: bar) {
                if let owner = ownership.view, owner.window === window, !owner.isHiddenOrHasHiddenAncestor,
                   bar.window === window, !bar.isHiddenOrHasHiddenAncestor {
                    if ownership.documentIdentity == nil { return context(.native, native: owner) }
                    if presentation.readiness == .ready, presentation.identity == ownership.documentIdentity {
                        return context(.document, document: owner)
                    }
                }
                return context(.document)
            }
            return context(.textEntry)
        }
        if let focused, focused.window !== window || focused.isHiddenOrHasHiddenAncestor {
            return context(previousFocus == .document || focused is EditorTextView ? .document : .browser)
        }
        if responder === window { return context(previousFocus) }
        let item = NSMenuItem(title: "Find…", action: action, keyEquivalent: "")
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        var candidate = responder
        while let current = candidate, current !== window {
            if current is EditorTextView || current is HTMLFindView { return context(.document) }
            if let text = current as? NSTextView, text.usesFindBar, documentScope(of: text) != nil {
                return context(.document)
            }
            // NSResponder's inherited forwarding does not establish a native Find handler.
            if class_getInstanceMethod(type(of: current), action) != class_getInstanceMethod(NSResponder.self, action),
               let validation = current as? NSUserInterfaceValidations, validation.validateUserInterfaceItem(item) {
                return context(.native, native: current)
            }
            if let view = current as? NSView, view.identifier == documentContainerIdentifier { return context(.document) }
            candidate = current.nextResponder
        }
        return context(.browser)
    }

    static func show(in target: NSResponder, documentIdentity: FindPresentation.Identity?) -> Ownership? {
        let item = NSMenuItem(title: "Find…", action: action, keyEquivalent: "")
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        guard target.tryToPerform(action, with: item) else { return nil }
        let owner = target as? NSView
        let bar = (owner as? NSTextView)?.enclosingScrollView?.findBarView ?? (owner as? NSScrollView)?.findBarView
        return Ownership(view: owner, bar: bar, documentIdentity: documentIdentity)
    }

    private static func documentScope(of view: NSView) -> NSView? {
        if view.identifier == documentContainerIdentifier { return view }
        return view.superview.flatMap { documentScope(of: $0) }
    }

    private static func presentation(in view: NSView?) -> FindPresentation? {
        guard let view, !view.isHiddenOrHasHiddenAncestor else { return nil }
        if let marker = view as? FindPresentationView.Marker { return marker.presentation }
        return view.subviews.lazy.compactMap { presentation(in: $0) }.first
    }

    private static func document(in view: NSView?) -> NSView? {
        guard let view, !view.isHiddenOrHasHiddenAncestor else { return nil }
        if view is HTMLFindView { return view }
        if let text = view as? NSTextView, !text.isFieldEditor, text.usesFindBar { return text }
        return view.subviews.lazy.compactMap { document(in: $0) }.first
    }
}
