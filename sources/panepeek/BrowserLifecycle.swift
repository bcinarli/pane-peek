import AppKit
import SwiftUI
import PanePeekCore
import Observation

@MainActor final class BrowserLifecycle: NSObject, NSApplicationDelegate {
    let operations = FileOperationCoordinator()
    private let restoration: WindowRestoration
    private weak var lastActiveWindow: NSWindow?

    override convenience init() { self.init(preferences: .standard) }

    init(preferences: UserDefaults) {
        restoration = WindowRestoration(preferences: preferences)
        super.init()
    }

    func start(_ browser: BrowserState, sizing: DetailsSizing) async {
        await restoration.start(browser, sizing: sizing) {
            if let window = windows.first(where: { $0.browser === browser })?.window {
                restoreFrameIfNeeded(sizing, in: window)
            }
        }
        if let record = windows.first(where: { $0.browser === browser }), let window = record.window {
            remember(browser, in: window, sizing: sizing)
        }
    }
    private struct WindowRecord {
        let observationID = UUID()
        weak var window: NSWindow?
        weak var browser: BrowserState?
        weak var prompts: BrowserPrompts?
        weak var owner: AnyObject?
        weak var sizing: DetailsSizing?
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

    func register(_ browser: BrowserState, in window: NSWindow, prompts: BrowserPrompts, owner: AnyObject, sizing: DetailsSizing? = nil) {
        browser.operations.register(browser)
        if let index = windows.firstIndex(where: { $0.window === window }) {
            guard windows[index].browser !== browser || windows[index].prompts !== prompts || windows[index].owner !== owner || windows[index].sizing !== sizing else { return }
            if let previous = windows[index].browser, previous !== browser { previous.operations.unregister(previous) }
            if windows[index].prompts !== prompts, windows[index].prompts?.window === window { windows[index].prompts?.window = nil }
            windows[index] = WindowRecord(window: window, browser: browser, prompts: prompts, owner: owner, sizing: sizing)
        } else {
            windows.append(WindowRecord(window: window, browser: browser, prompts: prompts, owner: owner, sizing: sizing))
        }
        registrationID = UUID()
        if let sizing, let record = windows.first(where: { $0.window === window }) {
            restoreFrameIfNeeded(sizing, in: window)
            observe(browser, in: window, sizing: sizing, registration: record.observationID)
        }
        if window.isKeyWindow { activate(window) }
    }

    @discardableResult func unregister(_ browser: BrowserState?, from window: NSWindow, owner: AnyObject) -> Bool {
        if let record = windows.first(where: { $0.window === window && $0.browser === browser && $0.owner === owner }),
           let browser = record.browser, let sizing = record.sizing {
            remember(browser, in: window, sizing: sizing)
        }
        let count = windows.count
        windows.removeAll { $0.window === window && $0.browser === browser && $0.owner === owner }
        guard windows.count != count else { return false }
        if let browser { browser.operations.unregister(browser) }
        registrationID = UUID()
        return true
    }

    func activate(_ window: NSWindow) {
        guard !isResolvingQuit, let record = windows.first(where: { $0.window === window }) else { return }
        lastActiveWindow = window
        if let browser = record.browser, let sizing = record.sizing { remember(browser, in: window, sizing: sizing) }
    }

    private func remember(_ browser: BrowserState, in window: NSWindow, sizing: DetailsSizing) {
        guard lastActiveWindow === window else { return }
        restoration.remember(browser, sizing: sizing, frame: window.frame)
    }

    private func restoreFrameIfNeeded(_ sizing: DetailsSizing, in window: NSWindow) {
        guard let frame = sizing.frameToRestore else { return }
        sizing.frameToRestore = nil
        var minimum = window.frameRect(forContentRect: NSRect(origin: .zero, size: WindowGeometry.minimumContentSize)).size
        minimum.width = max(minimum.width, window.minSize.width)
        minimum.height = max(minimum.height, window.minSize.height)
        let restored = WindowGeometry.constrained(frame, screens: NSScreen.screens.map(\.visibleFrame), minimumSize: minimum)
        window.setFrame(restored, display: false)
    }

    func geometryDidChange(_ window: NSWindow, owner: AnyObject) {
        guard let record = windows.first(where: { $0.window === window && $0.owner === owner }),
              let browser = record.browser, let sizing = record.sizing else { return }
        remember(browser, in: window, sizing: sizing)
    }

