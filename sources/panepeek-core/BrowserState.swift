import Foundation
import Observation

public enum PaneID: Hashable, Sendable {
    case left, right
}

public enum BrowserMode: Hashable, Sendable {
    case onePane, twoPanes
}

@MainActor @Observable
public final class DirectoryPane {
    public private(set) var directory: URL
    private var allEntries: [DirectoryEntry] = []
    /// The current listing in sort order, filtered by this pane's visibility setting.
    public var entries: [DirectoryEntry] {
        showHiddenFiles ? allEntries : allEntries.filter { !$0.isHidden }
    }
    private var hiddenFiles = false
    public var showHiddenFiles: Bool {
        get { hiddenFiles }
        set {
            guard newValue != hiddenFiles else { return }
            let visible = newValue ? allEntries : allEntries.filter { !$0.isHidden }
            let selection = resolvedSelection(selectedItems, focusedItem: nil, visibleEntries: visible)
            let primary = visible.first { $0.url == selection.primary }
            guard approveChange?(primary, false, { [weak self] in self?.showHiddenFiles = newValue }) != false else { return }
            hiddenFiles = newValue
            selectedItems = selection.items
            primaryItemURL = selection.primary
        }
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
    private var requestedDirectory: URL
    private var sortRequestID = UUID()
    fileprivate var navigationSnapshot: (id: UUID, directory: URL) {
        (requestID, isLoading ? requestedDirectory : directory)
    }
    var approveChange: ((DirectoryEntry?, Bool, @escaping @MainActor () -> Void) -> Bool)?

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
        self.requestedDirectory = directory
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
        _ = await navigate(to: directory, selecting: nil)
    }

