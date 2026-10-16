import Foundation

public enum DirectorySortField: String, CaseIterable, Sendable {
    case name = "Name"
    case size = "Size"
    case lastModified = "Last Modified"
}

public enum DirectorySortDirection: Sendable {
    case ascending, descending
}

public struct DirectoryEntry: Identifiable, Sendable, Equatable {
    public let url: URL
    public let isDirectory: Bool
    public let isPackage: Bool
    public let isSymbolicLink: Bool
    public let isHidden: Bool
    public let modifiedDate: Date?
    /// Regular-file length from attributes; directories and unavailable values remain nil.
    public let size: UInt64?
    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    public init(url: URL, isDirectory: Bool, isPackage: Bool = false,
                isSymbolicLink: Bool = false, isHidden: Bool = false, modifiedDate: Date? = nil, size: UInt64? = nil) {
        self.url = url
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isSymbolicLink = isSymbolicLink
        self.isHidden = isHidden
        self.modifiedDate = modifiedDate
        self.size = size
    }

    func precedes(_ other: DirectoryEntry, field: DirectorySortField, direction: DirectorySortDirection) -> Bool {
        if field == .name, isDirectory != other.isDirectory { return isDirectory }
        if field == .lastModified {
            switch (modifiedDate, other.modifiedDate) {
            case let (left?, right?) where left != right:
                return direction == .ascending ? left < right : left > right
            case (nil, _?): return false
            case (_?, nil): return true
            default: break
            }
        }
        if field == .size {
            switch (size, other.size) {
            case let (left?, right?) where left != right:
                return direction == .ascending ? left < right : left > right
            case (nil, _?): return false
            case (_?, nil): return true
            default: break
            }
        }
        let order = name.localizedStandardCompare(other.name)
        if order == .orderedSame { return url.path < other.url.path }
        let ascending = field != .name || direction == .ascending
        return order == (ascending ? .orderedAscending : .orderedDescending)
    }
}

public struct DirectoryListing: Sendable {
    public let directory: URL
    public let entries: [DirectoryEntry]

    public init(directory: URL, entries: [DirectoryEntry]) {
        self.directory = directory
        self.entries = entries
    }

    /// Reads all immediate entries, including hidden items, and the canonical location off the UI thread.
    /// Entry order is unspecified; the pane applies its current sort settings.
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
                includingPropertiesForKeys: [.isPackageKey, .isHiddenKey], options: []
            )
            let entries = urls.map { url in
                var isFolder: ObjCBool = false
                _ = files.fileExists(atPath: url.path, isDirectory: &isFolder)
                let attributes = try? files.attributesOfItem(atPath: url.path)
                let isPackage = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
                let navigable = isFolder.boolValue && !isPackage
                return DirectoryEntry(
                    url: canonicalDirectory.appendingPathComponent(url.lastPathComponent, isDirectory: navigable),
                    isDirectory: navigable,
                    isPackage: isPackage,
                    isSymbolicLink: attributes?[.type] as? FileAttributeType == .typeSymbolicLink,
                    isHidden: url.lastPathComponent.hasPrefix(".")
                        || (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true,
                    modifiedDate: attributes?[.modificationDate] as? Date,
                    size: attributes?[.type] as? FileAttributeType == .typeRegular
                        ? (attributes?[.size] as? NSNumber)?.uint64Value : nil
                )
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
