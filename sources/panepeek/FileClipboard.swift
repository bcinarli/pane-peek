import AppKit
import PanePeekCore

@MainActor enum FileClipboard {
    private struct Selection {
        let id = UUID()
        let board: NSPasteboard.Name
        let revision: Int
        let sources: [URL]
        let access: [DirectoryAccess]
        let cutting: Bool
        var isMoving = false
    }

    private static var selection: Selection?
    private static var ownershipTimer: Timer?

    static func write(_ sources: [URL], access: [DirectoryAccess] = [], to board: NSPasteboard, cutting: Bool = false) {
        guard !sources.isEmpty else { return }
        clearSelection()
        board.clearContents()
        guard board.writeObjects(sources.map { $0 as NSURL }) else { return }
        let owner = Selection(board: board.name, revision: board.changeCount, sources: sources, access: access, cutting: cutting)
        selection = owner
        // NSPasteboard has no change notification; observe only its revision while owning file access.
        if !access.isEmpty {
            let name = board.name.rawValue
            let id = owner.id
            let revision = owner.revision
            let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    guard selection?.id == id else { return }
                    if NSPasteboard(name: .init(name)).changeCount != revision { clearSelection() }
                }
            }
            ownershipTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private static func clearSelection() {
        selection = nil
        ownershipTimer?.invalidate()
        ownershipTimer = nil
    }

    private static func matchingSelection(_ sources: [URL], board: NSPasteboard, revision: Int) -> Selection? {
        guard let owner = selection else { return nil }
        guard owner.board == board.name, owner.revision == revision, owner.sources == sources else {
            clearSelection()
            return nil
        }
        return owner
    }

    static func sources(from board: NSPasteboard) -> [URL]? {
        guard let sources = FileDrop.sources(from: board) else { clearSelection(); return nil }
        let owner = matchingSelection(sources, board: board, revision: board.changeCount)
        return owner?.isMoving == true ? nil : sources
    }

    @discardableResult static func paste(from board: NSPasteboard, into browser: BrowserState,
                                        pane: PaneID, moving: Bool = false) -> Task<Void, Never>? {
        guard let incoming = FileDrop.capture(from: board) else { return nil }
        let owner = matchingSelection(incoming.sources, board: board, revision: incoming.revision)
        guard owner?.isMoving != true else { return nil }
        let cut = owner?.cutting == true ? owner : nil
        let operation: BrowserState.DropOperation = moving || cut != nil ? .move : .copy
        let access = incoming.access + (owner?.access ?? [])
        guard let task = browser.submitDrop(incoming.sources, into: pane, operation: operation, retaining: access, moveCompletion: { outcome in
            if let cut { finish(cut, outcome: outcome, board: board) }
        }) else { return nil }
        if let cut, selection?.id == cut.id { selection?.isMoving = true }
        return task
    }

    private static func finish(_ cut: Selection, outcome: ItemMove.Batch.Outcome?, board: NSPasteboard) {
        guard selection?.id == cut.id else { return }
        // A completed operation must never replace a newer clipboard selection.
        guard cut.board == board.name, cut.revision == board.changeCount else { clearSelection(); return }
        selection?.isMoving = false
        guard let outcome else { return }
        let relocated = Set(outcome.relocated.map(\.source))
        let remaining = cut.sources.filter { !relocated.contains($0) }
        if remaining.isEmpty {
            clearSelection()
            board.clearContents()
        } else if remaining != cut.sources {
            write(remaining, access: cut.access, to: board, cutting: true)
        }
    }
}