    private func observe(_ browser: BrowserState, in window: NSWindow, sizing: DetailsSizing, registration: UUID) {
        withObservationTracking {
            _ = WindowConfiguration(browser: browser, sizing: sizing)
            _ = browser.startupState
        } onChange: { [weak self, weak browser, weak window, weak sizing] in
            Task { @MainActor in
                guard let self, let browser, let window, let sizing,
                      self.windows.contains(where: { $0.observationID == registration }) else { return }
                self.remember(browser, in: window, sizing: sizing)
                self.observe(browser, in: window, sizing: sizing, registration: registration)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows && !windows.contains(where: { $0.window != nil }) {
            restoration.reopen()
        }
        return true
    }

    private func rememberActiveWindow() {
        guard let window = lastActiveWindow,
              let record = windows.first(where: { $0.window === window }),
              let browser = record.browser, let sizing = record.sizing else { return }
        restoration.remember(browser, sizing: sizing, frame: window.frame)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !operations.isBusy else { return .terminateCancel }
        guard quitTask == nil else { return .terminateLater }
        guard windows.contains(where: { $0.browser?.preview.isDirty == true || $0.browser?.preview.isSaving == true }) else {
            rememberActiveWindow()
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
        guard !isResolvingQuit, !operations.isBusy else { return false }
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
        guard !operations.isBusy, draftsAreCurrent(), snapshots.allSatisfy({ snapshot in
            let preview = snapshot.preview
            return !preview.isSaving && (!preview.isDirty || (preview.canEdit && discarded.contains(where: { $0 === preview })))
        }) else { return false }
        discarded.forEach { $0.discardChanges() }
        rememberActiveWindow()
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
    let sizing: DetailsSizing
    let prompts: BrowserPrompts
    let lifecycle: BrowserLifecycle
    let quickLookSelection: QuickLookSelection

    func makeNSView(context: Context) -> GuardView { GuardView() }

    func updateNSView(_ view: GuardView, context: Context) {
        view.browser = browser
        view.sizing = sizing
        view.prompts = prompts
        view.lifecycle = lifecycle
        view.quickLookSelection = quickLookSelection
        view.install()
        let dirty = browser.preview.isDirty
        if view.window?.isDocumentEdited != dirty { view.window?.isDocumentEdited = dirty }
    }

    static func dismantleNSView(_ view: GuardView, coordinator: ()) {
        view.uninstall()
    }

    final class GuardView: NSView {
        weak var browser: BrowserState?
        weak var sizing: DetailsSizing?
        weak var prompts: BrowserPrompts?
        weak var lifecycle: BrowserLifecycle?
        private weak var installedWindow: NSWindow?
        private weak var installedBrowser: BrowserState?
        private weak var installedLifecycle: BrowserLifecycle?
        private weak var installedPrompts: BrowserPrompts?
        private weak var installedSizing: DetailsSizing?
        private let proxy = WindowDelegate()
        var quickLookSelection = QuickLookSelection()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            install()
        }

        func install() {
            if installedWindow !== window || installedBrowser !== browser || installedLifecycle !== lifecycle || installedPrompts !== prompts || installedSizing !== sizing {
                uninstall()
            }
            guard let window, let browser, let prompts, let lifecycle else { return }
            installedWindow = window
            installedBrowser = browser
            installedLifecycle = lifecycle
            installedPrompts = prompts
            installedSizing = sizing
            prompts.window = window
            lifecycle.register(browser, in: window, prompts: prompts, owner: proxy, sizing: sizing)
            proxy.browser = browser
            proxy.prompts = prompts
            proxy.lifecycle = lifecycle
            proxy.quickLook.update(quickLookSelection)
            if window.delegate !== proxy {
                if let previous = window.delegate as? WindowDelegate {
                    proxy.original = previous.original
                } else {
                    proxy.original = window.delegate
                }
                window.delegate = proxy
            }
            proxy.quickLook.install(in: window)
        }

        func uninstall() {
            proxy.quickLook.stop()
            if let installedWindow {
                let removed = installedLifecycle?.unregister(installedBrowser, from: installedWindow, owner: proxy) == true
                if removed, installedPrompts?.window === installedWindow { installedPrompts?.window = nil }
                if installedWindow.delegate === proxy { installedWindow.delegate = proxy.original }
            }
            installedWindow = nil
            installedBrowser = nil
            installedLifecycle = nil
            installedPrompts = nil
            installedSizing = nil
            proxy.original = nil
        }
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate, QuickLookControlling {
        let quickLook = QuickLookPreview()
        weak var browser: BrowserState?
        weak var prompts: BrowserPrompts?
        weak var lifecycle: BrowserLifecycle?
        var original: (any NSWindowDelegate)?

        func toggleQuickLook() {
            guard browser?.renameRequest == nil else { return }
            quickLook.toggle()
        }

        func closeQuickLook() -> Bool { quickLook.close() }

        func windowDidBecomeKey(_ notification: Notification) {
            if let window = notification.object as? NSWindow { lifecycle?.activate(window) }
            original?.windowDidBecomeKey?(notification)
        }

        func windowDidMove(_ notification: Notification) {
            if let window = notification.object as? NSWindow { lifecycle?.geometryDidChange(window, owner: self) }
            original?.windowDidMove?(notification)
        }

        func windowDidResize(_ notification: Notification) {
            if let window = notification.object as? NSWindow { lifecycle?.geometryDidChange(window, owner: self) }
            original?.windowDidResize?(notification)
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard lifecycle?.isResolvingQuit != true else { return false }
            guard browser?.resolveChangesIfNeeded(resume: { [weak sender] in sender?.performClose(nil) }) != false else { return false }
            return original?.windowShouldClose?(sender) ?? true
        }

        func windowWillClose(_ notification: Notification) {
            quickLook.stop()
            if let window = notification.object as? NSWindow {
                let removed = lifecycle?.unregister(browser, from: window, owner: self) == true
                if removed, prompts?.window === window { prompts?.window = nil }
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
