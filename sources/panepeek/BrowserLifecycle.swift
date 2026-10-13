import AppKit
import SwiftUI
import PanePeekCore

@MainActor final class BrowserLifecycle: NSObject, NSApplicationDelegate {
    private struct WindowRecord {
        weak var window: NSWindow?
        weak var browser: BrowserState?
        weak var prompts: BrowserPrompts?
    }

    @MainActor private struct QuitSnapshot {
        let window: NSWindow
        let preview: PreviewState
        let prompts: BrowserPrompts
        let document: UUID
        let text: String?
        let dirty: Bool

        var draftUnchanged: Bool {
            guard preview.documentID == document else { return false }
            switch (preview.text, text) {
            case (nil, nil): return true
            case (let current?, let captured?): return current.utf8.elementsEqual(captured.utf8)
            default: return false
            }
        }
    }

    private var windows: [WindowRecord] = []
    private var registrationID = UUID()
    private var quitTask: Task<Void, Never>?
    private(set) var isResolvingQuit = false

    func register(_ browser: BrowserState, in window: NSWindow, prompts: BrowserPrompts) {
        if let index = windows.firstIndex(where: { $0.window === window }) {
            guard windows[index].browser !== browser || windows[index].prompts !== prompts else { return }
            windows[index] = WindowRecord(window: window, browser: browser, prompts: prompts)
        } else {
            windows.append(WindowRecord(window: window, browser: browser, prompts: prompts))
        }
        registrationID = UUID()
    }

    func unregister(_ browser: BrowserState?, from window: NSWindow) {
        let count = windows.count
        windows.removeAll { $0.window === window && $0.browser === browser }
        if windows.count != count { registrationID = UUID() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard quitTask == nil else { return .terminateLater }
        guard windows.contains(where: { $0.browser?.preview.isDirty == true || $0.browser?.preview.isSaving == true }) else {
            return .terminateNow
        }
        quitTask = Task {
            let approved = await prepareToQuit()
            quitTask = nil
            sender.reply(toApplicationShouldTerminate: approved)
        }
        return .terminateLater
    }

    /// Defer discards until every window agrees, so a later cancellation retains pending drafts.
    func prepareToQuit() async -> Bool {
        guard !isResolvingQuit else { return false }
        isResolvingQuit = true
        defer { isResolvingQuit = false }
        let registration = registrationID
        let snapshots = windows.compactMap { record -> QuitSnapshot? in
            guard let window = record.window, let browser = record.browser, let prompts = record.prompts else { return nil }
            let preview = browser.preview
            return QuitSnapshot(window: window, preview: preview, prompts: prompts,
                                document: preview.documentID, text: preview.text, dirty: preview.isDirty)
        }
        func draftsAreCurrent() -> Bool {
            registrationID == registration && snapshots.allSatisfy { $0.draftUnchanged }
        }
        guard snapshots.allSatisfy({ $0.window.attachedSheet == nil && !$0.preview.isSaving
            && (!$0.dirty || $0.preview.canEdit) }) else { return false }
        var discarded: [PreviewState] = []
        for snapshot in snapshots where snapshot.dirty {
            let preview = snapshot.preview
            guard draftsAreCurrent(), !preview.isSaving, preview.canEdit else { return false }
            let choice = await withCheckedContinuation { continuation in
                snapshot.prompts.confirmChanges(preview.selection?.item.name ?? "this file") {
                    continuation.resume(returning: $0)
                }
            }
            guard draftsAreCurrent(), !preview.isSaving, preview.canEdit else { return false }
            switch choice {
            case .cancel: return false
            case .discard: discarded.append(preview)
            case .save:
                guard await preview.save() else { return false }
            }
        }
        guard draftsAreCurrent(), snapshots.allSatisfy({ snapshot in
            let preview = snapshot.preview
            return !preview.isSaving && (!preview.isDirty || (preview.canEdit && discarded.contains(where: { $0 === preview })))
        }) else { return false }
        discarded.forEach { $0.discardChanges() }
        return true
    }
}

@MainActor final class BrowserPrompts {
    typealias Present = @MainActor (NSAlert, NSWindow, @escaping @MainActor (NSApplication.ModalResponse) -> Void) -> Void
    weak var window: NSWindow?
    private let present: Present

    init(present: @escaping Present = { alert, window, completion in
        alert.beginSheetModal(for: window) { response in
            DispatchQueue.main.async { completion(response) }
        }
    }) {
        self.present = present
    }

    private func show(_ makeAlert: @escaping @MainActor () -> NSAlert,
                      completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void) {
        // Capture the owner before returning to the originating command's event loop.
        DispatchQueue.main.async { [weak self, weak window = window] in
            guard let self, let window, self.window === window else { completion(.abort); return }
            var answered = false
            present(makeAlert(), window) { response in
                guard !answered else { return }
                answered = true
                completion(response)
            }
        }
    }

