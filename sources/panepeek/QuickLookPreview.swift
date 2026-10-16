import AppKit
import QuickLookUI
import PanePeekCore

@MainActor protocol QuickLookControlling: AnyObject {
    func toggleQuickLook()
    @discardableResult func closeQuickLook() -> Bool
}

struct QuickLookSelection: Equatable {
    let urls: [URL]
    let primaryIndex: Int

    @MainActor init(pane: DirectoryPane? = nil) {
        guard let pane else { urls = []; primaryIndex = 0; return }
        urls = pane.entries.filter { pane.selectedItems.contains($0.url) }.map(\.url)
        primaryIndex = urls.firstIndex { $0 == pane.primaryItemURL } ?? 0
    }
}

// Quick Look's legacy callbacks lack main-actor annotations.
@MainActor final class QuickLookPreview: NSResponder, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    private(set) weak var window: NSWindow?
    private(set) var selection = QuickLookSelection()
    private weak var panel: QLPreviewPanel?
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { window != nil }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        self.panel = panel
        panel.dataSource = self
        panel.delegate = self
        refresh()
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { release(panel) }

    func install(in window: NSWindow) {
        guard self.window !== window || window.nextResponder !== self else { return }
        stop()
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
        if self.panel === panel { self.panel = nil }
    }

    func stop() {
        if let panel {
            close()
            release(panel)
        }
        if window?.nextResponder === self { window?.nextResponder = nextResponder }
        nextResponder = nil
        window = nil
    }

    private func refresh() {
        guard let panel, panel.dataSource === self else { return }
        panel.reloadData()
        if selection.urls.isEmpty { close() }
        else { panel.currentPreviewItemIndex = selection.primaryIndex }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { selection.urls.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard selection.urls.indices.contains(index) else { return nil }
        return selection.urls[index] as NSURL
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
