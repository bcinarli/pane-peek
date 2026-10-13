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
    fileprivate func navigate(to directory: URL, selecting createdItem: URL?, preservingDocument: Bool = false) async -> String? {
        guard approveChange?(primaryItem, !preservingDocument, { [weak self] in
            Task { _ = await self?.navigate(to: directory, selecting: createdItem, preservingDocument: preservingDocument) }
        }) != false else { return nil }
        let request = UUID()
        requestID = request
        requestedDirectory = directory
        isLoading = true
        errorMessage = nil
        do {
            let canonical = await Task.detached(priority: .userInitiated) { directory.resolvingSymlinksInPath() }.value
            guard requestID == request else { return nil }
            requestedDirectory = canonical
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
                guard approveChange?(primary, !preservingDocument, { [weak self] in
                    guard let self, self.requestID == request else { return }
                    Task { _ = await self.navigate(to: directory, selecting: createdItem, preservingDocument: preservingDocument) }
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

    /// Keep the last usable listing at its new path, even if a subsequent refresh fails.
    fileprivate func applyRename(_ operation: ItemRename, to destination: URL,
                                 isHidden: Bool) -> (navigation: UUID, refreshDirectory: URL?)? {
        let intended = navigationSnapshot.directory
        let refresh = intended.path == operation.source.deletingLastPathComponent().path || operation.affects(intended)
        let directoryChanged = operation.affects(directory)
        if directoryChanged { directory = operation.relocated(directory, to: destination) }
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
                                      modifiedDate: entry.modifiedDate)
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
        if directoryChanged { directory = operation.relocated(directory) }
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
                                   isSymbolicLink: entry.isSymbolicLink, isHidden: entry.isHidden, modifiedDate: entry.modifiedDate)
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
                    allEntries = sorted
                    hasLoaded = true
                    listingRevision = UUID()
                    messages.append("The browsed folder was trashed. Browsing \(directory.path) instead.")
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
    public struct RenameRequest: Identifiable, Sendable {
        public let id = UUID()
        public let pane: PaneID
        public let item: DirectoryEntry
        public let operation: ItemRename
        fileprivate let navigationID: UUID
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
    }
    public private(set) var creationRequest: CreationRequest?
    public private(set) var isCreating = false
    public private(set) var creationError: String?
    private let createItem: @Sendable (ItemCreation.Kind, String, URL) async throws -> URL
    public private(set) var isCopying = false
    public private(set) var copyOutcome: ItemCopy.Outcome?
    private let copyItem: @Sendable (ItemCopy) async -> ItemCopy.Outcome
    public private(set) var isMoving = false
    public private(set) var moveOutcome: ItemMove.Batch.Outcome?
    private let moveItem: @Sendable (ItemMove) async -> ItemMove.Outcome
    private let confirmMove: @MainActor (ItemMove.Batch, @escaping @MainActor (Bool) -> Void) -> Void
    public private(set) var isTrashing = false
    public private(set) var trashOutcome: ItemTrash.Batch.Outcome?
    private let trashItem: @Sendable (ItemTrash) async -> ItemTrash.Outcome
    private let confirmTrash: @MainActor (ItemTrash.Batch, @escaping @MainActor (Bool) -> Void) -> Void
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
                rename: @escaping @Sendable (ItemRename, String) async throws -> URL = { try await $0.rename(to: $1) },
                copy: @escaping @Sendable (ItemCopy) async -> ItemCopy.Outcome = { await $0.copy() },
                move: @escaping @Sendable (ItemMove) async -> ItemMove.Outcome = { await $0.move() },
                confirmMove: @escaping @MainActor (ItemMove.Batch, @escaping @MainActor (Bool) -> Void) -> Void = { _, completion in completion(false) },
                trash: @escaping @Sendable (ItemTrash) async -> ItemTrash.Outcome = { await $0.trash() },
                confirmTrash: @escaping @MainActor (ItemTrash.Batch, @escaping @MainActor (Bool) -> Void) -> Void = { _, completion in completion(false) },
                confirmChanges: @escaping @MainActor (String, @escaping @MainActor (UnsavedChoice) -> Void) -> Void = { _, completion in completion(.cancel) }) {
        self.preview = preview ?? PreviewState()
        self.createItem = create
        self.renameItem = rename
        self.copyItem = copy
        self.moveItem = move
        self.confirmMove = confirmMove
        self.trashItem = trash
        self.confirmTrash = confirmTrash
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

    public func canMove(in id: PaneID) -> Bool { canCopy(in: id) }

    public enum DropOperation: Sendable { case copy, move }

    public struct DragNotice: Identifiable {
        public let id = UUID()
        public let message: String
    }
    public private(set) var dragNotice: DragNotice?
    private var draggedItems: DragSelection?
    private var dragReceivedHere = false
    public var isDragging: Bool { draggedItems != nil }
    public var draggedSources: [URL] { draggedItems?.sources ?? [] }

    /// Export only the accepted selection; resolving a draft requires a fresh native drag gesture.
    public func beginDrag(in id: PaneID, items expectedItems: Set<URL>) -> [URL]? {
        if let draggedItems {
            return draggedItems.pane == id && expectedItems == Set(draggedItems.sources) ? draggedItems.sources : nil
        }
        guard canReceiveDrop(into: id), expectedItems == pane(id).selectedItems else { return nil }
        let selection = DragSelection(pane: id, entries: pane(id).entries.filter { expectedItems.contains($0.url) })
        guard Self.acceptsDropSources(selection.sources) else { return nil }
        if let edited = preview.selection?.item.url, preview.isDirty, selection.affects(edited) {
            dragNotice = DragNotice(message: "Drag not started. Resolve the unsaved changes, then drag again.")
            _ = resolveChangesIfNeeded { [weak self] in
                self?.dragNotice = DragNotice(message: "Changes resolved. Drag the selected items again to start the transfer.")
            }
            return nil
        }
        copyOutcome = nil
        moveOutcome = nil
        trashOutcome = nil
        dragNotice = nil
        draggedItems = selection
        dragReceivedHere = false
        preview.setDraggingItems(selection)
        return selection.sources
    }

    public func endDrag(external: Bool = false) {
        guard isDragging else { return }
        if external && !dragReceivedHere {
            dragNotice = DragNotice(message: "Drag handed to Finder or another app. Use Refresh to see any filesystem changes.")
        }
        draggedItems = nil
        dragReceivedHere = false
        preview.setDraggingItems(nil)
    }
    public func dismissDragNotice() { dragNotice = nil }

    public func canReceiveDrop(into id: PaneID) -> Bool {
        visiblePanes.contains(id) && !isCopying && !isMoving && !isTrashing && !isCreating && !isRenaming
            && creationRequest == nil && renameRequest == nil && renameSubmission == nil
            && !preview.isSaving && pendingChangeID == nil
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
    @discardableResult public func submitDrop(_ sources: [URL], into id: PaneID, operation: DropOperation) -> Task<Void, Never>? {
        guard canReceiveDrop(into: id), Self.acceptsDropSources(sources) else { return nil }
        let directory = pane(id).directory
        if isDragging && Set(sources.map(\.path)) == Set(draggedSources.map(\.path)) { dragReceivedHere = true }
        dragNotice = nil
        switch operation {
        case .copy:
            isCopying = true
            return Task { _ = await performCopy(sources, to: directory) }
        case .move:
            isMoving = true
            return Task { _ = await performMove(sources, to: directory, entries: []) }
        }
    }

    public func canTrash(in id: PaneID? = nil) -> Bool {
        let id = id ?? focusedPane
        return visiblePanes.contains(id) && !pane(id).selectedItems.isEmpty && pane(id).primaryItem != nil
            && !isDragging && !isTrashing && !isRenaming && !isCreating && !isCopying && !isMoving && renameSubmission == nil
            && renameRequest == nil && creationRequest == nil && !preview.isSaving && pendingChangeID == nil
    }

    /// Capture the displayed selection before confirmation; later changes cannot redirect it.
    @discardableResult public func moveToTrash(from id: PaneID? = nil, items expectedItems: Set<URL>? = nil) async -> ItemTrash.Batch.Outcome? {
        let id = id ?? focusedPane
        guard canTrash(in: id), expectedItems == nil || expectedItems == pane(id).selectedItems else { return nil }
        let entries = pane(id).entries.filter { pane(id).selectedItems.contains($0.url) }
        let sources = entries.map(\.url)
        isTrashing = true
        trashOutcome = nil
        copyOutcome = nil
        moveOutcome = nil
        defer { isTrashing = false; preview.setTrashingItems([]) }
        do {
            let captured = try await ItemTrash.Batch.capture(sources)
            for (entry, item) in zip(entries, captured.items) {
                guard item.isSymbolicLink == entry.isSymbolicLink,
                      item.isDirectory == (!entry.isSymbolicLink && (entry.isDirectory || entry.isPackage)) else {
                    throw ItemTrash.PreflightError(source: entry.url, reason: "The selected item's type changed. Refresh and try Trash again.")
                }
            }
            guard pendingChangeID == nil, !preview.isSaving else { return nil }
            preview.setTrashingItems(captured.items)
            let decision = UUID()
            pendingChangeID = decision
            let confirmed = await withCheckedContinuation { continuation in
                confirmTrash(captured) { [weak self] answer in
                    guard let self, self.pendingChangeID == decision else { return }
                    self.pendingChangeID = nil
                    continuation.resume(returning: answer)
                }
            }
            guard confirmed, let operation = try await resolveTrashChanges(captured) else { return nil }
            let result = await operation.trash(using: trashItem)
            if let selected = preview.selection, result.removed.contains(where: { $0.affects(selected.item.url) }) {
                preview.discardChanges()
                await preview.load(nil)
            }
            preview.setTrashingItems([])
            let messages = await refreshTrash(result.removed)
            let outcome = ItemTrash.Batch.Outcome(succeeded: result.succeeded, message: ([result.message] + messages).joined(separator: "\n"),
                                                  completed: result.completed, failed: result.failed,
                                                  unattempted: result.unattempted, removed: result.removed)
            trashOutcome = outcome
            return outcome
        } catch {
            let failed = (error as? ItemTrash.PreflightError)?.source
            let outcome = ItemTrash.Batch.report(completed: [], removed: [], failed: failed,
                unattempted: sources.filter { $0 != failed }, error: "Trash request rejected before mutation. " + error.localizedDescription)
            trashOutcome = outcome
            return outcome
        }
    }

    private func resolveTrashChanges(_ request: ItemTrash.Batch) async throws -> ItemTrash.Batch? {
        guard preview.isTrashing, preview.isDirty else { return request }
        var items = request.items
        let document = preview.documentID
        let decision = UUID()
        pendingChangeID = decision
        let choice = await withCheckedContinuation { continuation in
            confirmChanges(preview.selection?.item.name ?? "selected items") { [weak self] choice in
                guard let self, self.pendingChangeID == decision else { return }
                self.pendingChangeID = nil
                continuation.resume(returning: choice)
            }
        }
        guard preview.documentID == document else { return nil }
        switch choice {
        case .cancel: return nil
        case .discard: return request
        case .save:
            let savingSource = items.firstIndex { preview.selection?.item.url.path == $0.source.path }
            preview.setTrashingItems([])
            let saved = await preview.save()
            preview.setTrashingItems(items)
            guard saved else { return nil }
            if let index = savingSource {
                do { items[index] = try await items[index].acceptingSavedSource(preview.fileSnapshot) } catch {
                    throw ItemTrash.PreflightError(source: items[index].source, reason: error.localizedDescription)
                }
            }
            return ItemTrash.Batch(items: items)
        }
    }

    private func refreshTrash(_ operations: [ItemTrash]) async -> [String] {
        var targets: [(pane: PaneID, navigation: UUID, directory: URL?, recovering: Bool, fallback: URL?)] = []
        for id in [PaneID.left, .right] {
            let target = pane(id)
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
            if changed { targets.append((id, target.navigationSnapshot.id, refresh, recovering, fallback)) }
        }
        var messages: [String] = []
        for snapshot in targets {
            let target = pane(snapshot.pane)
            await target.sort(by: target.sortField, direction: target.sortDirection)
            guard target.navigationSnapshot.id == snapshot.navigation else { continue }
            if let fallback = snapshot.fallback {
                messages += await target.recoverTrashFallback(from: fallback, navigation: snapshot.navigation)
                continue
            }
            guard var directory = snapshot.directory else { continue }
            while true {
                let error = await target.navigate(to: directory, selecting: nil, preservingDocument: true)
                if let error {
                    messages.append("Couldn’t refresh the listing. " + error)
                    guard snapshot.recovering, directory.path != "/" else { break }
                    directory.deleteLastPathComponent()
                } else {
                    if snapshot.recovering, target.directory.path == directory.path {
                        messages.append("The browsed folder was trashed. Browsing \(target.directory.path) instead.")
                    }
                    break
                }
            }
        }
        return messages
    }

    public func dismissTrashOutcome() { trashOutcome = nil }

    /// Capture the displayed selection before confirmation or any dirty-document decision.
    @discardableResult public func moveToOtherPane(from id: PaneID, items expectedItems: Set<URL>? = nil) async -> ItemMove.Batch.Outcome? {
        guard canMove(in: id), expectedItems == nil || expectedItems == pane(id).selectedItems,
              let destinationID = transferDestination(from: id) else { return nil }
        let entries = pane(id).entries.filter { pane(id).selectedItems.contains($0.url) }
        let sources = entries.map(\.url)
        let directory = pane(destinationID).directory
        return await performMove(sources, to: directory, entries: entries)
    }

    private func performMove(_ sources: [URL], to directory: URL, entries: [DirectoryEntry]) async -> ItemMove.Batch.Outcome? {
        dragNotice = nil
        isMoving = true
        trashOutcome = nil
        copyOutcome = nil
        moveOutcome = nil
        defer { isMoving = false; preview.setMovingItems([]) }
        do {
            let captured = try await ItemMove.Batch.capture(sources, to: directory)
            guard pendingChangeID == nil, !preview.isSaving else { return nil }
            preview.setMovingItems(captured.items)
            let decision = UUID()
            pendingChangeID = decision
            let confirmed = await withCheckedContinuation { continuation in
                confirmMove(captured) { [weak self] answer in
                    guard let self, self.pendingChangeID == decision else { return }
                    self.pendingChangeID = nil
                    continuation.resume(returning: answer)
                }
            }
            guard confirmed, let operation = try await resolveMoveChanges(captured) else { return nil }
            let result = await operation.move(using: moveItem)
            if let selected = preview.selection, result.relocated.contains(where: { $0.affects(selected.item.url) }) {
                preview.discardChanges()
                await preview.load(nil)
            }
            preview.setMovingItems([])
            let errors = await refreshMoves(operation, result: result, entries: entries)
            let refresh = errors.isEmpty ? "" : "\nCouldn’t refresh the listing. \(errors.joined(separator: "\n"))"
            let outcome = ItemMove.Batch.Outcome(succeeded: result.succeeded, message: result.message + refresh,
                                                 completed: result.completed, failed: result.failed,
                                                 unattempted: result.unattempted, relocated: result.relocated)
            moveOutcome = outcome
            return outcome
        } catch {
            let failed = (error as? ItemMove.PreflightError)?.source
            let outcome = ItemMove.Batch.report(relocated: [], failed: failed, unattempted: sources.filter { $0 != failed },
                error: "Move request rejected before mutation to \(directory.path). \(error.localizedDescription)")
            moveOutcome = outcome
            return outcome
        }
    }

    private func resolveMoveChanges(_ request: ItemMove.Batch) async throws -> ItemMove.Batch? {
        guard preview.isMoving, preview.isDirty else { return request }
        var items = request.items
        let document = preview.documentID
        let decision = UUID()
        pendingChangeID = decision
        let choice = await withCheckedContinuation { continuation in
            confirmChanges(preview.selection?.item.name ?? "selected items") { [weak self] choice in
                guard let self, self.pendingChangeID == decision else { return }
                self.pendingChangeID = nil
                continuation.resume(returning: choice)
            }
        }
        guard preview.documentID == document else { return nil }
        switch choice {
        case .cancel: return nil
        case .discard: return request
        case .save:
            let savingSource = items.firstIndex { preview.selection?.item.url.path == $0.source.path }
            preview.setMovingItems([])
            let saved = await preview.save()
            preview.setMovingItems(items)
            guard saved else { return nil }
            if let index = savingSource {
                do { items[index] = try await items[index].acceptingSavedSource(preview.fileSnapshot) } catch {
                    throw ItemMove.PreflightError(source: items[index].source, destination: items[index].destination, reason: error.localizedDescription)
                }
            }
            return ItemMove.Batch(items: items)
        }
    }

    private func refreshMoves(_ operation: ItemMove.Batch, result: ItemMove.Batch.Outcome, entries: [DirectoryEntry]) async -> [String] {
        let movedSources = Set(result.relocated.map(\.source))
        let moved = await Task.detached(priority: .userInitiated) {
            operation.items.enumerated().filter { movedSources.contains($0.element.source) }.map { index, item in
                let entry: DirectoryEntry
                if entries.indices.contains(index) {
                    entry = entries[index]
                } else {
                    let attributes = try? FileManager.default.attributesOfItem(atPath: item.destination.path)
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
                                            modifiedDate: entry.modifiedDate))
            }
        }.value
        let affected = Set(operation.items.flatMap { [$0.source.deletingLastPathComponent().path, $0.destination.deletingLastPathComponent().path] })
        var targets: [(pane: PaneID, navigation: UUID, directory: URL?)] = []
        for id in [PaneID.left, .right] {
            let target = pane(id)
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
            if changed || refresh != nil { targets.append((id, navigation.id, refresh)) }
        }
        var errors: [String] = []
        for snapshot in targets {
            let target = pane(snapshot.pane)
            await target.sort(by: target.sortField, direction: target.sortDirection)
            guard target.navigationSnapshot.id == snapshot.navigation, let directory = snapshot.directory else { continue }
            if let error = await target.navigate(to: directory, selecting: nil, preservingDocument: true) { errors.append(error) }
        }
        return errors
    }

    public func dismissMoveOutcome() { moveOutcome = nil }

    public func canCopy(in id: PaneID) -> Bool {
        transferDestination(from: id) != nil && !pane(id).selectedItems.isEmpty && pane(id).primaryItem != nil
            && !isDragging && canReceiveDrop(into: id)
    }

    /// Snapshot the displayed source and destination before any asynchronous work or dirty prompt.
    @discardableResult public func copyToOtherPane(from id: PaneID, items expectedItems: Set<URL>? = nil) async -> ItemCopy.Outcome? {
        guard canCopy(in: id), expectedItems == nil || expectedItems == pane(id).selectedItems,
              let destinationID = transferDestination(from: id) else { return nil }
        let sources = pane(id).entries.filter { pane(id).selectedItems.contains($0.url) }.map(\.url)
        let directory = pane(destinationID).directory
        return await performCopy(sources, to: directory)
    }

    private func performCopy(_ sources: [URL], to directory: URL) async -> ItemCopy.Outcome? {
        dragNotice = nil
        let snapshots = [PaneID.left, .right].map { (pane: $0, navigation: pane($0).navigationSnapshot) }
        isCopying = true
        trashOutcome = nil
        moveOutcome = nil
        copyOutcome = nil
        defer { isCopying = false; preview.setCopyingItems([]) }
        do {
            let captured = try await ItemCopy.Batch.capture(sources, to: directory)
            guard pendingChangeID == nil, !preview.isSaving else { return nil }
            preview.setCopyingItems(captured.items)
            guard let operation = try await resolveCopyChanges(captured) else { return nil }
            let result = await operation.copy(using: copyItem)
            let targets = await Task.detached(priority: .userInitiated) {
                snapshots.map { (pane: $0.pane, navigationID: $0.navigation.id,
                                 directory: $0.navigation.directory.resolvingSymlinksInPath()) }
            }.value
            let affected = Set(operation.items.flatMap { [$0.source.deletingLastPathComponent().path, $0.destination.deletingLastPathComponent().path] })
            var refreshErrors: [String] = []
            for snapshot in targets {
                let target = pane(snapshot.pane)
                guard target.navigationSnapshot.id == snapshot.navigationID,
                      affected.contains(snapshot.directory.path) else { continue }
                if let error = await target.navigate(to: snapshot.directory, selecting: nil, preservingDocument: true) { refreshErrors.append(error) }
            }
            let refreshMessage = refreshErrors.isEmpty ? "" : "\nCouldn’t refresh the listing. \(refreshErrors.joined(separator: "\n"))"
            let outcome = ItemCopy.Outcome(succeeded: result.succeeded, message: result.message + refreshMessage,
                                           completed: result.completed, failed: result.failed, unattempted: result.unattempted)
            copyOutcome = outcome
            return outcome
        } catch {
            let outcome = ItemCopy.Outcome(succeeded: false,
                message: "Copy request rejected before any item was copied. \(error.localizedDescription)",
                failed: (error as? ItemCopy.PreflightError)?.source,
                unattempted: sources.filter { $0 != (error as? ItemCopy.PreflightError)?.source })
            copyOutcome = outcome
            return outcome
        }
    }

    private func resolveCopyChanges(_ request: ItemCopy.Batch) async throws -> ItemCopy.Batch? {
        var items = request.items
        if preview.isCopying, preview.isDirty {
            let document = preview.documentID
            let decision = UUID()
            pendingChangeID = decision
            let choice = await withCheckedContinuation { continuation in
                confirmChanges(preview.selection?.item.name ?? "selected items") { [weak self] choice in
                    guard let self, self.pendingChangeID == decision else { return }
                    self.pendingChangeID = nil
                    continuation.resume(returning: choice)
                }
            }
            guard preview.documentID == document else { return nil }
            switch choice {
            case .cancel: return nil
            case .discard: preview.discardChanges()
            case .save:
                let savingSource = items.firstIndex { preview.selection?.item.url.path == $0.source.path }
                preview.setCopyingItems([])
                let saved = await preview.save()
                preview.setCopyingItems(items)
                guard saved else { return nil }
                if let index = savingSource { items[index] = try await items[index].acceptingSavedSource(preview.fileSnapshot) }
            }
        }
        return ItemCopy.Batch(items: items)
    }

    public func dismissCopyOutcome() { copyOutcome = nil }

    public func canRename(in id: PaneID? = nil) -> Bool {
        let id = id ?? focusedPane
        return visiblePanes.contains(id) && pane(id).selectedItems.count == 1 && pane(id).primaryItem != nil
            && !isDragging && !isRenaming && !isCreating && !isCopying && !isMoving && !isTrashing && renameSubmission == nil && renameRequest == nil && creationRequest == nil && !preview.isSaving
    }

    /// Capture identity before prompting; delayed selection changes cannot retarget the request.
    public func beginRename(in id: PaneID? = nil) async {
        let id = id ?? focusedPane
        guard canRename(in: id), let item = pane(id).primaryItem else { return }
        let navigation = pane(id).navigationSnapshot.id
        isRenaming = true
        renameError = nil
        defer { isRenaming = false }
        do {
            let operation = try await ItemRename.capture(item.url)
            guard visiblePanes.contains(id), pane(id).navigationSnapshot.id == navigation,
                  pane(id).selectedItems == [item.url] else { return }
            renameRequest = RenameRequest(pane: id, item: item, operation: operation, navigationID: navigation)
            renameName = item.name
        } catch {
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
        preview.setChangingLocation(operation)
        do {
            if preview.isChangingLocation, preview.isDirty {
                let document = preview.documentID
                let decision = UUID()
                pendingChangeID = decision
                let choice = await withCheckedContinuation { continuation in
                    confirmChanges(preview.selection?.item.name ?? request.item.name) { [weak self] choice in
                        guard let self, self.pendingChangeID == decision else { return }
                        self.pendingChangeID = nil
                        continuation.resume(returning: choice)
                    }
                }
                guard preview.documentID == document else { return nil }
                switch choice {
                case .cancel: return nil
                case .discard: break // Keep the draft until the rename succeeds.
                case .save:
                    let savingSource = preview.selection?.item.url.path == operation.source.path
                    preview.setChangingLocation(nil)
                    let saved = await preview.save()
                    preview.setChangingLocation(operation)
                    guard saved else { return nil }
                    if savingSource { operation = try await ItemRename.capture(operation.source, matching: preview.fileSnapshot) }
                }
            }
            let result = try await renameItem(operation, name)
            if preview.isChangingLocation {
                preview.discardChanges()
                await preview.load(nil)
            }
            preview.setChangingLocation(nil)
            let isHidden = await Task.detached(priority: .userInitiated) {
                result.lastPathComponent.hasPrefix(".")
                    || (try? result.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true
            }.value
            let targets = [PaneID.left, .right].compactMap { id -> (pane: PaneID, navigation: UUID, refreshDirectory: URL?)? in
                let target = pane(id)
                guard let snapshot = target.applyRename(operation, to: result, isHidden: isHidden) else { return nil }
                return (id, snapshot.navigation, snapshot.refreshDirectory)
            }
            var errors: [String] = []
            for snapshot in targets {
                let target = pane(snapshot.pane)
                await target.sort(by: target.sortField, direction: target.sortDirection)
                guard target.navigationSnapshot.id == snapshot.navigation, let directory = snapshot.refreshDirectory else { continue }
                if let error = await target.navigate(to: directory, selecting: nil) { errors.append(error) }
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

    /// Capture the creating pane and resolve any draft before presenting its name prompt.
    public func beginCreation(_ kind: ItemCreation.Kind, in id: PaneID? = nil) {
        let id = id ?? focusedPane
        let target = pane(id)
        beginCreation(CreationRequest(kind: kind, pane: id, directory: target.directory,
                                      navigationID: target.navigationSnapshot.id))
    }

    private func beginCreation(_ request: CreationRequest) {
        guard !isDragging, !isCreating, !isRenaming, !isCopying, !isMoving, !isTrashing, renameRequest == nil, creationRequest == nil, visiblePanes.contains(request.pane),
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
                if let error = await target.navigate(to: snapshot.directory, selecting: snapshot.pane == request.pane ? created : nil) {
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

    public func navigate(to directory: URL, in id: PaneID) async {
        guard visiblePanes.contains(id) else { return }
        guard resolveRenameIfNeeded(resume: { [weak self] operation, result in
            Task { await self?.navigate(to: operation.relocated(directory, to: result), in: id) }
        }) else { return }
        guard resolveChangesIfNeeded(resume: { [weak self] in Task { await self?.navigate(to: directory, in: id) } }) else { return }
        focusedPane = id
        await pane(id).navigate(to: directory)
    }

    /// Resume the captured transition only after successful Save or explicit Discard.
    public func resolveChangesIfNeeded(resume: @escaping @MainActor () -> Void = {}) -> Bool {
        guard !preview.isSaving else { return false }
        guard preview.isDirty else { return true }
        guard !preview.isChangingLocation, !preview.isCopying, !preview.isMoving, !preview.isTrashing, !preview.isDragging else { return false }
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
