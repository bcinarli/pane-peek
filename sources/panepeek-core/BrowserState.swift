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
    public private(set) var recoveryMessage: String?
    private let load: @Sendable (URL) async throws -> DirectoryListing
    private let sortEntries: @Sendable ([DirectoryEntry], DirectorySortField, DirectorySortDirection) async -> [DirectoryEntry]
    private var requestID = UUID()
    public private(set) var directoryAccess: DirectoryAccess?
    private let resolveBeforeLoading: Bool
    private let loadHistory: (@Sendable (URL) async throws -> DirectoryListing)?
    private var history: [URL] = []
    private var historyPosition = 0
    private var historyRevision = UUID()
    fileprivate enum NavigationIntent {
        case visit, reload
        case history(position: Int, revision: UUID)
    }
    public var navigationRevision: UUID { requestID }
    private var requestedDirectory: URL
    private var sortRequestID = UUID()
    fileprivate var navigationSnapshot: (id: UUID, directory: URL) {
        (requestID, isLoading ? requestedDirectory : directory)
    }
    var approveChange: ((DirectoryEntry?, Bool, @escaping @MainActor () -> Void) -> Bool)?

    public convenience init(directory: URL, resolveBeforeLoading: Bool = true, load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read,
                            loadHistory: (@Sendable (URL) async throws -> DirectoryListing)? = nil) {
        self.init(directory: directory, load: load, sortEntries: { entries, field, direction in
            await Task.detached(priority: .userInitiated) {
                entries.sorted { $0.precedes($1, field: field, direction: direction) }
            }.value
        }, resolveBeforeLoading: resolveBeforeLoading, loadHistory: loadHistory)
    }

    init(directory: URL, load: @escaping @Sendable (URL) async throws -> DirectoryListing,
         sortEntries: @escaping @Sendable ([DirectoryEntry], DirectorySortField, DirectorySortDirection) async -> [DirectoryEntry],
         resolveBeforeLoading: Bool = true, loadHistory: (@Sendable (URL) async throws -> DirectoryListing)? = nil) {
        self.directory = directory
        self.requestedDirectory = directory
        self.load = load
        self.sortEntries = sortEntries
        self.resolveBeforeLoading = resolveBeforeLoading
        self.loadHistory = loadHistory
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

    public var canGoBack: Bool { historyPosition > 0 }
    public var canGoForward: Bool { historyPosition + 1 < history.count }

    public func goBack() async {
        guard let navigate = historyNavigation(forward: false) else { return }
        await navigate()
    }

    public func goForward() async {
        guard let navigate = historyNavigation(forward: true) else { return }
        await navigate()
    }

    fileprivate func historyNavigation(forward: Bool) -> (@MainActor () async -> Void)? {
        let position = historyPosition + (forward ? 1 : -1)
        guard history.indices.contains(position) else { return nil }
        let directory = history[position]
        let intent = NavigationIntent.history(position: position, revision: historyRevision)
        return { [weak self] in
            guard let self else { return }
            _ = await self.navigate(to: directory, selecting: nil, intent: intent, using: self.loadHistory)
        }
    }

    private func accepts(_ intent: NavigationIntent) -> Bool {
        if case let .history(position, revision) = intent {
            return historyRevision == revision && history.indices.contains(position)
        }
        return true
    }

    private func publishHistory(_ directory: URL, intent: NavigationIntent) {
        if history.isEmpty {
            history = [directory]
            historyPosition = 0
        } else {
            switch intent {
            case .visit:
                guard history[historyPosition].path != directory.path else { return }
                history.removeSubrange((historyPosition + 1)..<history.count)
                history.append(directory)
                historyPosition = history.count - 1
            case .reload:
                guard history[historyPosition].path != directory.path else { return }
                history[historyPosition] = directory
                return
            case let .history(position, _):
                historyPosition = position
                history[position] = directory
            }
        }
        historyRevision = UUID()
    }

    public func navigate(to directory: URL) async {
        _ = await navigate(to: directory, selecting: nil)
    }

    /// Return true only when this request publishes a listing through the supplied access loader.
    @discardableResult public func navigate(to directory: URL, using loader: @escaping @Sendable (URL) async throws -> DirectoryListing) async -> Bool {
        let request = UUID()
        let previous = listingRevision
        _ = await navigate(to: directory, selecting: nil, request: request, using: loader)
        return requestID == request && listingRevision != previous
    }

    /// Restore a granted location without replacing an unavailable saved directory with Home.
    fileprivate func restoreAccess(to directory: URL, load: @escaping @Sendable (URL) async throws -> DirectoryListing) async {
        guard !hasLoaded else { return }
        self.directory = directory
        _ = await navigate(to: directory, selecting: nil, intent: .reload, using: load)
    }

    fileprivate func restore(to directory: URL, home: URL) async -> String? {
        guard let failure = await navigate(to: directory, selecting: nil, intent: .reload) else { return nil }
        guard directory.path != home.path else { return failure }
        let fallback = UUID()
        let homeFailure = await navigate(to: home, selecting: nil, request: fallback, intent: .reload)
        guard requestID == fallback else { return nil }
        let message = failure + " " + (homeFailure ?? "Browsing \(self.directory.path) instead.")
        return message
    }

    /// Returns this read's failure; deferred or superseded reads return nil.
    fileprivate func navigate(to directory: URL, selecting createdItem: URL?, preservingDocument: Bool = false, request: UUID = UUID(),
                              intent: NavigationIntent = .visit,
                              using loader: (@Sendable (URL) async throws -> DirectoryListing)? = nil) async -> String? {
        guard accepts(intent) else { return nil }
        let previousRequest = requestID
        guard approveChange?(primaryItem, !preservingDocument, { [weak self] in
            guard let self, self.requestID == previousRequest else { return }
            Task { _ = await self.navigate(to: directory, selecting: createdItem, preservingDocument: preservingDocument, intent: intent, using: loader) }
        }) != false else { return nil }
        requestID = request
        requestedDirectory = directory
        isLoading = true
        errorMessage = nil
        recoveryMessage = nil
        do {
            if resolveBeforeLoading {
                let canonical = await Task.detached(priority: .userInitiated) { directory.resolvingSymlinksInPath() }.value
                guard requestID == request else { return nil }
                requestedDirectory = canonical
            }
            let read = loader ?? load
            let listing = try await read(directory)
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
                guard approveChange?(primary, !preservingDocument, { [weak self] in
                    guard let self, self.requestID == request else { return }
                    Task { _ = await self.navigate(to: directory, selecting: createdItem, preservingDocument: preservingDocument, intent: intent, using: loader) }
                }) != false else {
                    if requestID == request { isLoading = false }
                    return nil
                }
                guard requestID == request, accepts(intent) else {
                    if requestID == request { isLoading = false }
                    return nil
                }
                // Invalidate sorts of the previous listing before publishing the new one.
                sortRequestID = UUID()
                self.directory = listing.directory
                publishHistory(listing.directory, intent: intent)
                directoryAccess = listing.access
                allEntries = entries
                selectedItems = selection.items
                primaryItemURL = selection.primary
                listingRevision = UUID()
                hasLoaded = true
                break
            }
        } catch is CancellationError {
            if requestID == request { isLoading = false }
            return nil
        } catch {
            guard requestID == request else { return nil }
            errorMessage = "Couldn’t open \(directory.path). \(error.localizedDescription)"
            isLoading = false
            return errorMessage
        }
        isLoading = false
        return nil
    }

    /// Invalidates pending readers and releases the scope of a detached pane.
    public func releaseAccess() {
        requestID = UUID()
        isLoading = false
        directoryAccess = nil
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
        _ = await navigate(to: directory, selecting: createdItem, intent: .reload)
    }

    /// Keep the last usable listing at its new path, even if a subsequent refresh fails.
    fileprivate func applyRename(_ operation: ItemRename, to destination: URL,
                                 isHidden: Bool) -> (navigation: UUID, refreshDirectory: URL?)? {
        let intended = navigationSnapshot.directory
        let refresh = intended.path == operation.source.deletingLastPathComponent().path || operation.affects(intended)
        let directoryChanged = operation.affects(directory)
        if directoryChanged {
            directory = operation.relocated(directory, to: destination)
            publishHistory(directory, intent: .reload)
        }
        if isLoading, operation.affects(requestedDirectory) {
            requestID = UUID()
            requestedDirectory = operation.relocated(requestedDirectory, to: destination)
        }
        let entriesChanged = directoryChanged || allEntries.contains(where: { operation.affects($0.url) })
        if entriesChanged {
            sortRequestID = UUID()
            allEntries = allEntries.map { entry in
                let url = operation.relocated(entry.url, to: destination)
                return DirectoryEntry(url: url, isDirectory: entry.isDirectory, isPackage: entry.isPackage,
                                      isSymbolicLink: entry.isSymbolicLink,
                                      isHidden: entry.url.path == operation.source.path ? isHidden : entry.isHidden,
                                      modifiedDate: entry.modifiedDate, size: entry.size)
            }
            let items = Set(selectedItems.map { operation.relocated($0, to: destination) })
            let primary = primaryItemURL.map { operation.relocated($0, to: destination) }
            let selection = resolvedSelection(items, focusedItem: primary, visibleEntries: entries)
            selectedItems = selection.items
            primaryItemURL = selection.primary
            listingRevision = UUID()
        }
        guard entriesChanged || refresh else { return nil }
        return (navigationSnapshot.id, refresh ? navigationSnapshot.directory : nil)
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

    /// Remove obsolete rows and follow moved descendants before a fallible refresh.
    fileprivate func applyMove(_ operation: ItemMove, entry moved: DirectoryEntry) -> (navigation: UUID, refreshDirectory: URL?)? {
        let intended = navigationSnapshot.directory
        let sourceParent = operation.source.deletingLastPathComponent().path
        let destinationParent = operation.destination.deletingLastPathComponent().path
        let refresh = [sourceParent, destinationParent].contains(intended.path) || operation.affects(intended)
        let directoryChanged = operation.affects(directory)
        if directoryChanged {
            directory = operation.relocated(directory)
            publishHistory(directory, intent: .reload)
        }
        if isLoading, refresh {
            requestID = UUID()
            requestedDirectory = operation.relocated(requestedDirectory)
        }
        let removed = allEntries.contains { operation.affects($0.url) }
        let receiving = directory.path == destinationParent
        if directoryChanged || removed || receiving {
            sortRequestID = UUID()
            if directoryChanged {
                allEntries = allEntries.map { entry in
                    DirectoryEntry(url: operation.relocated(entry.url), isDirectory: entry.isDirectory, isPackage: entry.isPackage,
                                   isSymbolicLink: entry.isSymbolicLink, isHidden: entry.isHidden, modifiedDate: entry.modifiedDate, size: entry.size)
                }
            } else {
                allEntries.removeAll { operation.affects($0.url) }
            }
            if receiving, !allEntries.contains(where: { $0.url == moved.url }) { allEntries.append(moved) }
            let items = directoryChanged ? Set(selectedItems.map(operation.relocated)) : selectedItems
            let primary = directoryChanged ? primaryItemURL.map(operation.relocated) : primaryItemURL
            let selection = resolvedSelection(items, focusedItem: primary, visibleEntries: entries)
            selectedItems = selection.items
            primaryItemURL = selection.primary
            listingRevision = UUID()
        }
        guard directoryChanged || removed || receiving || refresh else { return nil }
        return (navigationSnapshot.id, refresh ? navigationSnapshot.directory : nil)
    }

    /// Prune obsolete paths before refresh, retaining any newer unrelated navigation.
    fileprivate func applyTrash(_ operation: ItemTrash) -> (navigation: UUID, directory: URL?, recovering: Bool, fallback: Bool)? {
        let intended = navigationSnapshot.directory
        let parent = operation.source.deletingLastPathComponent()
        let recovering = operation.affects(intended)
        let refresh = recovering || intended.path == parent.path
        let directoryChanged = operation.affects(directory)
        let removed = allEntries.contains { operation.affects($0.url) }
        if directoryChanged {
            directory = parent
            publishHistory(directory, intent: .reload)
            allEntries = []
        } else { allEntries.removeAll { operation.affects($0.url) } }
        if isLoading, refresh {
            requestID = UUID()
            requestedDirectory = recovering ? parent : intended
            isLoading = false
        }
        if directoryChanged || removed {
            sortRequestID = UUID()
            let selection = resolvedSelection(selectedItems, focusedItem: primaryItemURL, visibleEntries: entries)
            selectedItems = selection.items
            primaryItemURL = selection.primary
            listingRevision = UUID()
        }
        guard directoryChanged || removed || refresh else { return nil }
        return (navigationSnapshot.id, refresh ? (recovering ? parent : intended) : nil, recovering, directoryChanged && !refresh)
    }

    /// Load a usable fallback without superseding a newer unrelated navigation request.
    fileprivate func recoverTrashFallback(from parent: URL, navigation: UUID) async -> [String] {
        var candidate = parent
        var messages: [String] = []
        while true {
            do {
                let listing = try await load(candidate)
                while true {
                    let sorting = sortRequestID
                    let sorted = await sortEntries(listing.entries, sortField, sortDirection)
                    guard requestID == navigation, directory.path == parent.path else { return messages }
                    guard sorting == sortRequestID else { continue }
                    sortRequestID = UUID()
                    directory = listing.directory
                    publishHistory(directory, intent: .reload)
                    allEntries = sorted
                    hasLoaded = true
                    listingRevision = UUID()
                    messages.append("The browsed folder was trashed. Browsing \(directory.path) instead.")
                    explainTrashRecovery()
                    return messages
                }
            } catch {
                guard requestID == navigation, directory.path == parent.path else { return messages }
                messages.append("Couldn’t refresh the listing. Couldn’t open \(candidate.path). \(error.localizedDescription)")
                guard candidate.path != "/" else { return messages }
                candidate.deleteLastPathComponent()
            }
        }
    }

    fileprivate func explainTrashRecovery() {
        recoveryMessage = "The browsed folder was trashed. Browsing \(directory.path) instead."
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
    public let operations: FileOperationCoordinator
    public enum UnsavedChoice: Sendable { case save, discard, cancel }
    public struct RenameRequest: Identifiable, Sendable {
        public let id = UUID()
        public let pane: PaneID
        public let item: DirectoryEntry
        public let operation: ItemRename
        fileprivate let navigationID: UUID
        fileprivate let access: [DirectoryAccess]
    }
    public private(set) var renameRequest: RenameRequest?
    public private(set) var renameName = ""
    public private(set) var isRenaming = false
    public private(set) var renameError: String?
    private let renameItem: @Sendable (ItemRename, String) async throws -> URL
    private var renameSubmission: (name: String, task: Task<URL?, Never>)?
    private var renameTransitionID: UUID?
    public struct CreationRequest: Identifiable, Sendable {
        public let id = UUID()
        public let kind: ItemCreation.Kind
        public let pane: PaneID
        public let directory: URL
        fileprivate let navigationID: UUID
        fileprivate var access: [DirectoryAccess] = []
    }
    private var creationPermissionID: UUID?
    public private(set) var creationRequest: CreationRequest?
    public private(set) var isCreating = false
    public private(set) var creationError: String?
    private let createItem: @Sendable (ItemCreation.Kind, String, URL) async throws -> URL
    public private(set) var isCopying = false
    public private(set) var copyOutcome: ItemCopy.Outcome?
    private let copyItem: @Sendable (ItemCopy) async -> ItemCopy.Outcome
    public private(set) var isMoving = false
    public private(set) var moveOutcome: ItemMove.Batch.Outcome?
    private let resolveTransferCollision: @MainActor (ItemMove.Collision, @escaping @MainActor (ItemMove.CollisionChoice) -> Void) -> Void
    private let moveItem: @Sendable (ItemMove) async -> ItemMove.Outcome
    public private(set) var isTrashing = false
    public private(set) var trashOutcome: ItemTrash.Batch.Outcome?
    private let trashItem: @Sendable (ItemTrash) async -> ItemTrash.Outcome
    public let notifications = OperationNotifications()
    public let preview: PreviewState
    private let confirmChanges: @MainActor (String, @escaping @MainActor (UnsavedChoice) -> Void) -> Void
    private var pendingChangeID: UUID?
    public let left: DirectoryPane
    public let right: DirectoryPane
    public let requiresFolderAccess: Bool
    private let acquireOperationAccess: (@MainActor (URL, DirectoryAccess.Mode) async throws -> DirectoryAccess?)?
    public let homeDirectory: URL
    public enum StartupState { case pending, loading, ready }
    public private(set) var startupState: StartupState = .pending
    public private(set) var restorationMessage: String? {
        didSet { if let restorationMessage { notifications.post(restorationMessage, kind: .error) } }
    }
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
        let pane = pane(focusedPane)
        guard let item = primaryItem, !requiresFolderAccess || pane.directoryAccess != nil else { return nil }
        return DetailsSelection(item: item, listingRevision: pane.listingRevision, access: pane.directoryAccess)
    }

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
                requiresFolderAccess: Bool = false,
                acquireOperationAccess: (@MainActor (URL, DirectoryAccess.Mode) async throws -> DirectoryAccess?)? = nil,
                load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read,
                loadHistory: (@Sendable (URL) async throws -> DirectoryListing)? = nil,
                operations: FileOperationCoordinator? = nil,
                preview: PreviewState? = nil,
                create: (@Sendable (ItemCreation.Kind, String, URL) async throws -> URL)? = nil,
                rename: (@Sendable (ItemRename, String) async throws -> URL)? = nil,
                copy: (@Sendable (ItemCopy) async -> ItemCopy.Outcome)? = nil,
                move: (@Sendable (ItemMove) async -> ItemMove.Outcome)? = nil,
                resolveTransferCollision: @escaping @MainActor (ItemMove.Collision, @escaping @MainActor (ItemMove.CollisionChoice) -> Void) -> Void = { _, answer in answer(.cancel) },
                trash: (@Sendable (ItemTrash) async -> ItemTrash.Outcome)? = nil,
                confirmChanges: @escaping @MainActor (String, @escaping @MainActor (UnsavedChoice) -> Void) -> Void = { _, completion in completion(.cancel) }) {
        self.requiresFolderAccess = requiresFolderAccess
        self.acquireOperationAccess = acquireOperationAccess
        self.preview = preview ?? PreviewState(readOnly: requiresFolderAccess)
        self.operations = operations ?? FileOperationCoordinator()
        self.preview.operations = self.operations
        self.createItem = create ?? { try await ItemCreation.create($0, named: $1, in: $2) }
        self.renameItem = rename ?? { try await $0.rename(to: $1) }
        self.copyItem = copy ?? { await $0.copy() }
        self.moveItem = move ?? { await $0.move() }
        self.resolveTransferCollision = resolveTransferCollision
        self.trashItem = trash ?? { await $0.trash() }
        self.confirmChanges = confirmChanges
        self.homeDirectory = homeDirectory
        left = DirectoryPane(directory: homeDirectory, resolveBeforeLoading: !requiresFolderAccess, load: load, loadHistory: loadHistory)
        right = DirectoryPane(directory: homeDirectory, resolveBeforeLoading: !requiresFolderAccess, load: load, loadHistory: loadHistory)
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

    /// Start each retained window once; later view updates must not reset its navigation.
    public func start(leftDirectory: URL, rightDirectory: URL, mode: BrowserMode, order: [PaneID], active: PaneID,
                      restoreAccess: (@Sendable (URL) async throws -> DirectoryListing)? = nil) async {
        guard startupState == .pending else { return }
        startupState = .loading
        presentationOrder = order.count == 2 && Set(order).count == 2 ? order : [.left, .right]
        focusedPane = mode == .onePane ? presentationOrder[0] : active
        self.mode = mode
        if requiresFolderAccess {
            if let restoreAccess {
                async let leftRestore: Void = left.restoreAccess(to: leftDirectory, load: restoreAccess)
                async let rightRestore: Void = right.restoreAccess(to: rightDirectory, load: restoreAccess)
                _ = await (leftRestore, rightRestore)
            }
            startupState = .ready
            return
        }
        async let leftMessage = left.restore(to: leftDirectory, home: homeDirectory)
        async let rightMessage = right.restore(to: rightDirectory, home: homeDirectory)
        let messages = await [leftMessage, rightMessage].compactMap { $0 }
        restorationMessage = messages.isEmpty ? nil : messages.joined(separator: "\n")
        startupState = .ready
    }

    public func dismissRestorationMessage() { restorationMessage = nil }

    public func canMove(in id: PaneID) -> Bool { canCopy(in: id) }

    public enum DropOperation: Sendable { case copy, move }

    public struct DragNotice: Identifiable {
        public let id = UUID()
        public let message: String
    }
    public private(set) var dragNotice: DragNotice? {
        didSet {
            if let dragNotificationID { notifications.dismiss(dragNotificationID) }
            dragNotificationID = dragNotice.map { notifications.post($0.message, kind: .information) }
        }
    }
    private var dragNotificationID: UUID?
    private var draggedItems: DragSelection?
    private var nativeDragID: UUID?
    var holdsNativeDrag: Bool { nativeDragID != nil && nativeDragID == draggedItems?.id }
    private var dragReceivedHere = false
    public var isDragging: Bool { draggedItems != nil }
    public var draggedSources: [URL] { draggedItems?.sources ?? [] }

    /// Export only the accepted selection; resolving a draft requires a fresh native drag gesture.
    public func beginDrag(in id: PaneID, items expectedItems: Set<URL>) -> [URL]? {
        if let draggedItems {
            return draggedItems.pane == id && expectedItems == Set(draggedItems.sources) ? draggedItems.sources : nil
        }
        guard canReceiveDrop(into: id), expectedItems == pane(id).selectedItems else { return nil }
        let selection = DragSelection(access: pane(id).directoryAccess, pane: id, entries: pane(id).entries.filter { expectedItems.contains($0.url) })
        guard Self.acceptsDropSources(selection.sources) else { return nil }
        operations.register(self)
        if operations.hasDirtyDocuments(affecting: selection.affects) {
            guard let reservation = operations.beginOperation(for: self) else { return nil }
            operations.lockPreviews(affecting: selection.affects)
            dragNotice = DragNotice(message: "Drag not started. Resolve the unsaved changes, then drag again.")
            Task {
                defer { operations.endOperation(reservation) }
                guard let resolution = await operations.resolveChanges() else { return }
                resolution.discardChanges()
                dragNotice = DragNotice(message: "Changes resolved. Drag the selected items again to start the transfer.")
            }
            return nil
        }
        guard operations.beginDrag(selection, from: self) else { return nil }
        copyOutcome = nil
        moveOutcome = nil
        trashOutcome = nil
        dragNotice = nil
        draggedItems = selection
        dragReceivedHere = false
        return selection.sources
    }

    /// Give the native session its own scope consumer, independently of its window.
    public func retainDragAccess() -> DirectoryAccess? {
        guard let selection = draggedItems, let access = selection.access else { return nil }
        nativeDragID = selection.id
        let id = selection.id
        return DirectoryAccess(root: access.root, mode: access.mode) { [self] in
            withExtendedLifetime(access) {}
            Task { @MainActor in
                if self.draggedItems?.id == id { self.endDrag() }
            }
        }
    }

    public func endDrag(external: Bool = false) {
        guard isDragging else { return }
        if external && !dragReceivedHere {
            dragNotice = DragNotice(message: "Drag handed to Finder or another app. Use Refresh to see any filesystem changes.")
        }
        operations.endDrag(from: self)
        draggedItems = nil
        nativeDragID = nil
        dragReceivedHere = false
    }
    func receiveDrag() { dragReceivedHere = true }
    public func dismissDragNotice() { dragNotice = nil }

    private func permitsFileOperations(in id: PaneID) -> Bool {
        !requiresFolderAccess || (acquireOperationAccess != nil && pane(id).hasLoaded && pane(id).directoryAccess != nil)
    }

    private func canStartTransfer(in id: PaneID) -> Bool {
        permitsFileOperations(in: id) && visiblePanes.contains(id) && !operations.isBusy && !isCopying && !isMoving && !isTrashing && !isCreating && !isRenaming
            && creationRequest == nil && renameRequest == nil && renameSubmission == nil
            && !preview.isSaving && pendingChangeID == nil
    }

    public func canReceiveDrop(into id: PaneID, sources: [URL]? = nil) -> Bool {
        canStartTransfer(in: id) && (sources.map(operations.acceptsDrop) ?? true)
    }

    private func accessForOperation(_ directories: [URL], requiring mode: DirectoryAccess.Mode) async throws -> [DirectoryAccess] {
        guard requiresFolderAccess else { return [] }
        guard let acquireOperationAccess else { throw CocoaError(.fileWriteNoPermission) }
        var access: [DirectoryAccess] = []
        var requested: Set<String> = []
        for directory in directories where requested.insert(directory.standardized.path).inserted {
            try Task.checkCancellation()
            guard let grant = try await acquireOperationAccess(directory, mode) else { throw CancellationError() }
            try Task.checkCancellation()
            guard directory.standardized.pathComponents.starts(with: grant.root.standardized.pathComponents),
                  mode == .readOnly || grant.mode == .readWrite else { throw CocoaError(.fileWriteNoPermission) }
            access.append(grant)
        }
        return access
    }

    private func sourceAccessForTransfer(_ sources: [URL], requiring mode: DirectoryAccess.Mode) async throws -> [DirectoryAccess] {
        guard requiresFolderAccess else { return [] }
        let identities = try await Task.detached(priority: .userInitiated) {
            try sources.map { try ItemCopy.Identity.read($0) }
        }.value
        let access = try await accessForOperation(sources.map { $0.deletingLastPathComponent() }, requiring: mode)
        defer { withExtendedLifetime(access) {} }
        try Task.checkCancellation()
        try await Task.detached(priority: .userInitiated) {
            for (source, identity) in zip(sources, identities) {
                guard try ItemCopy.Identity.read(source) == identity else {
                    throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey:
                        "The selected source changed. Select the files again before transferring."])
                }
            }
        }.value
        return access
    }

    nonisolated public static func acceptsDropSources(_ sources: [URL]) -> Bool {
        !sources.isEmpty && sources.allSatisfy { url in
            let host = url.host ?? ""
            return url.isFileURL && (host.isEmpty || host.lowercased() == "localhost")
                && url.user == nil && url.password == nil && url.port == nil
                && url.query == nil && url.fragment == nil && url.path.hasPrefix("/")
        } && Set(sources.map { $0.standardizedFileURL.path }).count == sources.count
    }

    /// Reserve the operation and capture its destination before returning to the drag event loop.
    /// Move completion receives the actual outcome, or nil when cancelled before mutation.
    @discardableResult public func submitDrop(_ sources: [URL], into id: PaneID, operation: DropOperation,
                                            retaining sourceAccess: [DirectoryAccess] = [],
                                            moveCompletion: (@MainActor (ItemMove.Batch.Outcome?) -> Void)? = nil) -> Task<Void, Never>? {
        guard canReceiveDrop(into: id, sources: sources), Self.acceptsDropSources(sources), let reservation = operations.beginOperation(for: self, receiving: sources) else { return nil }
        let directory = pane(id).directory
        let access = sourceAccess + [pane(id).directoryAccess, operations.dragAccess].compactMap { $0 }
        dragNotice = nil
        switch operation {
        case .copy:
            isCopying = true
            return Task {
                defer { withExtendedLifetime(access) {} }
                _ = await performCopy(sources, to: directory, reservation: reservation)
            }
        case .move:
            isMoving = true
            return Task {
                defer { withExtendedLifetime(access) {} }
                let outcome = await performMove(sources, to: directory, entries: [], reservation: reservation)
                moveCompletion?(outcome)
            }
        }
    }

    public func canTrash(in id: PaneID? = nil) -> Bool {
        let id = id ?? focusedPane
        return permitsFileOperations(in: id) && visiblePanes.contains(id) && operations.canMutate && !pane(id).selectedItems.isEmpty && pane(id).primaryItem != nil
            && !isDragging && !isTrashing && !isRenaming && !isCreating && !isCopying && !isMoving && renameSubmission == nil
            && renameRequest == nil && creationRequest == nil && !preview.isSaving && pendingChangeID == nil
    }

    /// Capture the displayed selection before confirmation; later changes cannot redirect it.
    @discardableResult public func moveToTrash(from id: PaneID? = nil, items expectedItems: Set<URL>? = nil) async -> ItemTrash.Batch.Outcome? {
        let id = id ?? focusedPane
        guard canTrash(in: id), expectedItems == nil || expectedItems == pane(id).selectedItems else { return nil }
        let entries = pane(id).entries.filter { pane(id).selectedItems.contains($0.url) }
        let sources = entries.map(\.url)
        var access = [pane(id).directoryAccess].compactMap { $0 }
        defer { withExtendedLifetime(access) {} }
        guard let reservation = operations.beginOperation(for: self) else { return nil }
        defer { operations.endOperation(reservation) }
        isTrashing = true
        trashOutcome = nil
        copyOutcome = nil
        moveOutcome = nil
        let notice = notifications.post("Moving selected items to Trash…", kind: .progress)
        defer { isTrashing = false; notifications.dismiss(notice) }
        do {
            let captured = try await ItemTrash.Batch.capture(sources)
            access += try await accessForOperation(sources.map { $0.deletingLastPathComponent() }, requiring: .readWrite)
            for (entry, item) in zip(entries, captured.items) {
                guard item.isSymbolicLink == entry.isSymbolicLink,
                      item.isDirectory == (!entry.isSymbolicLink && (entry.isDirectory || entry.isPackage)) else {
                    throw ItemTrash.PreflightError(source: entry.url, reason: "The selected item's type changed. Refresh and try Trash again.")
                }
            }
            guard pendingChangeID == nil, !preview.isSaving else { return nil }
            operations.lockPreviews(affecting: { url in captured.items.contains { $0.affects(url) } })
            guard let operation = try await resolveTrashChanges(captured) else { return nil }
            let result = await operation.trash(using: trashItem)
            await operations.closePreviews(affecting: { url in result.removed.contains { $0.affects(url) } })
            let messages = await refreshTrash(result.removed)
            let outcome = ItemTrash.Batch.Outcome(succeeded: result.succeeded, message: ([result.message] + messages).joined(separator: "\n"),
                                                  completed: result.completed, failed: result.failed,
                                                  unattempted: result.unattempted, removed: result.removed)
            trashOutcome = outcome
            let succeeded = outcome.succeeded && messages.isEmpty
            notifications.finish(notice, message: succeeded ? Self.transferSuccessMessage(outcome.completed, action: "moved to Trash") : outcome.message,
                                 succeeded: succeeded)
            return outcome
        } catch is CancellationError { return nil }
        catch {
            let failed = (error as? ItemTrash.PreflightError)?.source
            let outcome = ItemTrash.Batch.report(completed: [], removed: [], failed: failed,
                unattempted: sources.filter { $0 != failed }, error: "Trash request rejected before mutation. " + error.localizedDescription)
            trashOutcome = outcome
            notifications.finish(notice, message: outcome.message, succeeded: false)
            return outcome
        }
    }

    private func resolveTrashChanges(_ request: ItemTrash.Batch) async throws -> ItemTrash.Batch? {
        guard let resolution = await operations.resolveChanges() else { return nil }
        var items = request.items
        for saved in resolution.saved {
            if let index = items.firstIndex(where: { $0.source.path == saved.url.path }) {
                do { items[index] = try await items[index].acceptingSavedSource(saved.snapshot) } catch {
                    throw ItemTrash.PreflightError(source: items[index].source, reason: error.localizedDescription)
                }
            }
        }
        return ItemTrash.Batch(items: items)
    }

    private func refreshTrash(_ operations: [ItemTrash]) async -> [String] {
        var targets: [(pane: DirectoryPane, navigation: UUID, directory: URL?, recovering: Bool, fallback: URL?)] = []
        for target in self.operations.panes {
            var changed = false
            var refresh: URL?
            var recovering = false
            var fallback: URL?
            for operation in operations {
                if let snapshot = target.applyTrash(operation) {
                    changed = true
                    if let directory = snapshot.directory { refresh = directory }
                    recovering = recovering || snapshot.recovering
                    if snapshot.fallback { fallback = operation.source.deletingLastPathComponent() }
                }
            }
            if changed { targets.append((target, target.navigationSnapshot.id, refresh, recovering, fallback)) }
        }
        var messages: [String] = []
        for snapshot in targets {
            let target = snapshot.pane
            await target.sort(by: target.sortField, direction: target.sortDirection)
            guard target.navigationSnapshot.id == snapshot.navigation else { continue }
            if let fallback = snapshot.fallback {
                messages += await target.recoverTrashFallback(from: fallback, navigation: snapshot.navigation)
                continue
            }
            guard var directory = snapshot.directory else { continue }
            while true {
                let error = await target.navigate(to: directory, selecting: nil, preservingDocument: true, intent: .reload)
                if let error {
                    messages.append("Couldn’t refresh the listing. " + error)
                    guard snapshot.recovering, directory.path != "/" else { break }
                    directory.deleteLastPathComponent()
                } else {
                    if snapshot.recovering, target.directory.path == directory.path {
                        messages.append("The browsed folder was trashed. Browsing \(target.directory.path) instead.")
                        target.explainTrashRecovery()
                    }
                    break
                }
            }
        }
        return messages
    }

    public func dismissTrashOutcome() { trashOutcome = nil }

    /// Capture the displayed selection before asynchronous work or any dirty-document decision.
    @discardableResult public func moveToOtherPane(from id: PaneID, items expectedItems: Set<URL>? = nil) async -> ItemMove.Batch.Outcome? {
        guard canMove(in: id), expectedItems == nil || expectedItems == pane(id).selectedItems,
              let destinationID = transferDestination(from: id) else { return nil }
        let entries = pane(id).entries.filter { pane(id).selectedItems.contains($0.url) }
        let sources = entries.map(\.url)
        let directory = pane(destinationID).directory
        return await performMove(sources, to: directory, entries: entries)
    }

    private func performMove(_ sources: [URL], to directory: URL, entries: [DirectoryEntry], reservation: UUID? = nil) async -> ItemMove.Batch.Outcome? {
        var access = [left.directoryAccess, right.directoryAccess].compactMap { $0 }
        defer { withExtendedLifetime(access) {} }
        guard let reservation = reservation ?? operations.beginOperation(for: self) else { return nil }
        defer { operations.endOperation(reservation) }
        dragNotice = nil
        isMoving = true
        trashOutcome = nil
        copyOutcome = nil
        moveOutcome = nil
        let notice = notifications.post("Moving selected items…", kind: .progress)
        defer { isMoving = false; notifications.dismiss(notice) }
        do {
            access += try await sourceAccessForTransfer(sources, requiring: .readWrite)
            let captured = try await ItemMove.Batch.captureForResolvingCollisions(sources, to: directory)
            access += try await accessForOperation([directory], requiring: .readWrite)
            guard pendingChangeID == nil, !preview.isSaving else { return nil }
            operations.lockPreviews(affecting: { url in captured.items.contains { $0.affects(url) || $0.destination.path == url.path } })
            guard let resolved = try await captured.resolvingCollisions(chooseTransferName) else { return nil }
            operations.lockPreviews(affecting: { url in resolved.items.contains { $0.affects(url) || ($0.replacement != nil && $0.destination.path == url.path) } })
            guard let operation = try await resolveMoveChanges(resolved) else { return nil }
            let result = await operation.move(using: moveItem)
            let recoveryErrors = await operations.refreshRestoredPreviews(at: result.restored)
            await operations.closePreviews(affecting: { url in result.relocated.contains { $0.affects(url) } || result.replaced.contains { $0.path == url.path } })
            let errors = await refreshMoves(operation, result: result, entries: entries)
            let refresh = errors.isEmpty ? "" : "\nCouldn’t refresh the listing. \(errors.joined(separator: "\n"))"
            let outcome = ItemMove.Batch.Outcome(succeeded: result.succeeded, message: ([result.message] + recoveryErrors).joined(separator: "\n") + refresh,
                                                 completed: result.completed, failed: result.failed,
                                                 unattempted: result.unattempted, relocated: result.relocated, replaced: result.replaced, restored: result.restored)
            moveOutcome = outcome
            let succeeded = outcome.succeeded && errors.isEmpty && recoveryErrors.isEmpty
            notifications.finish(notice, message: succeeded ? Self.transferSuccessMessage(outcome.completed, action: "moved") : outcome.message,
                                 succeeded: succeeded)
            return outcome
        } catch is CancellationError { return nil }
        catch {
            let failed = (error as? ItemMove.PreflightError)?.source
            let outcome = ItemMove.Batch.report(relocated: [], failed: failed, unattempted: sources.filter { $0 != failed },
                error: "Move request rejected before mutation to \(directory.path). \(error.localizedDescription)")
            moveOutcome = outcome
            notifications.finish(notice, message: outcome.message, succeeded: false)
            return outcome
        }
    }

    private func chooseTransferName(_ collision: ItemMove.Collision) async -> ItemMove.CollisionChoice {
        let decision = UUID()
        pendingChangeID = decision
        return await withCheckedContinuation { continuation in
            resolveTransferCollision(collision) { [weak self] name in
                guard let self, self.pendingChangeID == decision else { return }
                self.pendingChangeID = nil
                continuation.resume(returning: name)
            }
        }
    }

    private func resolveMoveChanges(_ request: ItemMove.Batch) async throws -> ItemMove.Batch? {
        guard let resolution = await operations.resolveChanges() else { return nil }
        var items = request.items
        for saved in resolution.saved {
            for index in items.indices {
                do {
                    if items[index].source.path == saved.url.path {
                        items[index] = try await items[index].acceptingSavedSource(saved.snapshot)
                    } else if items[index].replacement != nil && items[index].destination.path == saved.url.path {
                        items[index] = try await items[index].acceptingSavedDestination(saved.snapshot)
                    }
                } catch {
                    throw ItemMove.PreflightError(source: items[index].source, destination: items[index].destination, reason: error.localizedDescription)
                }
            }
        }
        return ItemMove.Batch(items: items)
    }

    private func refreshMoves(_ operation: ItemMove.Batch, result: ItemMove.Batch.Outcome, entries: [DirectoryEntry]) async -> [String] {
        let movedSources = Set(result.relocated.map(\.source))
        let moved = await Task.detached(priority: .userInitiated) {
            operation.items.enumerated().filter { movedSources.contains($0.element.source) }.map { index, item in
                let attributes = try? FileManager.default.attributesOfItem(atPath: item.destination.path)
                let size = attributes?[.type] as? FileAttributeType == .typeRegular
                    ? (attributes?[.size] as? NSNumber)?.uint64Value : nil
                let entry: DirectoryEntry
                if entries.indices.contains(index), entries[index].name == item.destination.lastPathComponent {
                    entry = entries[index]
                } else {
                    let isPackage = (try? item.destination.resolvingSymlinksInPath().resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
                    var isFolder: ObjCBool = false
                    _ = FileManager.default.fileExists(atPath: item.destination.path, isDirectory: &isFolder)
                    entry = DirectoryEntry(url: item.destination, isDirectory: isFolder.boolValue && !isPackage,
                        isPackage: isPackage, isSymbolicLink: attributes?[.type] as? FileAttributeType == .typeSymbolicLink,
                        modifiedDate: attributes?[.modificationDate] as? Date)
                }
                return (item, DirectoryEntry(url: item.destination, isDirectory: entry.isDirectory, isPackage: entry.isPackage,
                                            isSymbolicLink: entry.isSymbolicLink,
                                            isHidden: item.destination.lastPathComponent.hasPrefix(".")
                                                || (try? item.destination.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true,
                                            modifiedDate: entry.modifiedDate, size: size))
            }
        }.value
        let affected = Set(operation.items.flatMap { [$0.source.deletingLastPathComponent().path, $0.destination.deletingLastPathComponent().path] })
        var targets: [(pane: DirectoryPane, navigation: UUID, directory: URL?)] = []
        for target in operations.panes {
            var changed = false
            var refresh: URL?
            for (item, entry) in moved {
                if let snapshot = target.applyMove(item, entry: entry) {
                    changed = true
                    if let directory = snapshot.refreshDirectory { refresh = directory }
                }
            }
            let navigation = target.navigationSnapshot
            if affected.contains(navigation.directory.path) { refresh = navigation.directory }
            if changed || refresh != nil { targets.append((target, navigation.id, refresh)) }
        }
        var errors: [String] = []
        for snapshot in targets {
            let target = snapshot.pane
            await target.sort(by: target.sortField, direction: target.sortDirection)
            guard target.navigationSnapshot.id == snapshot.navigation, let directory = snapshot.directory else { continue }
            if let error = await target.navigate(to: directory, selecting: nil, preservingDocument: true, intent: .reload) { errors.append(error) }
        }
        return errors
    }

    public func dismissMoveOutcome() { moveOutcome = nil }

    public func canCopy(in id: PaneID) -> Bool {
        operations.canMutate && transferDestination(from: id) != nil && !pane(id).selectedItems.isEmpty && pane(id).primaryItem != nil
            && !isDragging && canStartTransfer(in: id)
            && transferDestination(from: id).map { permitsFileOperations(in: $0) } == true
    }

    public func canDuplicate(in id: PaneID) -> Bool {
        operations.canMutate && !isDragging && canStartTransfer(in: id)
            && !pane(id).selectedItems.isEmpty && pane(id).primaryItem != nil
    }

    /// Copy the guarded displayed selection into its captured containing directory.
    @discardableResult public func duplicate(from id: PaneID, items expectedItems: Set<URL>? = nil) async -> ItemCopy.Outcome? {
        guard canDuplicate(in: id), expectedItems == nil || expectedItems == pane(id).selectedItems else { return nil }
        let sources = pane(id).entries.filter { pane(id).selectedItems.contains($0.url) }.map(\.url)
        let directory = pane(id).directory
        return await performCopy(sources, to: directory)
    }

    /// Snapshot the displayed source and destination before any asynchronous work or dirty prompt.
    @discardableResult public func copyToOtherPane(from id: PaneID, items expectedItems: Set<URL>? = nil) async -> ItemCopy.Outcome? {
        guard canCopy(in: id), expectedItems == nil || expectedItems == pane(id).selectedItems,
              let destinationID = transferDestination(from: id) else { return nil }
        let sources = pane(id).entries.filter { pane(id).selectedItems.contains($0.url) }.map(\.url)
        let directory = pane(destinationID).directory
        return await performCopy(sources, to: directory)
    }

    private func performCopy(_ sources: [URL], to directory: URL, reservation: UUID? = nil) async -> ItemCopy.Outcome? {
        var access = [left.directoryAccess, right.directoryAccess].compactMap { $0 }
        defer { withExtendedLifetime(access) {} }
        guard let reservation = reservation ?? operations.beginOperation(for: self) else { return nil }
        defer { operations.endOperation(reservation) }
        dragNotice = nil
        isCopying = true
        trashOutcome = nil
        moveOutcome = nil
        copyOutcome = nil
        let notice = notifications.post("Copying selected items…", kind: .progress)
        defer { isCopying = false; notifications.dismiss(notice) }
        do {
            access += try await sourceAccessForTransfer(sources, requiring: .readOnly)
            let captured = try await ItemCopy.Batch.capture(sources, to: directory, allowingCollisions: true,
                                                           allowingSameFolderCopies: true)
            access += try await accessForOperation([directory], requiring: .readWrite)
            guard pendingChangeID == nil, !preview.isSaving else { return nil }
            operations.lockPreviews(affecting: { url in captured.items.contains { $0.affects(url) || $0.destination.path == url.path } })
            guard let resolved = try await captured.resolvingCollisions(chooseTransferName) else { return nil }
            operations.lockPreviews(affecting: { url in resolved.items.contains { $0.affects(url) || ($0.replacement != nil && $0.destination.path == url.path) } })
            guard let operation = try await resolveCopyChanges(resolved) else { return nil }
            let result = await operation.copy(using: copyItem)
            let recoveryErrors = await operations.refreshRestoredPreviews(at: result.restored)
            await operations.closePreviews(affecting: { url in result.replaced.contains { $0.path == url.path } })
            let affected = Set(operation.items.flatMap { [$0.source.deletingLastPathComponent().path, $0.destination.deletingLastPathComponent().path] })
            let refreshErrors = await Self.refreshDirectories(affected, panes: operations.panes)
            let refreshMessage = refreshErrors.isEmpty ? "" : "\nCouldn’t refresh the listing. \(refreshErrors.joined(separator: "\n"))"
            let outcome = ItemCopy.Outcome(succeeded: result.succeeded, message: ([result.message] + recoveryErrors).joined(separator: "\n") + refreshMessage,
                                           completed: result.completed, failed: result.failed, unattempted: result.unattempted,
                                           replaced: result.replaced, restored: result.restored)
            copyOutcome = outcome
            let succeeded = outcome.succeeded && refreshErrors.isEmpty && recoveryErrors.isEmpty
            notifications.finish(notice, message: succeeded ? Self.transferSuccessMessage(outcome.completed, action: "copied") : outcome.message,
                                 succeeded: succeeded)
            return outcome
        } catch is CancellationError { return nil }
        catch {
            let outcome = ItemCopy.Outcome(succeeded: false,
                message: "Copy request rejected before any item was copied.\n\(error.localizedDescription)",
                failed: (error as? ItemCopy.PreflightError)?.source,
                unattempted: sources.filter { $0 != (error as? ItemCopy.PreflightError)?.source })
            copyOutcome = outcome
            notifications.finish(notice, message: outcome.message, succeeded: false)
            return outcome
        }
    }

    private func resolveCopyChanges(_ request: ItemCopy.Batch) async throws -> ItemCopy.Batch? {
        guard let resolution = await operations.resolveChanges() else { return nil }
        var items = request.items
        for saved in resolution.saved {
            for index in items.indices {
                if items[index].source.path == saved.url.path {
                    items[index] = try await items[index].acceptingSavedSource(saved.snapshot)
                } else if items[index].replacement != nil && items[index].destination.path == saved.url.path {
                    items[index] = try await items[index].acceptingSavedDestination(saved.snapshot)
                }
            }
        }
        for preview in resolution.discarded {
            if let url = preview.selection?.item.url, request.items.contains(where: { $0.affects(url) }) {
                preview.discardChanges()
            }
        }
        return ItemCopy.Batch(items: items)
    }

    private static func transferSuccessMessage(_ completed: [URL], action: String) -> String {
        let subject = completed.count == 1 ? completed[0].lastPathComponent : "\(completed.count) items"
        return "\(subject) \(action)."
    }

    public func dismissCopyOutcome() { copyOutcome = nil }

    public func canRename(in id: PaneID? = nil) -> Bool {
        let id = id ?? focusedPane
        return permitsFileOperations(in: id) && visiblePanes.contains(id) && operations.canMutate && pane(id).selectedItems.count == 1 && pane(id).primaryItem != nil
            && !isDragging && !isRenaming && !isCreating && !isCopying && !isMoving && !isTrashing && renameSubmission == nil && renameRequest == nil && creationRequest == nil && !preview.isSaving
    }

    /// Capture identity before prompting; delayed selection changes cannot retarget the request.
    public func beginRename(in id: PaneID? = nil) async {
        let id = id ?? focusedPane
        guard canRename(in: id), let item = pane(id).primaryItem else { return }
        let navigation = pane(id).navigationSnapshot.id
        var access = [pane(id).directoryAccess].compactMap { $0 }
        defer { withExtendedLifetime(access) {} }
        isRenaming = true
        renameError = nil
        defer { isRenaming = false }
        do {
            let operation = try await ItemRename.capture(item.url)
            access += try await accessForOperation([item.url.deletingLastPathComponent()], requiring: .readWrite)
            guard visiblePanes.contains(id), pane(id).navigationSnapshot.id == navigation,
                  pane(id).selectedItems == [item.url] else { return }
            renameRequest = RenameRequest(pane: id, item: item, operation: operation, navigationID: navigation, access: access)
            renameName = item.name
        } catch is CancellationError { return }
        catch {
            guard !Task.isCancelled, visiblePanes.contains(id), pane(id).navigationSnapshot.id == navigation,
                  pane(id).selectedItems == [item.url] else { return }
            renameError = "Couldn’t prepare Rename for \(item.url.path). \(error.localizedDescription)"
        }
    }

    @discardableResult public func submitRename(named name: String) async -> URL? {
        if let submission = renameSubmission {
            guard submission.name.utf8.elementsEqual(name.utf8) else { return nil }
            return await submission.task.value
        }
        guard renameRequest != nil, !isRenaming, !isCreating else { return nil }
        let task = Task<URL?, Never> { [weak self] in await self?.performRename(named: name) }
        renameSubmission = (name, task)
        let result = await task.value
        renameSubmission = nil
        return result
    }

    private func performRename(named name: String) async -> URL? {
        guard let request = renameRequest else { return nil }
        defer { withExtendedLifetime(request) {} }
        guard let reservation = operations.beginOperation(for: self) else {
            renameError = "Another file operation is in progress. Try Rename again when it finishes."
            return nil
        }
        defer { operations.endOperation(reservation) }
        renameName = name
        isRenaming = true
        renameError = nil
        defer { isRenaming = false; preview.setChangingLocation(nil) }
        var operation = request.operation
        do {
            _ = try await operation.destination(named: name)
        } catch {
            if renameRequest?.id == request.id { renameError = error.localizedDescription }
            return nil
        }
        guard renameRequest?.id == request.id else { return nil }
        renameRequest = nil
        guard visiblePanes.contains(request.pane), pane(request.pane).navigationSnapshot.id == request.navigationID,
              pane(request.pane).selectedItems == [request.item.url], !preview.isSaving, pendingChangeID == nil else {
            renameError = "The selected item or pane changed. Open Rename again."
            return nil
        }
        if operation.source.lastPathComponent.utf8.elementsEqual(name.utf8) { return operation.source }
        operations.lockPreviews(affecting: operation.affects)
        preview.setChangingLocation(operation)
        do {
            guard let resolution = await operations.resolveChanges() else { return nil }
            if let saved = resolution.saved.last(where: { $0.url.path == operation.source.path }) {
                operation = try await ItemRename.capture(operation.source, matching: saved.snapshot)
            }
            let result = try await renameItem(operation, name)
            await operations.closePreviews(affecting: operation.affects)
            preview.setChangingLocation(nil)
            let isHidden = await Task.detached(priority: .userInitiated) {
                result.lastPathComponent.hasPrefix(".")
                    || (try? result.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true
            }.value
            let targets = operations.panes.compactMap { target -> (pane: DirectoryPane, navigation: UUID, refreshDirectory: URL?)? in
                guard let snapshot = target.applyRename(operation, to: result, isHidden: isHidden) else { return nil }
                return (target, snapshot.navigation, snapshot.refreshDirectory)
            }
            var errors: [String] = []
            for snapshot in targets {
                let target = snapshot.pane
                await target.sort(by: target.sortField, direction: target.sortDirection)
                guard target.navigationSnapshot.id == snapshot.navigation, let directory = snapshot.refreshDirectory else { continue }
                if let error = await target.navigate(to: directory, selecting: nil, preservingDocument: true, intent: .reload) { errors.append(error) }
            }
            if !errors.isEmpty {
                renameError = "Renamed to \(result.path), but couldn’t refresh the listing. \(errors.joined(separator: "\n"))"
            }
            return result
        } catch {
            renameError = "Couldn’t rename \(operation.source.path). \(error.localizedDescription)"
            return nil
        }
    }

    public func cancelRename() { renameRequest = nil; renameError = nil }

    public func updateRenameName(_ name: String) {
        guard renameRequest != nil, !isRenaming, renameSubmission == nil else { return }
        renameName = name
    }

    /// An unrelated focus loss cancels only the filename entry, never the document draft.
    public func endRenameEditing() {
        guard renameRequest != nil, renameTransitionID == nil, renameSubmission == nil else { return }
        cancelRename()
    }

    private func resolveRenameIfNeeded(resume: @escaping @MainActor (ItemRename, URL) -> Void) -> Bool {
        guard let request = renameRequest else { return true }
        let transition = UUID()
        renameTransitionID = transition
        let name = renameName
        Task { [weak self] in
            guard let self else { return }
            let result = await self.submitRename(named: name)
            guard self.renameTransitionID == transition else { return }
            self.renameTransitionID = nil
            if let result { resume(request.operation, result) }
        }
        return false
    }

    public func dismissRenameError() { renameError = nil }

    /// Report whether a visible pane can start the guarded creation workflow.
    public func canCreate(in id: PaneID? = nil) -> Bool {
        let id = id ?? focusedPane
        return permitsFileOperations(in: id) && visiblePanes.contains(id) && operations.canMutate
            && !isDragging && !isCreating && !isRenaming && !isCopying && !isMoving && !isTrashing
            && renameRequest == nil && creationRequest == nil && !preview.isSaving && pendingChangeID == nil
    }

    /// Capture the creating pane and resolve any draft before presenting its name prompt.
    public func beginCreation(_ kind: ItemCreation.Kind, in id: PaneID? = nil) {
        let id = id ?? focusedPane
        let target = pane(id)
        beginCreation(CreationRequest(kind: kind, pane: id, directory: target.directory,
                                      navigationID: target.navigationSnapshot.id, access: [target.directoryAccess].compactMap { $0 }))
    }

    private func beginCreation(_ request: CreationRequest) {
        guard canCreate(in: request.pane),
              pane(request.pane).navigationSnapshot.id == request.navigationID else { return }
        guard resolveChangesIfNeeded(resume: { [weak self] in self?.beginCreation(request) }) else { return }
        focusedPane = request.pane
        creationError = nil
        guard requiresFolderAccess else { creationRequest = request; return }
        // Resolve folder permission before presenting the separate filename sheet.
        let permission = UUID()
        creationPermissionID = permission
        isCreating = true
        Task {
            defer {
                isCreating = false
                if creationPermissionID == permission { creationPermissionID = nil }
            }
            do {
                var prepared = request
                prepared.access += try await accessForOperation([request.directory], requiring: .readWrite)
                guard creationPermissionID == permission, visiblePanes.contains(request.pane),
                      pane(request.pane).navigationSnapshot.id == request.navigationID,
                      !preview.isDirty, !preview.isSaving else { return }
                creationRequest = prepared
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled, creationPermissionID == permission,
                      visiblePanes.contains(request.pane), pane(request.pane).navigationSnapshot.id == request.navigationID else { return }
                creationError = "Couldn’t allow changes in \(request.directory.path). \(error.localizedDescription)"
            }
        }
    }

    public func cancelCreation() { creationPermissionID = nil; creationRequest = nil; creationError = nil }

    public func dismissCreationError() { creationError = nil }

    /// Submit once, then refresh only panes still showing the captured directory.
    public func submitCreation(named name: String) async {
        guard let request = creationRequest, !isCreating else { return }
        defer { withExtendedLifetime(request) {} }
        do { try ItemName.validate(name) } catch {
            creationError = error.localizedDescription
            return
        }
        guard let reservation = operations.beginOperation(for: self) else {
            creationError = "Another file operation is in progress. Try creating the item again when it finishes."
            return
        }
        defer { operations.endOperation(reservation) }
        creationRequest = nil
        creationError = nil
        guard visiblePanes.contains(request.pane), pane(request.pane).navigationSnapshot.id == request.navigationID,
              !preview.isDirty, !preview.isSaving else {
            creationError = "The creating pane or document changed. Open New Text File or New Folder again."
            return
        }
        isCreating = true
        defer { isCreating = false }
        do {
            let created = try await createItem(request.kind, name, request.directory)
            let refreshErrors = await Self.refreshDirectories([created.deletingLastPathComponent().path], panes: operations.panes,
                creation: (pane(request.pane), request.navigationID, created))
            if !refreshErrors.isEmpty {
                creationError = "Created \(created.path), but couldn’t refresh the listing. \(refreshErrors.joined(separator: "\n"))"
            }
        } catch {
            creationError = "Couldn’t create \(name) in \(request.directory.path). \(error.localizedDescription)"
        }
    }

    /// Refresh currently affected panes without redirecting newer navigation or replacing drafts.
    static func refreshDirectories(_ paths: Set<String>, panes: [DirectoryPane],
                                   creation: (pane: DirectoryPane, navigation: UUID, item: URL)? = nil) async -> [String] {
        let snapshots = panes.map { (pane: $0, navigation: $0.navigationSnapshot) }
        let requestedDirectories = snapshots.map { $0.navigation.directory }
        let directories = await Task.detached(priority: .userInitiated) {
            requestedDirectories.map { $0.resolvingSymlinksInPath() }
        }.value
        var errors: [String] = []
        for (snapshot, directory) in zip(snapshots, directories) {
            let target = snapshot.pane
            guard target.navigationSnapshot.id == snapshot.navigation.id, paths.contains(directory.path) else { continue }
            let created = creation.flatMap {
                $0.pane === target && $0.navigation == snapshot.navigation.id ? $0.item : nil
            }
            if let created, created.lastPathComponent.hasPrefix(".") { target.showHiddenFiles = true }
            if let error = await target.navigate(to: directory, selecting: created, preservingDocument: created == nil) { errors.append(error) }
        }
        return errors
    }

    /// Focus a pane and complete its UI transition after any replaced draft is resolved.
    @discardableResult public func focus(_ id: PaneID, then: @escaping @MainActor () -> Void = {}) -> Bool {
        guard visiblePanes.contains(id) else { return false }
        guard id != focusedPane else { then(); return true }
        guard resolveRenameIfNeeded(resume: { [weak self] _, _ in self?.focus(id, then: then) }) else { return false }
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
        if id != focusedPane || items != target.selectedItems {
            guard resolveRenameIfNeeded(resume: { [weak self] operation, result in
                let relocated = Set(items.map { operation.relocated($0, to: result) })
                self?.select(relocated, in: id, focusedItem: focusedItem.map { operation.relocated($0, to: result) }, then: then)
            }) else { return false }
        }
        guard target.primaryItem(for: items, focusedItem: focusedItem)?.url == preview.selection?.item.url
                || resolveChangesIfNeeded(resume: { [weak self] in self?.select(items, in: id, focusedItem: focusedItem, then: then) }) else { return false }
        guard target.setSelection(items, focusedItem: focusedItem) else { return false }
        focusedPane = id
        then()
        return true
    }

    @discardableResult public func goBack() -> Task<Void, Never> { navigateHistory(forward: false) }
    @discardableResult public func goForward() -> Task<Void, Never> { navigateHistory(forward: true) }

    private func navigateHistory(forward: Bool) -> Task<Void, Never> {
        let id = focusedPane
        let navigate = pane(id).historyNavigation(forward: forward)
        return Task { [weak self] in
            guard let self, let navigate, self.visiblePanes.contains(id) else { return }
            guard self.resolveRenameIfNeeded(resume: { [weak self] _, _ in
                guard let self, self.visiblePanes.contains(id) else { return }
                Task { await navigate() }
            }) else { return }
            await navigate()
        }
    }

    public func navigate(to directory: URL, in id: PaneID) async {
        guard visiblePanes.contains(id) else { return }
        guard resolveRenameIfNeeded(resume: { [weak self] operation, result in
            Task { await self?.navigate(to: operation.relocated(directory, to: result), in: id) }
        }) else { return }
        guard resolveChangesIfNeeded(resume: { [weak self] in Task { await self?.navigate(to: directory, in: id) } }) else { return }
        focusedPane = id
        await pane(id).navigate(to: directory)
    }

    func requestOperationChanges() async -> UnsavedChoice? {
        guard pendingChangeID == nil, !preview.isSaving else { return nil }
        let decision = UUID()
        let document = preview.documentID
        pendingChangeID = decision
        let choice: UnsavedChoice = await withCheckedContinuation { continuation in
            confirmChanges(preview.selection?.item.name ?? "this file") { [weak self] choice in
                guard let self, self.pendingChangeID == decision else { return }
                self.pendingChangeID = nil
                continuation.resume(returning: choice)
            }
        }
        guard preview.documentID == document else { return nil }
        return choice
    }

    /// Resume the captured transition only after successful Save or explicit Discard.
    public func resolveChangesIfNeeded(resume: @escaping @MainActor () -> Void = {}) -> Bool {
        guard !preview.isSaving else { return false }
        guard preview.isDirty else { return true }
        guard !preview.isOperationLocked else { return false }
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
