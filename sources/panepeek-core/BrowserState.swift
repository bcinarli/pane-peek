import Foundation
import Observation

public enum PaneID: Sendable {
    case left, right
}

@MainActor @Observable
public final class DirectoryPane {
    public private(set) var directory: URL
    private var allEntries: [DirectoryEntry] = []
    /// The current listing in sort order, filtered by this pane's visibility setting.
    public var entries: [DirectoryEntry] {
        showHiddenFiles ? allEntries : allEntries.filter { !$0.isHidden }
    }
    public var showHiddenFiles = false
    public private(set) var sortField: DirectorySortField = .name
    public private(set) var sortDirection: DirectorySortDirection = .ascending
    public private(set) var isLoading = false
    public private(set) var hasLoaded = false
    public private(set) var errorMessage: String?
    private let load: @Sendable (URL) async throws -> DirectoryListing
    private let sortEntries: @Sendable ([DirectoryEntry], DirectorySortField, DirectorySortDirection) async -> [DirectoryEntry]
    private var requestID = UUID()
    private var sortRequestID = UUID()

    public convenience init(directory: URL, load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read) {
        self.init(directory: directory, load: load, sortEntries: { entries, field, direction in
            await Task.detached(priority: .userInitiated) {
                entries.sorted { $0.precedes($1, field: field, direction: direction) }
            }.value
        })
    }

    init(directory: URL, load: @escaping @Sendable (URL) async throws -> DirectoryListing,
         sortEntries: @escaping @Sendable ([DirectoryEntry], DirectorySortField, DirectorySortDirection) async -> [DirectoryEntry]) {
        self.directory = directory
        self.load = load
        self.sortEntries = sortEntries
    }

    /// Root-to-current directories for the pane's displayed location.
    public var breadcrumbDirectories: [URL] {
        var current = directory
        var ancestors = [current]
        while current.path != "/" {
            current.deleteLastPathComponent()
            ancestors.append(current)
        }
        return ancestors.reversed()
    }

    public func navigate(to directory: URL) async {
        let request = UUID()
        requestID = request
        isLoading = true
        errorMessage = nil
        do {
            let listing = try await load(directory)
            guard requestID == request else { return }
            while true {
                let sorting = sortRequestID
                let entries = await sortEntries(listing.entries, sortField, sortDirection)
                guard requestID == request else { return }
                guard sortRequestID == sorting else { continue }
                // Invalidate sorts of the previous listing before publishing the new one.
                sortRequestID = UUID()
                self.directory = listing.directory
                allEntries = entries
                hasLoaded = true
                break
            }
        } catch {
            guard requestID == request else { return }
            errorMessage = "Couldn’t open \(directory.path). \(error.localizedDescription)"
        }
        isLoading = false
    }

    public func navigate(toPath path: String) async {
        guard path.hasPrefix("/") else {
            requestID = UUID()
            isLoading = false
            errorMessage = "Enter an absolute directory path starting with /."
            return
        }
        await navigate(to: URL(fileURLWithPath: path, isDirectory: true))
    }

    /// Rereads the displayed directory, retaining view settings and the last successful listing on failure.
    public func refresh() async {
        await navigate(to: directory)
    }

    /// Sort a snapshot off the UI thread, reversing an active column unless a direction is supplied.
    public func sort(by field: DirectorySortField, direction: DirectorySortDirection? = nil) async {
        if let direction {
            sortDirection = direction
        } else if sortField == field {
            sortDirection = sortDirection == .ascending ? .descending : .ascending
        } else {
            sortDirection = field == .name ? .ascending : .descending
        }
        sortField = field
        let request = UUID()
        sortRequestID = request
        let entries = await sortEntries(allEntries, field, sortDirection)
        guard sortRequestID == request else { return }
        allEntries = entries
    }
}

@MainActor @Observable
public final class BrowserState {
    public let left: DirectoryPane
    public let right: DirectoryPane
    public let homeDirectory: URL
    public private(set) var focusedPane: PaneID = .left

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
                load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read) {
        self.homeDirectory = homeDirectory
        left = DirectoryPane(directory: homeDirectory, load: load)
        right = DirectoryPane(directory: homeDirectory, load: load)
    }

    public func pane(_ id: PaneID) -> DirectoryPane {
        id == .left ? left : right
    }

    public func focus(_ id: PaneID) {
        focusedPane = id
    }

}
