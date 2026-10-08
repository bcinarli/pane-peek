import AppKit

enum PathClipboard {
    static func copy(_ paths: String) {
        guard !paths.isEmpty else { return }
        let clipboard = NSPasteboard.general
        clipboard.clearContents()
        clipboard.setString(paths, forType: .string)
    }
}