    /// Returns this read's failure; deferred or superseded reads return nil.
    fileprivate func navigate(to directory: URL, selecting createdItem: URL?) async -> String? {
        guard approveChange?(primaryItem, true, { [weak self] in
            Task { _ = await self?.navigate(to: directory, selecting: createdItem) }
        }) != false else { return nil }
        let request = UUID()
        requestID = request
        requestedDirectory = directory
        isLoading = true
        errorMessage = nil
        do {
            let listing = try await load(directory)
            guard requestID == request else { return nil }
            while true {
                let sorting = sortRequestID
                let entries = await sortEntries(listing.entries, sortField, sortDirection)
                guard requestID == request else { return nil }
                guard sortRequestID == sorting else { continue }
                let directoryChanged = self.directory != listing.directory
                let visible = showHiddenFiles ? entries : entries.filter { !$0.isHidden }
                let created = createdItem?.deletingLastPathComponent().path == listing.directory.path ? createdItem : nil
                let items = created.map { Set([$0]) } ?? (directoryChanged ? [] : selectedItems)
                let selection = resolvedSelection(items, focusedItem: created, visibleEntries: visible)
                let primary = visible.first { $0.url == selection.primary }
                guard approveChange?(primary, true, { [weak self] in
                    guard let self, self.requestID == request else { return }
                    Task { _ = await self.navigate(to: directory, selecting: createdItem) }
                }) != false else {
                    if requestID == request { isLoading = false }
                    return nil
                }
                guard requestID == request else { return nil }
                // Invalidate sorts of the previous listing before publishing the new one.
                sortRequestID = UUID()
                self.directory = listing.directory
                allEntries = entries
                selectedItems = selection.items
                primaryItemURL = selection.primary
                listingRevision = UUID()
                hasLoaded = true
                break
            }
        } catch {
            guard requestID == request else { return nil }
            errorMessage = "Couldn’t open \(directory.path). \(error.localizedDescription)"
            isLoading = false
            return errorMessage
        }
        isLoading = false
        return nil
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
    public func refresh(selecting createdItem: URL? = nil) async {
        _ = await navigate(to: directory, selecting: createdItem)
    }

    /// Keep visible URL identities, following an interacted row or retaining the current primary.
    @discardableResult public func setSelection(_ items: Set<URL>, focusedItem: URL? = nil) -> Bool {
        let visibleEntries = entries
        let selection = resolvedSelection(items, focusedItem: focusedItem, visibleEntries: visibleEntries)
        let primary = visibleEntries.first { $0.url == selection.primary }
        guard approveChange?(primary, false, { [weak self] in
            self?.setSelection(items, focusedItem: focusedItem)
        }) != false else { return false }
        selectedItems = selection.items
        primaryItemURL = selection.primary
        return true
    }

    func primaryItem(for items: Set<URL>, focusedItem: URL?) -> DirectoryEntry? {
        let selection = resolvedSelection(items, focusedItem: focusedItem, visibleEntries: entries)
        return entries.first { $0.url == selection.primary }
    }

    private func resolvedSelection(_ items: Set<URL>, focusedItem: URL?, visibleEntries: [DirectoryEntry]) -> (items: Set<URL>, primary: URL?) {
        let selection = items.intersection(visibleEntries.map(\.url))
        let added = selection.subtracting(selectedItems)
        let primary: URL?
        if let focusedItem, selection.contains(focusedItem) {
            primary = focusedItem
        } else if added.count == 1 {
            primary = added.first
        } else if primaryItemURL.map(selection.contains) != true {
            primary = visibleEntries.first { selection.contains($0.url) }?.url
        } else {
            primary = primaryItemURL
        }
        return (selection, primary)
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
    public enum UnsavedChoice: Sendable { case save, discard, cancel }
    public struct CreationRequest: Identifiable, Sendable {
        public let id = UUID()
        public let kind: ItemCreation.Kind
        public let pane: PaneID
        public let directory: URL
        fileprivate let navigationID: UUID
    }
    public private(set) var creationRequest: CreationRequest?
    public private(set) var isCreating = false
    public private(set) var creationError: String?
    private let createItem: @Sendable (ItemCreation.Kind, String, URL) async throws -> URL
    public let preview: PreviewState
    private let confirmChanges: @MainActor (String, @escaping @MainActor (UnsavedChoice) -> Void) -> Void
    private var pendingChangeID: UUID?
    public let left: DirectoryPane
    public let right: DirectoryPane
    public let homeDirectory: URL
    public private(set) var focusedPane: PaneID = .left
    public private(set) var mode: BrowserMode = .twoPanes
    public private(set) var presentationOrder: [PaneID] = [.left, .right]
    public var visiblePanes: [PaneID] {
        mode == .onePane ? [focusedPane] : presentationOrder
    }
    public var commandPane: DirectoryPane { pane(focusedPane) }

    /// Retain browser identities and the active document as their displayed sides change.
    public func setMode(_ mode: BrowserMode) {
        guard mode != self.mode else { return }
        if mode == .onePane {
            presentationOrder = [focusedPane, focusedPane == .left ? .right : .left]
        }
        self.mode = mode
    }

    /// A new other-pane request needs two visible browsers; callers capture the returned target.
    public func transferDestination(from source: PaneID) -> PaneID? {
        guard mode == .twoPanes else { return nil }
        return source == .left ? .right : .left
    }
    public var primaryItem: DirectoryEntry? { pane(focusedPane).primaryItem }
    public var detailsSelection: DetailsSelection? {
        guard let item = primaryItem else { return nil }
        return DetailsSelection(item: item, listingRevision: pane(focusedPane).listingRevision)
    }

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
                load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read,
                preview: PreviewState? = nil,
                create: @escaping @Sendable (ItemCreation.Kind, String, URL) async throws -> URL = {
                    try await ItemCreation.create($0, named: $1, in: $2)
                },
                confirmChanges: @escaping @MainActor (String, @escaping @MainActor (UnsavedChoice) -> Void) -> Void = { _, completion in completion(.cancel) }) {
        self.preview = preview ?? PreviewState()
        self.createItem = create
        self.confirmChanges = confirmChanges
        self.homeDirectory = homeDirectory
        left = DirectoryPane(directory: homeDirectory, load: load)
        right = DirectoryPane(directory: homeDirectory, load: load)
        for id in [PaneID.left, .right] {
            pane(id).approveChange = { [weak self] primary, reload, resume in
                guard let self else { return false }
                guard self.focusedPane == id else { return true }
                return (!reload && primary?.url == self.preview.selection?.item.url) || self.resolveChangesIfNeeded(resume: resume)
            }
        }
    }

    public func pane(_ id: PaneID) -> DirectoryPane {
        id == .left ? left : right
    }

    /// Capture the creating pane and resolve any draft before presenting its name prompt.
    public func beginCreation(_ kind: ItemCreation.Kind, in id: PaneID? = nil) {
        let id = id ?? focusedPane
        let target = pane(id)
        beginCreation(CreationRequest(kind: kind, pane: id, directory: target.directory,
                                      navigationID: target.navigationSnapshot.id))
    }

    private func beginCreation(_ request: CreationRequest) {
        guard !isCreating, creationRequest == nil, visiblePanes.contains(request.pane),
              pane(request.pane).navigationSnapshot.id == request.navigationID else { return }
        guard resolveChangesIfNeeded(resume: { [weak self] in self?.beginCreation(request) }) else { return }
        focusedPane = request.pane
        creationError = nil
        creationRequest = request
    }

    public func cancelCreation() { creationRequest = nil; creationError = nil }

    public func dismissCreationError() { creationError = nil }

    /// Submit once, then refresh only panes still showing the captured directory.
    public func submitCreation(named name: String) async {
        guard let request = creationRequest, !isCreating else { return }
        do { try ItemName.validate(name) } catch {
            creationError = error.localizedDescription
            return
        }
        creationRequest = nil
        creationError = nil
        guard visiblePanes.contains(request.pane), pane(request.pane).navigationSnapshot.id == request.navigationID,
              !preview.isDirty, !preview.isSaving else {
            creationError = "The creating pane or document changed. Open New Text File or New Folder again."
            return
        }
        isCreating = true
        defer { isCreating = false }
        let snapshots = [PaneID.left, .right].map { (pane: $0, navigation: pane($0).navigationSnapshot) }
        do {
            let created = try await createItem(request.kind, name, request.directory)
            let targets = await Task.detached(priority: .userInitiated) {
                snapshots.map { (pane: $0.pane, navigationID: $0.navigation.id,
                                 directory: $0.navigation.directory.resolvingSymlinksInPath()) }
            }.value
            var refreshErrors: [String] = []
            for snapshot in targets {
                let target = pane(snapshot.pane)
                guard target.navigationSnapshot.id == snapshot.navigationID,
                      snapshot.directory.path == created.deletingLastPathComponent().path else { continue }
                if snapshot.pane == request.pane, name.hasPrefix(".") { target.showHiddenFiles = true }
                if let error = await target.navigate(to: target.directory, selecting: snapshot.pane == request.pane ? created : nil) {
                    refreshErrors.append(error)
                }
            }
            if !refreshErrors.isEmpty {
                creationError = "Created \(created.path), but couldn’t refresh the listing. \(refreshErrors.joined(separator: "\n"))"
            }
        } catch {
            creationError = "Couldn’t create \(name) in \(request.directory.path). \(error.localizedDescription)"
        }
    }

    /// Focus a pane and complete its UI transition after any replaced draft is resolved.
    @discardableResult public func focus(_ id: PaneID, then: @escaping @MainActor () -> Void = {}) -> Bool {
        guard visiblePanes.contains(id) else { return false }
        guard id != focusedPane else { then(); return true }
        guard pane(id).primaryItem?.url == preview.selection?.item.url
                || resolveChangesIfNeeded(resume: { [weak self] in self?.focus(id, then: then) }) else { return false }
        focusedPane = id
        then()
        return true
    }

    /// Change selection and pane focus together, after resolving any replaced draft.
    @discardableResult public func select(_ items: Set<URL>, in id: PaneID, focusedItem: URL? = nil, then: @escaping @MainActor () -> Void = {}) -> Bool {
        guard visiblePanes.contains(id) else { return false }
        let target = pane(id)
        guard target.primaryItem(for: items, focusedItem: focusedItem)?.url == preview.selection?.item.url
                || resolveChangesIfNeeded(resume: { [weak self] in self?.select(items, in: id, focusedItem: focusedItem, then: then) }) else { return false }
        guard target.setSelection(items, focusedItem: focusedItem) else { return false }
        focusedPane = id
        then()
        return true
    }

    public func navigate(to directory: URL, in id: PaneID) async {
        guard visiblePanes.contains(id) else { return }
        guard resolveChangesIfNeeded(resume: { [weak self] in Task { await self?.navigate(to: directory, in: id) } }) else { return }
        focusedPane = id
        await pane(id).navigate(to: directory)
    }

    /// Resume the captured transition only after successful Save or explicit Discard.
    public func resolveChangesIfNeeded(resume: @escaping @MainActor () -> Void = {}) -> Bool {
        guard !preview.isSaving else { return false }
        guard preview.isDirty else { return true }
        guard pendingChangeID == nil else { return false }
        let decision = UUID()
        let document = preview.documentID
        pendingChangeID = decision
        confirmChanges(preview.selection?.item.name ?? "this file") { [weak self] choice in
            guard let self, self.pendingChangeID == decision else { return }
            guard self.preview.documentID == document else { self.pendingChangeID = nil; return }
            switch choice {
            case .cancel:
                self.pendingChangeID = nil
            case .discard:
                self.pendingChangeID = nil
                self.preview.discardChanges()
                resume()
            case .save:
                // Consume the sheet answer before awaiting I/O so a duplicate cannot submit again.
                let saving = UUID()
                self.pendingChangeID = saving
                Task {
                    let saved = await self.preview.save()
                    guard self.pendingChangeID == saving else { return }
                    self.pendingChangeID = nil
                    if saved, self.preview.documentID == document, !self.preview.isDirty { resume() }
                }
            }
        }
        return false
    }

    /// Capture the focused pane before scheduling the existing navigation path.
    @discardableResult public func openFavourite(_ directory: URL) -> Task<Void, Never> {
        let target = pane(focusedPane)
        return Task { await target.navigate(to: directory) }
    }

    /// Targets a context click, preserving an existing selection that contains the item.
    @discardableResult public func targetContextItem(_ url: URL, in id: PaneID, then: @escaping @MainActor () -> Void = {}) -> Bool {
        let pane = pane(id)
        guard pane.entries.contains(where: { $0.url == url }) else { return false }
        return select(pane.selectedItems.contains(url) ? pane.selectedItems : [url], in: id, focusedItem: url, then: then)
    }
}
