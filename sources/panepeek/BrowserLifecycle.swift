import AppKit
import SwiftUI
import PanePeekCore
import Observation

struct BrowserScene: Codable, Hashable {
    let id: UUID
    let restores: Bool
    init(restores: Bool) { id = UUID(); self.restores = restores }
}

@MainActor final class BrowserLifecycle: NSObject, NSApplicationDelegate {
    private var updateWindow: UpdateWindow?
    private var terminalCommandWindow: TerminalCommandWindow?
    private var wakeObservation: (any NSObjectProtocol)?
    let updates: AppUpdates
    let operations = FileOperationCoordinator()
    let folderAccess: FolderAccess
    private let restoration: WindowRestoration
    private weak var lastActiveWindow: NSWindow?
    let initialScene = BrowserScene(restores: true)
    private var initialSceneStarted = false
    private var hasFinishedLaunching = false
    private var sceneOpener: ((BrowserScene) -> Void)?
    private var pendingScene: BrowserScene?
    private var sceneRequested = false
    private var pendingOpen: IncomingOpen?
    private var scenes: [ObjectIdentifier: BrowserScene] = [:]

    private final class IncomingOpen {
        let destination: IncomingRequest
        var url: URL { destination.url }
        var pane: PaneID?
        var navigation: UUID?
        init(_ destination: IncomingRequest, pane: PaneID? = nil) { self.destination = destination; self.pane = pane }
    }

    func systemScene() -> BrowserScene {
        if !initialSceneStarted { return initialScene }
        return pendingScene ?? BrowserScene(restores: true)
    }

    func installSceneOpener(_ open: @escaping (BrowserScene) -> Void) {
        sceneOpener = open
        guard pendingOpen != nil else { return }
        // Commands can install this while SwiftUI is still updating the scene tree.
        DispatchQueue.main.async { [weak self] in self?.requestPendingScene() }
    }

    private func requestPendingScene() {
        guard initialSceneStarted || hasFinishedLaunching,
              pendingOpen != nil, !isResolvingQuit,
              let pendingScene, let sceneOpener, !sceneRequested else { return }
        sceneRequested = true
        sceneOpener(pendingScene)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !isResolvingQuit else { return }
        let live = windows.filter { $0.window != nil && $0.browser != nil }
        let record = live.first { $0.window === lastActiveWindow } ?? live.last
        let destination: IncomingRequest?
        if urls.count == 1, let url = urls.first {
            if let launcher = LauncherRequest(eventURL: url) { destination = .launcher(launcher) }
            else if BrowserState.acceptsDropSources(urls) { destination = .native(url) }
            else { destination = nil }
        } else { destination = nil }
        guard let destination else {
            let message = "Open one local file or folder at a time."
            if let browser = record?.browser { browser.notifications.post(message, kind: .error) }
            else {
                let alert = NSAlert()
                alert.messageText = "Couldn’t Open Items"
                alert.informativeText = message
                alert.runModal()
            }
            return
        }
        if let record, let browser = record.browser {
            cancelIncoming(record)
            record.incoming = IncomingOpen(destination, pane: browser.startupState == .pending ? nil : browser.focusedPane)
            startIncoming(record)
        } else {
            pendingOpen = IncomingOpen(destination)
            if pendingScene == nil { pendingScene = initialSceneStarted ? BrowserScene(restores: true) : initialScene }
            requestPendingScene()
        }
    }

    override convenience init() { self.init(preferences: .standard) }

