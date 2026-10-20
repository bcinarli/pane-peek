import AppKit
import PanePeekCore

@MainActor enum FileDrop {
    struct Selection {
        let sources: [URL]
        let access: [DirectoryAccess]
        let revision: Int
    }

    private static func nativeSources(from board: NSPasteboard) -> [NSURL]? {
        let revision = board.changeCount
        guard let items = board.pasteboardItems, !items.isEmpty else { return nil }
        let declared = items.compactMap { item in item.string(forType: .fileURL).flatMap(URL.init(string:)) }
        guard declared.count == items.count, BrowserState.acceptsDropSources(declared),
              let native = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL],
              native.count == items.count, board.changeCount == revision else { return nil }
        let sources = native.map { $0 as URL }
        guard BrowserState.acceptsDropSources(sources), sources == declared else { return nil }
        return native
    }

    static func sources(from board: NSPasteboard) -> [URL]? {
        nativeSources(from: board)?.map { $0 as URL }
    }

    /// Native references and successful scope acquisitions outlive the pasteboard and receiving window.
    static func capture(from board: NSPasteboard,
                        start: @Sendable (NSURL) -> Bool = { $0.startAccessingSecurityScopedResource() },
                        stop: @escaping @Sendable (NSURL) -> Void = { $0.stopAccessingSecurityScopedResource() }) -> Selection? {
        let revision = board.changeCount
        guard let native = nativeSources(from: board), board.changeCount == revision else { return nil }
        let access = native.map { reference in
            let started = start(reference)
            return DirectoryAccess(root: reference as URL) {
                if started { stop(reference) }
                withExtendedLifetime(reference) {}
            }
        }
        guard board.changeCount == revision else { return nil }
        return Selection(sources: native.map { $0 as URL }, access: access, revision: revision)
    }

    static func operation(allowed: NSDragOperation, modifiers: NSEvent.ModifierFlags) -> NSDragOperation {
        if modifiers.contains(.command), allowed.contains(.move) { return .move }
        if allowed.contains(.copy) { return .copy }
        // AppKit may already have filtered the source mask before Command is sampled.
        return allowed.contains(.move) ? .move : []
    }
}
