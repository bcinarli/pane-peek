import AppKit
import Observation
import PanePeekCore

@MainActor @Observable final class BrowserFind: NSObject {
    typealias Destination = FindRouting.Destination
    private(set) var destination = Destination.unavailable
    private(set) var folderRequest = UUID()
    private(set) var canSearchFolder = false
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored weak var browser: BrowserState?
    @ObservationIgnored var isBlocked = false
    @ObservationIgnored private var ownership: FindResponder.Ownership?
    @ObservationIgnored private var previousFocus = FindRouting.Focus.browser

    var canFind: Bool { destination != .unavailable }

    override init() {
        super.init()
        for name in [NSWindow.didUpdateNotification, NSWindow.didBecomeKeyNotification,
                     NSWindow.didResignKeyNotification, NSMenu.didBeginTrackingNotification, FindPresentationView.didChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(refreshFromNotification), name: name, object: nil)
        }
    }

    @objc private func refreshFromNotification(_ notification: Notification) { refresh() }
    func refresh(in keyWindow: NSWindow? = NSApp.keyWindow) { _ = resolve(in: keyWindow) }

    private func resolve(in keyWindow: NSWindow?) -> (FindRouting.Decision, FindResponder.Context?) {
        let blocked = window == nil || window !== keyWindow || window?.attachedSheet != nil || browser == nil
            || browser?.renameRequest != nil || browser?.creationRequest != nil || isBlocked
        let context = blocked ? nil : window.map { FindResponder.capture(in: $0, ownership: ownership, previousFocus: previousFocus) }
        if let context {
            switch context.focus {
            case .browser: previousFocus = .browser
            case .document, .native: previousFocus = .document
            case .textEntry: break
            }
        }
        let decision = FindRouting.decide(blocked: blocked, focus: context?.focus ?? .browser,
                                          presentation: context?.presentation ?? .unavailable, hasDocumentClient: context?.document != nil)
        if destination != decision.destination { destination = decision.destination }
        if canSearchFolder != decision.canSearchFolder { canSearchFolder = decision.canSearchFolder }
        return (decision, context)
    }

    func find(in keyWindow: NSWindow? = NSApp.keyWindow) {
        let (decision, context) = resolve(in: keyWindow)
        switch decision.destination {
        case .folder: focusFolder()
        case .document:
            if let target = context?.document { ownership = FindResponder.show(in: target, documentIdentity: context?.presentation.identity) }
        case .native:
            if let target = context?.native { ownership = FindResponder.show(in: target, documentIdentity: nil) }
        case .unavailable: break
        }
    }

    func searchFolder(in keyWindow: NSWindow? = NSApp.keyWindow) {
        let (decision, _) = resolve(in: keyWindow)
        if decision.canSearchFolder { focusFolder() }
    }

    private func focusFolder() {
        previousFocus = .browser
        folderRequest = UUID()
    }
}
