import Foundation
import Observation

/// Shares mutation and Save exclusion without blocking navigation or unrelated buffer edits.
@MainActor @Observable
public final class FileOperationCoordinator {
    private struct Window { weak var browser: BrowserState? }
    @MainActor struct Resolution {
        let saved: [(url: URL, snapshot: TextFileSnapshot?)]
        let discarded: [PreviewState]
        func discardChanges() { discarded.forEach { $0.discardChanges() } }
    }

    @ObservationIgnored private var windows: [Window] = []
    @ObservationIgnored private var registrationID = UUID()
    private var operation: UUID?
    private var saving: PreviewState?
    private var permittedSave: PreviewState?
    private var affects: ((URL) -> Bool)?
    public var isBusy: Bool { operation != nil || saving != nil }

    public init() {}

    public func register(_ browser: BrowserState) {
        guard !windows.contains(where: { $0.browser === browser }) else { return }
        windows.append(Window(browser: browser))
        registrationID = UUID()
    }

    public func unregister(_ browser: BrowserState) {
        let count = windows.count
        windows.removeAll { $0.browser == nil || $0.browser === browser }
        if windows.count != count { registrationID = UUID() }
    }

    func beginOperation(for browser: BrowserState) -> UUID? {
        guard !isBusy, !windows.contains(where: { $0.browser !== browser && $0.browser?.isDragging == true }) else { return nil }
        register(browser)
        let id = UUID()
        operation = id
        return id
    }

    func endOperation(_ id: UUID) {
        guard operation == id else { return }
        affects = nil
        permittedSave = nil
        operation = nil
    }

    func isLocked(_ preview: PreviewState) -> Bool {
        guard permittedSave !== preview, let url = preview.selection?.item.url else { return false }
        return affects?(url) == true
    }

    func canSave(_ preview: PreviewState) -> Bool {
        saving == nil && (operation == nil || permittedSave === preview)
    }

    func beginSave(_ preview: PreviewState) -> Bool {
        guard canSave(preview) else { return false }
        saving = preview
        return true
    }

    func endSave(_ preview: PreviewState) {
        if saving === preview { saving = nil }
    }

    /// Keep Discard pending until every affected document agrees to the operation.
    func resolveChanges(affecting matches: @escaping (URL) -> Bool) async -> Resolution? {
        affects = matches
        let registration = registrationID
        let snapshots = windows.compactMap { window -> (browser: BrowserState, document: UUID, text: String, url: URL)? in
            guard let browser = window.browser, browser.preview.isDirty,
                  let url = browser.preview.selection?.item.url, matches(url), let text = browser.preview.text else { return nil }
            return (browser, browser.preview.documentID, text, url)
        }
        func draftsAreCurrent() -> Bool {
            registrationID == registration && snapshots.allSatisfy {
                $0.browser.preview.documentID == $0.document
                    && $0.browser.preview.text?.utf8.elementsEqual($0.text.utf8) == true
            }
        }
        var discarded: [PreviewState] = []
        var saved: [(url: URL, snapshot: TextFileSnapshot?)] = []
        for snapshot in snapshots {
            let preview = snapshot.browser.preview
            guard draftsAreCurrent(), let choice = await snapshot.browser.requestOperationChanges(), draftsAreCurrent() else { return nil }
            switch choice {
            case .cancel: return nil
            case .discard: discarded.append(preview)
            case .save:
                permittedSave = preview
                let succeeded = await preview.saveForOperation()
                permittedSave = nil
                guard succeeded, draftsAreCurrent() else { return nil }
                saved.append((snapshot.url, preview.fileSnapshot))
            }
        }
        guard draftsAreCurrent() else { return nil }
        return Resolution(saved: saved, discarded: discarded)
    }

    /// Removed sources must not leave an editor capable of saving to its old path.
    func closePreviews(affecting matches: (URL) -> Bool) async {
        for browser in windows.compactMap(\.browser) {
            if let selected = browser.preview.selection, matches(selected.item.url) {
                browser.preview.discardChanges()
                await browser.preview.load(nil)
            }
        }
    }
}
