import Foundation

struct DragSelection: Sendable {
    let pane: PaneID
    let entries: [DirectoryEntry]
    var sources: [URL] { entries.map(\.url) }

    func affects(_ url: URL) -> Bool {
        entries.contains {
            url.path == $0.url.path || (($0.isDirectory || $0.isPackage) && !$0.isSymbolicLink && url.path.hasPrefix($0.url.path + "/"))
        }
    }
}
