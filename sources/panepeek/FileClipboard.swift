import AppKit
import PanePeekCore

@MainActor enum FileClipboard {
    private struct CutSelection {
        let id = UUID()
        let board: NSPasteboard.Name
        let revision: Int
        let sources: [URL]
        var isMoving = false
    }

    private static var pendingCut: CutSelection?

    static func write(_ sources: [URL], to board: NSPasteboard, cutting: Bool = false) {
        guard !sources.isEmpty else { return }
        pendingCut = nil
        board.clearContents()
        guard board.writeObjects(sources.map { $0 as NSURL }), cutting else { return }
        pendingCut = CutSelection(board: board.name, revision: board.changeCount, sources: sources)
    }

    static func sources(from board: NSPasteboard) -> [URL]? {
        guard let sources = FileDrop.sources(from: board) else { pendingCut = nil; return nil }
        guard let cut = pendingCut else { return sources }
        guard cut.board == board.name, cut.revision == board.changeCount, cut.sources == sources else {
            pendingCut = nil
            return sources
        }
        return cut.isMoving ? nil : sources
    }

    @discardableResult static func paste(from board: NSPasteboard, into browser: BrowserState,
                                        pane: PaneID, moving: Bool = false) -> Task<Void, Never>? {
        guard let sources = sources(from: board) else { return nil }
        let cut = pendingCut
        let operation: BrowserState.DropOperation = moving || cut != nil ? .move : .copy
        guard let task = browser.submitDrop(sources, into: pane, operation: operation, moveCompletion: { outcome in
            if let cut { finish(cut, outcome: outcome, board: board) }
        }) else { return nil }
        if let cut, pendingCut?.id == cut.id { pendingCut?.isMoving = true }
        return task
    }

    private static func finish(_ cut: CutSelection, outcome: ItemMove.Batch.Outcome?, board: NSPasteboard) {
        guard pendingCut?.id == cut.id else { return }
        // A completed operation must never replace a newer clipboard selection.
        guard cut.board == board.name, cut.revision == board.changeCount else { pendingCut = nil; return }
        pendingCut?.isMoving = false
        guard let outcome else { return }
        let relocated = Set(outcome.relocated.map(\.source))
        let remaining = cut.sources.filter { !relocated.contains($0) }
        if remaining.isEmpty {
            pendingCut = nil
            board.clearContents()
        } else if remaining != cut.sources {
            write(remaining, to: board, cutting: true)
        }
    }
}
