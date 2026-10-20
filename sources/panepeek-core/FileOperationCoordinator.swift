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
    private var dragging: DragSelection?
    @ObservationIgnored private weak var dragSource: BrowserState?
    public var isBusy: Bool { operation != nil || saving != nil }
    public var canMutate: Bool { !isBusy && dragging == nil }
    var panes: [DirectoryPane] { windows.compactMap(\.browser).flatMap { [$0.left, $0.right] } }

    public init() {}

    public func register(_ browser: BrowserState) {
        guard !windows.contains(where: { $0.browser === browser }) else { return }
        windows.append(Window(browser: browser))
        registrationID = UUID()
    }

    public func unregister(_ browser: BrowserState) {
        if !browser.holdsNativeDrag { endDrag(from: browser) }
        let count = windows.count
        windows.removeAll { $0.browser == nil || $0.browser === browser }
        if windows.count != count { registrationID = UUID() }
    }

    var dragAccess: DirectoryAccess? { dragging?.access }

    func acceptsDrop(_ sources: [URL]) -> Bool {
        guard let dragging else { return true }
        return Set(dragging.sources.map { $0.standardizedFileURL.path }) == Set(sources.map { $0.standardizedFileURL.path })
    }

    func beginOperation(for browser: BrowserState, receiving sources: [URL]? = nil) -> UUID? {
        guard !isBusy else { return nil }
        if let dragging {
            guard let sources, acceptsDrop(sources) else { return nil }
            affects = dragging.affects
            dragSource?.receiveDrag()
        }
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
        return affects?(url) == true || dragging?.affects(url) == true
    }

    func canSave(_ preview: PreviewState) -> Bool {
        saving == nil && (operation == nil || permittedSave === preview)
            && (preview.selection.map { dragging?.affects($0.item.url) != true } ?? true)
    }

    func beginSave(_ preview: PreviewState) -> Bool {
        guard canSave(preview) else { return false }
        saving = preview
        return true
    }

    func endSave(_ preview: PreviewState) {
        if saving === preview { saving = nil }
    }

    func beginDrag(_ selection: DragSelection, from browser: BrowserState) -> Bool {
        guard !isBusy, dragging == nil else { return false }
        register(browser)
        dragging = selection
        dragSource = browser
        return true
    }

    func endDrag(from browser: BrowserState) {
        guard dragSource === browser else { return }
        dragging = nil
        dragSource = nil
    }

    func hasDirtyDocuments(affecting matches: (URL) -> Bool) -> Bool {
        windows.contains {
            guard let preview = $0.browser?.preview, preview.isDirty, let url = preview.selection?.item.url else { return false }
            return matches(url)
        }
    }

    func refreshAfterSave(at url: URL, savedPreview: PreviewState) async -> [String] {
        let errors = await BrowserState.refreshDirectories([url.deletingLastPathComponent().path], panes: panes)
        // Accept the saved owner's metadata before its Save guard releases.
        if let browser = windows.compactMap(\.browser).first(where: { $0.preview === savedPreview }),
           let selection = browser.detailsSelection, selection.item.url == url {
            await savedPreview.load(selection)
        }
        return errors
    }

    /// Install the shared edit lock before confirmation or a deferred dirty prompt.
    func lockPreviews(affecting matches: @escaping (URL) -> Bool) {
        affects = matches
    }

    /// Keep Discard pending until every affected document agrees to the operation.
    func resolveChanges() async -> Resolution? {
        guard let matches = affects else { return nil }
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
                let succeeded = await preview.save()
                permittedSave = nil
                guard succeeded, draftsAreCurrent() else { return nil }
                saved.append((snapshot.url, preview.fileSnapshot))
            }
        }
        guard draftsAreCurrent() else { return nil }
        return Resolution(saved: saved, discarded: discarded)
    }

    func refreshRestoredPreviews(at urls: [URL]) async -> [String] {
        var errors: [String] = []
        for browser in windows.compactMap(\.browser) {
            for url in urls {
                if let error = await browser.preview.refreshRestoredSnapshot(at: url) { errors.append(error) }
            }
        }
        return errors
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
