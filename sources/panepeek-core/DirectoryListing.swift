import Foundation

public struct DirectoryEntry: Identifiable, Sendable, Equatable {
    public let url: URL
    public let isDirectory: Bool
    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }
}

public struct DirectoryListing: Sendable {
    public let directory: URL
    public let entries: [DirectoryEntry]

    public init(directory: URL, entries: [DirectoryEntry]) {
        self.directory = directory
        self.entries = entries
    }

    /// Reads a directory and its canonical location off the UI thread.
    public static func read(_ directory: URL) async throws -> DirectoryListing {
        try await Task.detached {
            let canonicalDirectory = directory.resolvingSymlinksInPath()
            let files = FileManager.default
            var isDirectory: ObjCBool = false
            let exists = files.fileExists(atPath: canonicalDirectory.path, isDirectory: &isDirectory)
            if !exists {
                throw CocoaError(.fileReadNoSuchFile)
            }
            let values = try canonicalDirectory.resourceValues(forKeys: [.isPackageKey])
            guard directory.isFileURL, isDirectory.boolValue, values.isPackage != true else {
                throw ListingError.notDirectory
            }
            let urls = try files.contentsOfDirectory(
                at: canonicalDirectory,
                includingPropertiesForKeys: [.isPackageKey], options: [.skipsHiddenFiles]
            )
            let entries = urls.map { url in
                var isFolder: ObjCBool = false
                _ = files.fileExists(atPath: url.path, isDirectory: &isFolder)
                let isPackage = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
                let navigable = isFolder.boolValue && !isPackage
                return DirectoryEntry(
                    url: canonicalDirectory.appendingPathComponent(url.lastPathComponent, isDirectory: navigable),
                    isDirectory: navigable
                )
            }.sorted { left, right in
                if left.isDirectory != right.isDirectory { return left.isDirectory }
                let order = left.name.localizedStandardCompare(right.name)
                if order == .orderedSame { return left.url.path < right.url.path }
                return order == .orderedAscending
            }
            return DirectoryListing(directory: canonicalDirectory, entries: entries)
        }.value
    }
}

private enum ListingError: LocalizedError {
    case notDirectory

    var errorDescription: String? {
        "Choose a directory. Files and macOS packages cannot be browsed."
    }
}