    init(preferences: UserDefaults, folderAccess: FolderAccess? = nil, updates: AppUpdates? = nil) {
        self.updates = updates ?? UpdateComposition.make(preferences: preferences)
        let access = folderAccess ?? FolderAccess(preferences: FolderAccess.isSandboxed() ? preferences : nil, selectionMode: .readWrite)
        self.folderAccess = access
        restoration = WindowRestoration(preferences: preferences, folderAccess: access)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hasFinishedLaunching = true
        requestPendingScene()
        if updates.isEnabled { updateWindow = updateWindow ?? UpdateWindow(updates: updates) }
        updates.setApplicationActive(NSApp.isActive)
        updates.startAutomaticChecks()
        wakeObservation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updates.resumeAutomaticChecks() }
            }
    }

    func applicationDidBecomeActive(_ notification: Notification) { updates.setApplicationActive(true) }
    func applicationDidResignActive(_ notification: Notification) { updates.setApplicationActive(false) }

    func applicationWillTerminate(_ notification: Notification) {
        updates.stopAutomaticChecks()
        if let wakeObservation { NSWorkspace.shared.notificationCenter.removeObserver(wakeObservation) }
        wakeObservation = nil
    }

    func showTerminalCommand() {
        guard let home = FolderAccess.accountHome else { return }
        let window = terminalCommandWindow ?? TerminalCommandWindow(home: home, folderAccess: folderAccess)
        terminalCommandWindow = window
        window.show()
    }

    func checkForUpdates() {
        guard updates.isEnabled else { return }
        let window = updateWindow ?? UpdateWindow(updates: updates)
        updateWindow = window
        window.show()
    }

    func start(_ browser: BrowserState, sizing: DetailsSizing, scene: BrowserScene? = nil) async {
        if let scene {
            scenes[ObjectIdentifier(browser)] = scene
            if scene == initialScene { initialSceneStarted = true }
            adoptPendingOpen(for: browser)
        }
        let record = windows.first { $0.browser === browser }
        let incoming = record?.incoming != nil || (scene != nil && scene == pendingScene && pendingOpen != nil)
        await restoration.start(browser, sizing: sizing, restoring: scene?.restores, incoming: incoming, restoreFrame: {
            if let window = windows.first(where: { $0.browser === browser })?.window {
                restoreFrameIfNeeded(sizing, in: window)
            }
        }, configured: {
            if let record = windows.first(where: { $0.browser === browser }) { startIncoming(record) }
        })
        if let record = windows.first(where: { $0.browser === browser }), let window = record.window {
            remember(browser, in: window, sizing: sizing)
        }
    }
    private final class WindowRecord {
        var observationID = UUID()
        weak var window: NSWindow?
        weak var browser: BrowserState?
        weak var prompts: BrowserPrompts?
        weak var owner: AnyObject?
        weak var sizing: DetailsSizing?
        var incoming: IncomingOpen?
        var incomingTask: Task<Void, Never>?
        var protectedPane: PaneID?
        init(window: NSWindow, browser: BrowserState, prompts: BrowserPrompts, owner: AnyObject, sizing: DetailsSizing?) {
            self.window = window; self.browser = browser; self.prompts = prompts; self.owner = owner; self.sizing = sizing
        }
    }

    private func adoptPendingOpen(for browser: BrowserState) {
        guard scenes[ObjectIdentifier(browser)] == pendingScene,
              let record = windows.first(where: { $0.browser === browser }), let pendingOpen else { return }
        record.incoming = pendingOpen
        self.pendingOpen = nil
        pendingScene = nil
        sceneRequested = false
    }

    private func cancelIncoming(_ record: WindowRecord) {
        record.incomingTask?.cancel()
        record.incomingTask = nil
        if let request = record.incoming, let id = request.pane,
           record.browser?.pane(id).navigationRevision == request.navigation {
            record.browser?.beginExternalOpen(in: id)
        }
        record.incoming = nil
    }

    private func startIncoming(_ record: WindowRecord) {
        guard record.incomingTask == nil, let request = record.incoming, let browser = record.browser,
              let window = record.window, browser.startupState != .pending else { return }
        let id = request.pane ?? browser.focusedPane
        request.pane = id
        if !browser.pane(id).hasLoaded { record.protectedPane = id }
        let navigation = browser.beginExternalOpen(in: id)
        request.navigation = navigation
        record.incomingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if record.incoming === request { record.incoming = nil; record.incomingTask = nil }
            }
            @MainActor func current() -> Bool {
                !Task.isCancelled && record.incoming === request && browser.pane(id).navigationRevision == navigation
                    && windows.contains { $0 === record }
            }
            do {
                let choose: FolderAccess.Choose = { initial in
                    while window.attachedSheet != nil {
                        try Task.checkCancellation()
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    guard current() else { throw CancellationError() }
                    return try await FolderAccess.chooseFolder(initial: initial, window: window, purpose: .opening)
                }
                while window.attachedSheet != nil {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(100))
                }
                guard current() else { return }
                let destination = try await IncomingPath.prepare(request.destination, access: browser.requiresFolderAccess ? folderAccess : nil, choose: choose)
                guard current() else { return }
                let opened = await browser.openExternal(directory: destination.listing.directory, selecting: destination.selection,
                                                        in: id, request: navigation, using: { _ in
                    try await destination.validate()
                    return destination.listing
                })
                guard current() else { return }
                if opened {
                    record.protectedPane = nil
                    if window.isMiniaturized { window.deminiaturize(nil) }
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate()
                    activate(window)
                } else if let error = browser.pane(id).errorMessage { browser.notifications.post(error, kind: .error) }
            } catch is CancellationError { /* Explicit cancellation and obsolete requests stay quiet. */ }
            catch {
                if current() { browser.notifications.post("Couldn’t open \(request.url.path). \(error.localizedDescription)", kind: .error) }
            }
        }
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
            let record = windows[index]
            record.observationID = UUID()
            if record.browser !== browser { cancelIncoming(record); record.protectedPane = nil }
            record.browser = browser
            record.prompts = prompts
            record.owner = owner
            record.sizing = sizing
        } else {
            windows.append(WindowRecord(window: window, browser: browser, prompts: prompts, owner: owner, sizing: sizing))
        }
        registrationID = UUID()
        if let sizing, let record = windows.first(where: { $0.window === window }) {
            restoreFrameIfNeeded(sizing, in: window)
            observe(browser, in: window, sizing: sizing, registration: record.observationID)
        }
        adoptPendingOpen(for: browser)
        if let record = windows.first(where: { $0.window === window }) { startIncoming(record) }
        if window.isKeyWindow { activate(window) }
    }

    @discardableResult func unregister(_ browser: BrowserState?, from window: NSWindow, owner: AnyObject) -> Bool {
        if let record = windows.first(where: { $0.window === window && $0.browser === browser && $0.owner === owner }),
           let browser = record.browser, let sizing = record.sizing {
            remember(browser, in: window, sizing: sizing)
        }
        let count = windows.count
        for record in windows where record.window === window && record.browser === browser && record.owner === owner { cancelIncoming(record) }
        windows.removeAll { $0.window === window && $0.browser === browser && $0.owner === owner }
        guard windows.count != count else { return false }
        if let browser {
            scenes.removeValue(forKey: ObjectIdentifier(browser))
            browser.operations.unregister(browser)
            if browser.requiresFolderAccess { browser.left.releaseAccess(); browser.right.releaseAccess() }
        }
        registrationID = UUID()
        return true
    }

    func activate(_ window: NSWindow) {
        guard !isResolvingQuit, let record = windows.first(where: { $0.window === window }) else { return }
        lastActiveWindow = window
        windows.removeAll { $0 === record }
        windows.append(record)
        if let browser = record.browser, let sizing = record.sizing { remember(browser, in: window, sizing: sizing) }
    }

    private func remember(_ browser: BrowserState, in window: NSWindow, sizing: DetailsSizing) {
        guard lastActiveWindow === window else { return }
        if let record = windows.first(where: { $0.window === window }), let id = record.protectedPane,
           !browser.pane(id).hasLoaded { return }
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
        remember(browser, in: window, sizing: sizing)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !operations.isBusy else { return .terminateCancel }
        windows.forEach { cancelIncoming($0) }
        pendingOpen = nil
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
        windows.forEach { cancelIncoming($0) }
        pendingOpen = nil
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
    typealias Present = @MainActor (UnsavedChangesSheet, NSWindow, @escaping @MainActor (BrowserState.UnsavedChoice) -> Void) -> Void
    typealias PresentCollision = @MainActor (TransferCollisionSheet, NSWindow, @escaping @MainActor (ItemTransfer.CollisionChoice) -> Void) -> Void
    weak var window: NSWindow?
    private let present: Present
    private let presentCollision: PresentCollision

    init(present: @escaping Present = { sheet, window, completion in
        window.beginSheet(sheet) { _ in
            DispatchQueue.main.async { completion(sheet.choice) }
        }
    }, presentCollision: @escaping PresentCollision = { sheet, window, completion in
        window.beginSheet(sheet) { _ in
            DispatchQueue.main.async { completion(sheet.choice) }
        }
    }) {
        self.present = present
        self.presentCollision = presentCollision
    }

    func confirmChanges(_ fileName: String, completion: @escaping @MainActor (BrowserState.UnsavedChoice) -> Void) {
        // Capture the owner before returning to the originating command's event loop.
        DispatchQueue.main.async { [weak self, weak window = window] in
            guard let self, let window, self.window === window else { completion(.cancel); return }
            var answered = false
            self.present(UnsavedChangesSheet(fileName), window) { choice in
                guard !answered else { return }
                answered = true
                completion(choice)
            }
        }
    }

    func resolveTransferCollision(_ collision: ItemTransfer.Collision, completion: @escaping @MainActor (ItemTransfer.CollisionChoice) -> Void) {
        DispatchQueue.main.async { [weak self, weak window = window] in
            guard let self, let window, self.window === window else { completion(.cancel); return }
            var answered = false
            self.presentCollision(TransferCollisionSheet(collision), window) { choice in
                guard !answered else { return }
                answered = true
                completion(choice)
            }
        }
    }
}

