import Foundation

/// Searches names beneath one displayed directory without following file links.
public enum DirectorySearch {
    public struct Result: Sendable {
        public let entries: [DirectoryEntry]
        public let skippedDirectories: Int
        public let reachedLimit: Bool

        public init(entries: [DirectoryEntry], skippedDirectories: Int = 0, reachedLimit: Bool = false) {
            self.entries = entries
            self.skippedDirectories = skippedDirectories
            self.reachedLimit = reachedLimit
        }
    }

    /// Each loader receives the remaining visited-entry budget, including names that do not match.
    @concurrent public static func read(_ root: URL, query: String, showHidden: Bool,
                            load: (@Sendable (URL, Int) async throws -> DirectoryListing)? = nil,
                            maximumEntries: Int = 100_000) async throws -> Result {
        let maximumEntries = max(0, maximumEntries)
        let read = load ?? { try await DirectoryListing.read($0, followingLinks: false, maximumEntries: $1) }
        try Task.checkCancellation()
        let first = try await read(root, maximumEntries)
        let boundary = root.standardizedFileURL.path
        guard first.directory.standardizedFileURL.path == boundary else { throw CocoaError(.fileReadNoSuchFile) }
        var initial: DirectoryListing? = first
        var directories: [(url: URL, hidden: Bool)] = []
        var matches: [DirectoryEntry] = []
        var examined = 0
        var skipped = 0
        while initial != nil || !directories.isEmpty {
            try Task.checkCancellation()
            let listing: DirectoryListing
            let inheritedHidden: Bool
            if let ready = initial {
                initial = nil
                listing = ready
                inheritedHidden = false
            } else {
                guard examined < maximumEntries else {
                    return Result(entries: matches, skippedDirectories: skipped, reachedLimit: true)
                }
                let directory = directories.removeLast()
                inheritedHidden = directory.hidden
                do { listing = try await read(directory.url, maximumEntries - examined) }
                catch is CancellationError { throw CancellationError() }
                catch { skipped += 1; continue }
            }
            try Task.checkCancellation()
            // A directory replaced by a link during traversal cannot publish outside-root names.
            let path = listing.directory.standardizedFileURL.path
            guard path == boundary || path.hasPrefix(boundary == "/" ? "/" : boundary + "/") else {
                skipped += 1
                continue
            }
            for entry in listing.entries {
                try Task.checkCancellation()
                guard examined < maximumEntries else {
                    return Result(entries: matches, skippedDirectories: skipped, reachedLimit: true)
                }
                examined += 1
                guard showHidden || !entry.isHidden else { continue }
                if entry.name.range(of: query, options: .caseInsensitive) != nil || query.isEmpty {
                    matches.append(DirectoryEntry(url: entry.url, isDirectory: entry.isDirectory, isPackage: entry.isPackage,
                        isSymbolicLink: entry.isSymbolicLink, isHidden: inheritedHidden || entry.isHidden,
                        modifiedDate: entry.modifiedDate, size: entry.size))
                }
                if entry.isDirectory && !entry.isPackage && !entry.isSymbolicLink {
                    directories.append((entry.url, inheritedHidden || entry.isHidden))
                }
            }
            if listing.hasMoreEntries {
                return Result(entries: matches, skippedDirectories: skipped, reachedLimit: true)
            }
            await Task.yield()
        }
        return Result(entries: matches, skippedDirectories: skipped)
    }
}
