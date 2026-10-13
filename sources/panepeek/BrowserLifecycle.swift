import AppKit
import SwiftUI
import PanePeekCore

@MainActor final class BrowserLifecycle: NSObject, NSApplicationDelegate {
    static weak var browser: BrowserState?
    static weak var window: NSWindow?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.browser?.resolveChangesIfNeeded(resume: { sender.terminate(nil) }) == false ? .terminateCancel : .terminateNow
    }

    static func confirmChanges(_ fileName: String, completion: @escaping @MainActor (BrowserState.UnsavedChoice) -> Void) {
        // Present after the originating selection or command has returned to its event loop.
        DispatchQueue.main.async {
            guard let window else { completion(.cancel); return }
            let alert = NSAlert()
            alert.messageText = "Save changes to \(fileName)?"
            alert.informativeText = "Save keeps your changes. Discard continues without saving. Cancel keeps the draft open."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
            alert.addButton(withTitle: "Discard")
            alert.beginSheetModal(for: window) { response in
                let choice: BrowserState.UnsavedChoice = switch response {
                case .alertFirstButtonReturn: .save
                case .alertThirdButtonReturn: .discard
                default: .cancel
                }
                DispatchQueue.main.async { completion(choice) }
            }
        }
    }

    static func confirmMove(_ operation: ItemMove.Batch, completion: @escaping @MainActor (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let window else { completion(false); return }
            let alert = NSAlert()
            alert.messageText = "Move \(operation.items.count) \(operation.items.count == 1 ? "item" : "items")?"
            alert.informativeText = "Destination:\n" + (operation.items.first?.destination.deletingLastPathComponent().path ?? "")
            alert.accessoryView = sourceList(operation.items.map { $0.source.path })
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move")
            alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
            alert.beginSheetModal(for: window) { response in
                DispatchQueue.main.async { completion(response == .alertFirstButtonReturn) }
            }
        }
    }

    static func confirmTrash(_ operation: ItemTrash.Batch, completion: @escaping @MainActor (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let window else { completion(false); return }
            let alert = NSAlert()
            alert.messageText = "Move \(operation.items.count) \(operation.items.count == 1 ? "item" : "items") to Trash?"
            alert.informativeText = "Items will remain in Trash until it is emptied."
            alert.accessoryView = sourceList(operation.items.map { $0.source.path })
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move to Trash")
            alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
            alert.beginSheetModal(for: window) { response in
                DispatchQueue.main.async { completion(response == .alertFirstButtonReturn) }
            }
        }
    }

    private static func sourceList(_ paths: [String]) -> NSScrollView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 160))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let sources = NSTextView(frame: scroll.bounds)
        sources.isEditable = false
        sources.isRichText = false
        sources.isSelectable = true
        sources.isVerticallyResizable = true
        sources.isHorizontallyResizable = false
        sources.autoresizingMask = .width
        sources.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        sources.textContainer?.widthTracksTextView = true
        sources.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        sources.font = .preferredFont(forTextStyle: .body)
        sources.string = paths.joined(separator: "\n")
        sources.setAccessibilityLabel("Source items")
        scroll.documentView = sources
        return scroll
    }
}

struct BrowserWindowGuard: NSViewRepresentable {
    let browser: BrowserState

    func makeNSView(context: Context) -> GuardView { GuardView() }

    func updateNSView(_ view: GuardView, context: Context) {
        view.browser = browser
        view.install()
        let dirty = browser.preview.isDirty
        if view.window?.isDocumentEdited != dirty { view.window?.isDocumentEdited = dirty }
    }

    static func dismantleNSView(_ view: GuardView, coordinator: ()) {
        view.uninstall()
    }

    final class GuardView: NSView {
        weak var browser: BrowserState?
        private let proxy = WindowDelegate()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            install()
        }

        func install() {
            guard let window, let browser else { return }
            BrowserLifecycle.browser = browser
            BrowserLifecycle.window = window
            proxy.browser = browser
            if window.delegate !== proxy {
                proxy.original = window.delegate
                window.delegate = proxy
            }
        }

        func uninstall() {
            if window?.delegate === proxy { window?.delegate = proxy.original }
            proxy.original = nil
        }
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        weak var browser: BrowserState?
        var original: (any NSWindowDelegate)?

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard browser?.resolveChangesIfNeeded(resume: { [weak sender] in sender?.performClose(nil) }) != false else { return false }
            return original?.windowShouldClose?(sender) ?? true
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || original?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}