    func confirmChanges(_ fileName: String, completion: @escaping @MainActor (BrowserState.UnsavedChoice) -> Void) {
        show {
            let alert = NSAlert()
            alert.messageText = "Save changes to \(fileName)?"
            alert.informativeText = "Save keeps your changes. Discard continues without saving. Cancel keeps the draft open."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
            alert.addButton(withTitle: "Discard")
            return alert
        } completion: { response in
            let choice: BrowserState.UnsavedChoice = switch response {
            case .alertFirstButtonReturn: .save
            case .alertThirdButtonReturn: .discard
            default: .cancel
            }
            completion(choice)
        }
    }

    func confirmMove(_ operation: ItemMove.Batch, completion: @escaping @MainActor (Bool) -> Void) {
        show {
            let alert = NSAlert()
            alert.messageText = "Move \(operation.items.count) \(operation.items.count == 1 ? "item" : "items")?"
            alert.informativeText = "Destination:\n" + (operation.items.first?.destination.deletingLastPathComponent().path ?? "")
            alert.accessoryView = Self.sourceList(operation.items.map { $0.source.path })
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move")
            alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
            return alert
        } completion: { response in
            completion(response == .alertFirstButtonReturn)
        }
    }

    func confirmTrash(_ operation: ItemTrash.Batch, completion: @escaping @MainActor (Bool) -> Void) {
        show {
            let alert = NSAlert()
            alert.messageText = "Move \(operation.items.count) \(operation.items.count == 1 ? "item" : "items") to Trash?"
            alert.informativeText = "Items will remain in Trash until it is emptied."
            alert.accessoryView = Self.sourceList(operation.items.map { $0.source.path })
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move to Trash")
            alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
            return alert
        } completion: { response in
            completion(response == .alertFirstButtonReturn)
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
    let prompts: BrowserPrompts
    let lifecycle: BrowserLifecycle

    func makeNSView(context: Context) -> GuardView { GuardView() }

    func updateNSView(_ view: GuardView, context: Context) {
        view.browser = browser
        view.prompts = prompts
        view.lifecycle = lifecycle
        view.install()
        let dirty = browser.preview.isDirty
        if view.window?.isDocumentEdited != dirty { view.window?.isDocumentEdited = dirty }
    }

    static func dismantleNSView(_ view: GuardView, coordinator: ()) {
        view.uninstall()
    }

    final class GuardView: NSView {
        weak var browser: BrowserState?
        weak var prompts: BrowserPrompts?
        weak var lifecycle: BrowserLifecycle?
        private weak var installedWindow: NSWindow?
        private weak var installedBrowser: BrowserState?
        private weak var installedLifecycle: BrowserLifecycle?
        private weak var installedPrompts: BrowserPrompts?
        private let proxy = WindowDelegate()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            install()
        }

        func install() {
            if installedWindow !== window || installedBrowser !== browser || installedLifecycle !== lifecycle || installedPrompts !== prompts {
                uninstall()
            }
            guard let window, let browser, let prompts, let lifecycle else { return }
            installedWindow = window
            installedBrowser = browser
            installedLifecycle = lifecycle
            installedPrompts = prompts
            prompts.window = window
            lifecycle.register(browser, in: window, prompts: prompts)
            proxy.browser = browser
            proxy.prompts = prompts
            proxy.lifecycle = lifecycle
            if window.delegate !== proxy {
                proxy.original = window.delegate
                window.delegate = proxy
            }
        }

        func uninstall() {
            if let installedWindow {
                installedLifecycle?.unregister(installedBrowser, from: installedWindow)
                if installedPrompts?.window === installedWindow { installedPrompts?.window = nil }
                if installedWindow.delegate === proxy { installedWindow.delegate = proxy.original }
            }
            installedWindow = nil
            installedBrowser = nil
            installedLifecycle = nil
            installedPrompts = nil
            proxy.original = nil
        }
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        weak var browser: BrowserState?
        weak var prompts: BrowserPrompts?
        weak var lifecycle: BrowserLifecycle?
        var original: (any NSWindowDelegate)?

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard lifecycle?.isResolvingQuit != true else { return false }
            guard browser?.resolveChangesIfNeeded(resume: { [weak sender] in sender?.performClose(nil) }) != false else { return false }
            return original?.windowShouldClose?(sender) ?? true
        }

        func windowWillClose(_ notification: Notification) {
            if let window = notification.object as? NSWindow {
                lifecycle?.unregister(browser, from: window)
                if prompts?.window === window { prompts?.window = nil }
            }
            original?.windowWillClose?(notification)
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || original?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}
