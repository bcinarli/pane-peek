import AppKit
import PanePeekCore

enum FileDrop {
    static func sources(from pasteboard: NSPasteboard) -> [URL]? {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }
        var sources: [URL] = []
        for item in items {
            guard let raw = item.string(forType: .fileURL), let url = URL(string: raw) else { return nil }
            sources.append(url)
        }
        return BrowserState.acceptsDropSources(sources) ? sources : nil
    }

    static func operation(allowed: NSDragOperation, modifiers: NSEvent.ModifierFlags) -> NSDragOperation {
        if modifiers.contains(.command), allowed.contains(.move) { return .move }
        return allowed.contains(.copy) ? .copy : []
    }
}
