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
    public let access: DirectoryAccess?
    /// Immediate entries remain unread because this listing reached its entry budget.
    public let hasMoreEntries: Bool

    public init(directory: URL, entries: [DirectoryEntry], access: DirectoryAccess? = nil, hasMoreEntries: Bool = false) {
        self.directory = directory
        self.entries = entries
        self.access = access
        self.hasMoreEntries = hasMoreEntries
    }

    /// Reads all immediate entries, including hidden items, and the canonical location off the UI thread.
    /// Entry order is unspecified; the pane applies its current sort settings.
    public static func read(_ directory: URL) async throws -> DirectoryListing {
        try await read(directory, followingLinks: true)
    }

    /// Scoped browsing can omit target classification until a link is explicitly opened.
    public static func read(_ directory: URL, followingLinks: Bool) async throws -> DirectoryListing {
        try await read(directory, followingLinks: followingLinks, maximumEntries: nil)
    }

    static func read(_ directory: URL, followingLinks: Bool, maximumEntries: Int? = nil,
                     readAttributes: @escaping @Sendable (URL) throws -> [FileAttributeKey: Any] = {
                         try FileManager.default.attributesOfItem(atPath: $0.path)
                     }) async throws -> DirectoryListing {
        try Task.checkCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let canonicalDirectory = directory.resolvingSymlinksInPath()
            try Task.checkCancellation()
            let files = FileManager.default
            var isDirectory: ObjCBool = false
            let exists = files.fileExists(atPath: canonicalDirectory.path, isDirectory: &isDirectory)
            try Task.checkCancellation()
            if !exists {
                throw CocoaError(.fileReadNoSuchFile)
            }
            let values = try canonicalDirectory.resourceValues(forKeys: [.isPackageKey])
            try Task.checkCancellation()
            guard directory.isFileURL, isDirectory.boolValue, values.isPackage != true else {
                throw ListingError.notDirectory
            }
            var readError: Error?
            guard let urls = files.enumerator(
                at: canonicalDirectory,
                includingPropertiesForKeys: maximumEntries == nil && followingLinks ? [.isPackageKey, .isHiddenKey] : [],
                options: [.skipsSubdirectoryDescendants], errorHandler: { _, error in
                    readError = error
                    return false
                }
            ) else { throw CocoaError(.fileReadUnknown) }
            var entries: [DirectoryEntry] = []
            while true {
                try Task.checkCancellation()
                let next = urls.nextObject() as? URL
                try Task.checkCancellation()
                guard let url = next else { break }
                // The extra URL detects truncation without inspecting its metadata.
                if let maximumEntries, entries.count >= max(0, maximumEntries) {
                    return DirectoryListing(directory: canonicalDirectory, entries: entries, hasMoreEntries: true)
                }
                let entry = try autoreleasepool {
                    try entry(at: url, in: canonicalDirectory, followingLinks: followingLinks, readAttributes: readAttributes)
                }
                entries.append(entry)
            }
            if let readError { throw readError }
            return DirectoryListing(directory: canonicalDirectory, entries: entries)
        }
        return try await withTaskCancellationHandler {
            let listing = try await worker.value
            try Task.checkCancellation()
            return listing
        } onCancel: {
            worker.cancel()
        }
    }

    private static func entry(at url: URL, in directory: URL, followingLinks: Bool,
                              readAttributes: (URL) throws -> [FileAttributeKey: Any]) throws -> DirectoryEntry {
        let attributes = try? readAttributes(url)
        try Task.checkCancellation()
        let type = attributes?[.type] as? FileAttributeType
        let isLink = type == .typeSymbolicLink
        let inspectTarget = followingLinks || !isLink
        var isFolder = ObjCBool(type == .typeDirectory)
        if inspectTarget, type == nil || isLink {
            _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder)
            try Task.checkCancellation()
        }
        // Keep prefetched metadata on enumerated URLs; only links need target resolution.
        let packageURL = isLink && followingLinks ? url.resolvingSymlinksInPath() : url
        try Task.checkCancellation()
        let isPackage = inspectTarget
            && (try? packageURL.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
        try Task.checkCancellation()
        let hidden = url.lastPathComponent.hasPrefix(".")
            || (inspectTarget && (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true)
        try Task.checkCancellation()
        let navigable = isFolder.boolValue && !isPackage
        return DirectoryEntry(
            url: directory.appendingPathComponent(url.lastPathComponent, isDirectory: navigable),
            isDirectory: navigable, isPackage: isPackage, isSymbolicLink: isLink, isHidden: hidden,
            modifiedDate: attributes?[.modificationDate] as? Date,
            size: type == .typeRegular ? (attributes?[.size] as? NSNumber)?.uint64Value : nil
        )
    }
}

private enum ListingError: LocalizedError {
    case notDirectory

    var errorDescription: String? {
        "Choose a directory. Files and macOS packages cannot be browsed."
    }
}
