import AppKit
import Observation

/// Keeps SwiftUI's file commands in step with native focus and clipboard changes.
@MainActor @Observable final class BrowserFileMenuState: NSObject {
    private(set) weak var table: DirectoryTableView?
    private var clipboardRevision = 0

    override init() {
        super.init()
        for name in [NSWindow.didUpdateNotification, NSMenu.didBeginTrackingNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(refresh(_:)), name: name, object: nil)
        }
        refresh(in: NSApp.keyWindow)
    }

    @objc private func refresh(_ notification: Notification) { refresh(in: NSApp.keyWindow) }

    func refresh(in window: NSWindow?) {
        let focused = window?.firstResponder as? DirectoryTableView
        if table !== focused { table = focused }
        let revision = table?.filePasteboard.changeCount ?? NSPasteboard.general.changeCount
        if clipboardRevision != revision { clipboardRevision = revision }
    }

    var canMove: Bool {
        _ = clipboardRevision
        return table?.canPasteFiles == true
    }

    var canTrash: Bool { table?.canTrashFiles == true }

    func move() { (NSApp.keyWindow?.firstResponder as? DirectoryTableView)?.moveItemHere(nil) }
    func trash() { (NSApp.keyWindow?.firstResponder as? DirectoryTableView)?.moveSelectionToTrash(nil) }
}