struct BrowserWindowGuard: NSViewRepresentable {
    let browser: BrowserState
    let sizing: DetailsSizing
    let prompts: BrowserPrompts
    let lifecycle: BrowserLifecycle
    let quickLookSelection: QuickLookSelection
    var find: BrowserFind? = nil
    var findBlocked = false

    func makeNSView(context: Context) -> GuardView { GuardView() }

    func updateNSView(_ view: GuardView, context: Context) {
        view.browser = browser
        view.sizing = sizing
        view.prompts = prompts
        view.lifecycle = lifecycle
        view.quickLookSelection = quickLookSelection
        view.find = find
        find?.isBlocked = findBlocked
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
        weak var find: BrowserFind?
        private weak var installedWindow: NSWindow?
        private weak var installedBrowser: BrowserState?
        private weak var installedLifecycle: BrowserLifecycle?
        private weak var installedPrompts: BrowserPrompts?
        private weak var installedSizing: DetailsSizing?
        private weak var closedWindow: NSWindow?
        private var proxy = WindowDelegate(original: nil)
        var quickLookSelection = QuickLookSelection()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            install()
        }

        func install() {
            // SwiftUI can update a retained view after its window closes.
            if let window, window === closedWindow { return }
            if installedWindow !== window || installedBrowser !== browser || installedLifecycle !== lifecycle || installedPrompts !== prompts || installedSizing !== sizing {
                uninstall()
            }
            guard let window, let browser, let prompts, let lifecycle else { return }
            window.backgroundColor = AppColours.frame
            window.titlebarAppearsTransparent = true
            if window.delegate !== proxy {
                let original: (any NSWindowDelegate)?
                if let previous = window.delegate as? WindowDelegate { original = previous.original }
                else { original = window.delegate }
                proxy.quickLook.stop()
                proxy = WindowDelegate(original: original, onClose: { [weak self] window in
                    self?.closedWindow = window
                })
            }
            installedWindow = window
            installedBrowser = browser
            installedLifecycle = lifecycle
            installedPrompts = prompts
            installedSizing = sizing
            prompts.window = window
            find?.window = window
            find?.browser = browser
            DispatchQueue.main.async { [weak find] in find?.refresh() }
            lifecycle.register(browser, in: window, prompts: prompts, owner: proxy, sizing: sizing)
            proxy.browser = browser
            proxy.prompts = prompts
            proxy.lifecycle = lifecycle
            proxy.quickLook.update(quickLookSelection)
            if window.delegate !== proxy {
                window.delegate = proxy
            }
            proxy.quickLook.install(in: window)
        }

        func uninstall() {
            proxy.quickLook.stop()
            find?.window = nil
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
            proxy = WindowDelegate(original: nil)
        }
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate, QuickLookControlling {
        @MainActor let quickLook = QuickLookPreview()
        @MainActor weak var browser: BrowserState?
        @MainActor weak var prompts: BrowserPrompts?
        @MainActor weak var lifecycle: BrowserLifecycle?
        // Objective-C forwarding reads this synchronously without entering the main actor.
        let original: (any NSWindowDelegate)?
        @MainActor private let onClose: (NSWindow) -> Void

        @MainActor init(original: (any NSWindowDelegate)?, onClose: @escaping (NSWindow) -> Void = { _ in }) {
            self.original = original
            self.onClose = onClose
            super.init()
        }

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
                onClose(window)
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
