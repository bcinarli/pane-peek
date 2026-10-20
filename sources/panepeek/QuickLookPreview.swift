import AppKit
import Darwin
import CoreFoundation
import ObjectiveC
import QuickLookUI
import PanePeekCore

protocol QuickLookControlling: AnyObject {
    @MainActor func toggleQuickLook()
    @MainActor @discardableResult func closeQuickLook() -> Bool
}

struct QuickLookSelection: Equatable {
    let urls: [URL]
    let primaryIndex: Int
    private(set) weak var access: DirectoryAccess?
    let requiresAccess: Bool
    private let revision: UUID?

    @MainActor init(pane: DirectoryPane? = nil, requiringAccess: Bool = false) {
        guard let pane, !requiringAccess || pane.directoryAccess != nil else {
            urls = []; primaryIndex = 0; access = nil; requiresAccess = requiringAccess; revision = nil; return
        }
        let granted = pane.directoryAccess
        access = granted
        requiresAccess = requiringAccess || granted != nil
        revision = granted == nil ? nil : pane.listingRevision
        urls = pane.entries.filter {
            pane.selectedItems.contains($0.url) && (granted == nil || !$0.isSymbolicLink)
        }.map(\.url)
        primaryIndex = urls.firstIndex { $0 == pane.primaryItemURL } ?? 0
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.urls == rhs.urls && lhs.primaryIndex == rhs.primaryIndex && lhs.revision == rhs.revision && lhs.requiresAccess == rhs.requiresAccess
    }
}

// Quick Look's synchronous UI callbacks lack main-actor annotations.
@MainActor final class QuickLookPreview: NSResponder, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    private(set) weak var window: NSWindow?
    private(set) var selection = QuickLookSelection()
    private weak var panel: QLPreviewPanel?
    private var items: [Int: any QLPreviewItem] = [:]
    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        MainActor.assumeIsolated { window != nil }
    }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            self.panel = panel
            panel.dataSource = self
            panel.delegate = self
            refresh()
        }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { release(panel) }
    }

    func install(in window: NSWindow) {
        guard self.window !== window || window.nextResponder !== self else { return }
        let selection = self.selection
        stop()
        self.selection = selection
        let previous = window.nextResponder
        if let previous = previous as? QuickLookPreview { nextResponder = previous.nextResponder }
        else { nextResponder = previous }
        self.window = window
        window.nextResponder = self
        if QLPreviewPanel.sharedPreviewPanelExists() { QLPreviewPanel.shared()?.updateController() }
    }

    func update(_ selection: QuickLookSelection) {
        guard self.selection != selection else { return }
        self.selection = selection
        items.removeAll()
        refresh()
    }

    func toggle() {
        guard let window, window.attachedSheet == nil, !selection.urls.isEmpty else { return }
        if close() { return }
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.makeKeyAndOrderFront(nil)
        refresh()
        if panel.dataSource === self { panel.refreshCurrentPreviewItem() }
    }

    @discardableResult func close() -> Bool {
        guard let panel, panel.dataSource === self, panel.isVisible else { return false }
        panel.orderOut(nil)
        return true
    }

    private func release(_ panel: QLPreviewPanel) {
        if panel.dataSource === self { panel.dataSource = nil }
        if panel.delegate === self { panel.delegate = nil }
        if self.panel === panel { self.panel = nil; items.removeAll() }
    }

    func stop() {
        if let panel {
            close()
            release(panel)
        }
        if window?.nextResponder === self { window?.nextResponder = nextResponder }
        nextResponder = nil
        window = nil
        items.removeAll()
        selection = QuickLookSelection()
    }

    private func refresh() {
        guard let panel, panel.dataSource === self else { return }
        panel.reloadData()
        guard panel.dataSource === self else { return }
        if selection.urls.isEmpty { close() }
        else { panel.currentPreviewItemIndex = selection.primaryIndex }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { selection.urls.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard selection.urls.indices.contains(index) else { return nil }
        guard selection.requiresAccess else { return selection.urls[index] as NSURL }
        guard let access = selection.access else { return nil }
        if let item = items[index] { return item }
        guard let item = ScopedQuickLookAccess.item(for: selection.urls[index], access: access) else {
            if let panel, panel === self.panel {
                let selection = self.selection
                // Finish the data-source callback before hiding the system panel.
                Task { [weak self, weak panel] in
                    guard let self, let panel, panel.dataSource === self, self.selection == selection else { return }
                    self.close()
                }
            }
            return nil
        }
        items[index] = item
        return item
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        if event.keyCode == 53 || (event.keyCode == 49 && event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty) {
            if !event.isARepeat { close() }
            return true
        }
        if [125, 126].contains(event.keyCode), event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let table = window?.firstResponder as? DirectoryTableView {
            table.keyDown(with: event)
            return true
        }
        return false
    }
}

// Keep the native reference unbridged: Swift URL conversion snapshots its current path.
@MainActor private final class ScopedQuickLookAccess: NSObject {
    private static let ownerKey = NSObject()
    private let handle: FileHandle
    private let access: DirectoryAccess

    private init(handle: FileHandle, access: DirectoryAccess) {
        self.handle = handle
        self.access = access
    }

    static func item(for url: URL, access: DirectoryAccess) -> (any QLPreviewItem)? {
        guard url.isFileURL else { return nil }
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var opened = stat()
        guard fstat(descriptor, &opened) == 0,
              [mode_t(S_IFREG), mode_t(S_IFDIR)].contains(opened.st_mode & mode_t(S_IFMT)),
              let reference = CFURLCreateFileReferenceURL(nil, url as CFURL, nil)?.takeRetainedValue(),
              let native = reference as AnyObject as? NSURL, let path = native.path else { return nil }
        var resolved = stat()
        guard stat(path, &resolved) == 0,
              opened.st_dev == resolved.st_dev, opened.st_ino == resolved.st_ino else { return nil }
        // The item can outlive the controller while the system finishes its preview reads.
        objc_setAssociatedObject(native, Unmanaged.passUnretained(ownerKey).toOpaque(),
                                 ScopedQuickLookAccess(handle: handle, access: access), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return native
    }
}
