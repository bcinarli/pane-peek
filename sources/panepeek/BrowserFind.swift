import AppKit
import ObjectiveC
import Observation
import PanePeekCore

@MainActor @Observable final class BrowserFind: NSObject {
    static let documentContainerIdentifier = NSUserInterfaceItemIdentifier("PanePeekDocumentFind")
    enum Destination { case unavailable, folder, document, native }
    private(set) var destination = Destination.unavailable
    private(set) var folderRequest = UUID()
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored weak var browser: BrowserState?
    @ObservationIgnored var isBlocked = false
    @ObservationIgnored private weak var target: NSResponder?
    @ObservationIgnored private weak var findOwner: NSView?
    @ObservationIgnored private weak var findBar: NSView?
    @ObservationIgnored private var documentHadFocus = false
    @ObservationIgnored private var action: Selector?

    var canFind: Bool { destination != .unavailable }
    var canSearchFolder: Bool { canFind }

    override init() {
        super.init()
        for name in [NSWindow.didUpdateNotification, NSWindow.didBecomeKeyNotification,
                     NSWindow.didResignKeyNotification, NSMenu.didBeginTrackingNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(refreshFromNotification), name: name, object: nil)
        }
    }

    @objc private func refreshFromNotification(_ notification: Notification) { refresh() }

    func refresh(in keyWindow: NSWindow? = NSApp.keyWindow) {
        destination = resolve(in: keyWindow)
        if destination == .folder { documentHadFocus = false }
        if destination == .document || destination == .native { documentHadFocus = true }
    }

    private func resolve(in keyWindow: NSWindow?) -> Destination {
        target = nil
        action = nil
        guard let window, window === keyWindow, window.attachedSheet == nil,
              let browser, browser.renameRequest == nil, browser.creationRequest == nil, !isBlocked else { return .unavailable }
        let responder = window.firstResponder
        let text = responder as? NSTextView
        let focused = text?.isFieldEditor == true ? (text?.delegate as? NSView) ?? text : responder as? NSView
        let hiddenSource = (responder as? EditorTextView)?.isHiddenOrHasHiddenAncestor == true
        let removedText = text?.isFieldEditor == false && text?.window !== window
        let previousContent = findOwner.map { focused?.isDescendant(of: $0) == true } ?? false
        let previousField = findBar.map { focused?.isDescendant(of: $0) == true } ?? false
        let previousHidden = findOwner.map { $0.window !== window || $0.isHiddenOrHasHiddenAncestor } ?? false
        let documentLostFocus = responder === window && documentHadFocus
        if hiddenSource || removedText || documentLostFocus || (previousHidden && (previousContent || previousField)) {
            guard let visible = visibleDocument(in: window.contentView) else { return .unavailable }
            return setTarget(visible)
        }
        if let owner = findOwner, owner.window === window, !owner.isHiddenOrHasHiddenAncestor,
           let bar = findBar, bar.window === window, !bar.isHiddenOrHasHiddenAncestor,
           let focused, focused.isDescendant(of: bar) {
            return setTarget(owner)
        } else if let editor = responder as? EditorTextView, !editor.isHiddenOrHasHiddenAncestor {
            return setTarget(editor)
        } else if focused is FolderSearchField.SearchInput {
            return .folder
        } else if text?.isFieldEditor != true {
            let findAction = #selector(NSResponder.performTextFinderAction(_:))
            let item = NSMenuItem(title: "Find…", action: findAction, keyEquivalent: "")
            item.tag = NSTextFinder.Action.showFindInterface.rawValue
            var candidate = responder
            while let current = candidate, current !== window {
                if let native = current as? NSTextView, !native.isFieldEditor, !native.isHiddenOrHasHiddenAncestor {
                    return setTarget(native)
                }
                // Inherited Find forwarding does not establish a native Find handler.
                if class_getInstanceMethod(type(of: current), findAction) != class_getInstanceMethod(NSResponder.self, findAction),
                   let validation = current as? NSUserInterfaceValidations,
                   validation.validateUserInterfaceItem(item) {
                    target = current
                    action = item.action
                    return .native
                }
                if let container = current as? NSView, container.identifier == Self.documentContainerIdentifier {
                    guard let visible = visibleDocument(in: container) else { return .unavailable }
                    return setTarget(visible)
                }
                candidate = current.nextResponder
            }
            return .folder
        }
        return .unavailable
    }

    private func setTarget(_ view: NSView) -> Destination {
        target = view
        action = #selector(NSResponder.performTextFinderAction(_:))
        return view is NSTextView ? .document : .native
    }

    private func visibleDocument(in view: NSView?) -> NSView? {
        guard let view, !view.isHiddenOrHasHiddenAncestor else { return nil }
        if view is HTMLFindView { return view }
        if let text = view as? NSTextView, !text.isFieldEditor, text.usesFindBar { return text }
        return view.subviews.lazy.compactMap { self.visibleDocument(in: $0) }.first
    }

    func find(in keyWindow: NSWindow? = NSApp.keyWindow) {
        refresh(in: keyWindow)
        guard canFind else { return }
        if destination == .folder { searchFolder(in: keyWindow); return }
        let item = NSMenuItem(title: "Find…", action: action, keyEquivalent: "")
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        let owner = target as? NSView
        findOwner = owner
        if let action { target?.tryToPerform(action, with: item) }
        findBar = (owner as? NSTextView)?.enclosingScrollView?.findBarView ?? (owner as? NSScrollView)?.findBarView
    }

    func searchFolder(in keyWindow: NSWindow? = NSApp.keyWindow) {
        refresh(in: keyWindow)
        guard canSearchFolder else { return }
        folderRequest = UUID()
    }
}
