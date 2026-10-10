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
    public var showHiddenFiles = false {
        didSet { setSelection(selectedItems) }
    }
    public private(set) var selectedItems: Set<URL> = []
    public private(set) var primaryItemURL: URL?
    public var primaryItem: DirectoryEntry? {
        allEntries.first { $0.url == primaryItemURL }
    }
    public private(set) var sortField: DirectorySortField = .name
    public private(set) var sortDirection: DirectorySortDirection = .ascending
    public private(set) var isLoading = false
    public private(set) var hasLoaded = false
    /// Changes after a successful listing publication, even when its entries are unchanged.
    public private(set) var listingRevision = UUID()
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
                let directoryChanged = self.directory != listing.directory
                self.directory = listing.directory
                allEntries = entries
                setSelection(directoryChanged ? [] : selectedItems)
                listingRevision = UUID()
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

    /// Keep visible URL identities, following an interacted row or retaining the current primary.
    public func setSelection(_ items: Set<URL>, focusedItem: URL? = nil) {
        let visibleEntries = entries
        let selection = items.intersection(visibleEntries.map(\.url))
        let added = selection.subtracting(selectedItems)
        if let focusedItem, selection.contains(focusedItem) {
            primaryItemURL = focusedItem
        } else if added.count == 1 {
            primaryItemURL = added.first
        } else if primaryItemURL.map(selection.contains) != true {
            primaryItemURL = visibleEntries.first { selection.contains($0.url) }?.url
        }
        selectedItems = selection
    }

    /// Select the visible listing without replacing an existing primary item.
    public func selectAll() {
        setSelection(Set(entries.map(\.url)), focusedItem: primaryItemURL)
    }

    /// Formats selected item paths in the pane's displayed order.
    public func copiedPaths(relative: Bool = false) -> String {
        let urls = entries.filter { selectedItems.contains($0.url) }.map(\.url)
        return CopiedPaths.string(for: urls, relativeTo: relative ? directory : nil)
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
    public var primaryItem: DirectoryEntry? { pane(focusedPane).primaryItem }
    public var detailsSelection: DetailsSelection? {
        guard let item = primaryItem else { return nil }
        return DetailsSelection(item: item, listingRevision: pane(focusedPane).listingRevision)
    }

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

    /// Capture the focused pane before scheduling the existing navigation path.
    @discardableResult public func openFavourite(_ directory: URL) -> Task<Void, Never> {
        let target = pane(focusedPane)
        return Task { await target.navigate(to: directory) }
    }

    /// Targets a context click, preserving an existing selection that contains the item.
    public func targetContextItem(_ url: URL, in id: PaneID) {
        let pane = pane(id)
        guard pane.entries.contains(where: { $0.url == url }) else { return }
        focus(id)
        pane.setSelection(pane.selectedItems.contains(url) ? pane.selectedItems : [url], focusedItem: url)
    }

}
