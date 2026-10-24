import AppKit
import Darwin
import PanePeekCore

/// Shares live folder scopes and retains bookmarks independently of their consumers.
@MainActor final class FolderAccess {
    typealias Choose = @MainActor (URL) async throws -> URL?
    struct Location: Codable, Sendable {
        let id: UUID
        let data: Data
        let identity: Identity?
        var mode: DirectoryAccess.Mode? = nil
    }
    struct Identity: Codable, Sendable, Equatable {
        let file: Data
        let volume: String

        static func read(_ url: URL) throws -> Identity {
            var current = url
            current.removeAllCachedResourceValues()
            let values = try current.resourceValues(forKeys: [.fileResourceIdentifierKey, .volumeUUIDStringKey])
            guard let file = values.fileResourceIdentifier as? Data, let volume = values.volumeUUIDString else {
                throw CocoaError(.fileReadNoPermission)
            }
            return Identity(file: file, volume: volume)
        }
    }
    struct Resolution: Sendable { let url: URL; let stale: Bool }
    struct Bookmarking: Sendable {
        var create: @Sendable (URL, DirectoryAccess.Mode) throws -> Data = { url, mode in
            let options: URL.BookmarkCreationOptions = mode == .readWrite
                ? [.withSecurityScope] : [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
            return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        var resolve: @Sendable (Data) throws -> Resolution = {
            var stale = false
            let url = try URL(resolvingBookmarkData: $0, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            return Resolution(url: url, stale: stale)
        }
        var start: @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() }
    }
    private struct Record: Codable {
        let id: UUID
        var path: String
        var data: Data
        let identity: Identity?
        var mode: DirectoryAccess.Mode? = nil
    }
    private struct Root {
        let id: UUID
        weak var access: DirectoryAccess?
        let location: Location?
    }
    private var roots: [Root] = []
    private struct ListedLocation {
        let path: String
        let location: Location
        weak var access: DirectoryAccess?
    }
    private var locations: [ListedLocation] = []
    private var records: [Record]
    private let preferences: UserDefaults?
    private let bookmarking: Bookmarking
    private let selectionMode: DirectoryAccess.Mode
    private let stop: @Sendable (URL) -> Void
    private static let key = "sandboxFolderBookmarks"

    init(preferences: UserDefaults? = nil, selectionMode: DirectoryAccess.Mode = .readOnly, bookmarking: Bookmarking = Bookmarking(),
         stop: @escaping @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }) {
        self.preferences = preferences
        self.bookmarking = bookmarking
        self.selectionMode = selectionMode
        self.stop = stop
        let saved = preferences?.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([Record].self, from: $0) } ?? []
        records = saved.filter { $0.path.hasPrefix("/") && !$0.path.contains("\0") }
    }

    // Foundation redirects current-account Home lookups into the app container.
    static var accountHome: URL? {
        var record = passwd()
        var result: UnsafeMutablePointer<passwd>?
        let capacity = 16_384
        var buffer = [CChar](repeating: 0, count: capacity)
        guard getpwuid_r(getuid(), &record, &buffer, capacity, &result) == 0,
              result != nil, let directory = record.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
    }
    static var isReview: Bool { Bundle.main.object(forInfoDictionaryKey: "PanePeekSandboxReview") as? Bool == true }
    static func isSandboxed(in bundle: Bundle = .main) -> Bool {
        bundle.object(forInfoDictionaryKey: "PanePeekSandboxed") as? Bool == true ||
            bundle.object(forInfoDictionaryKey: "PanePeekSandboxReview") as? Bool == true
    }

    func select(initial: URL, mode: DirectoryAccess.Mode? = nil, requiredDirectory: URL? = nil, choose: Choose) async throws -> DirectoryAccess? {
        let mode = mode ?? selectionMode
        guard let url = try await choose(initial) else { return nil }
        // NSOpenPanel supplies an already-started scope; adopt it without starting it twice.
        let stop = stop
        var adopted = false
        defer { if !adopted { stop(url) } }
        try Task.checkCancellation()
        guard BrowserState.acceptsDropSources([url]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let root = await Task.detached(priority: .userInitiated) { url.resolvingSymlinksInPath() }.value
        if let requiredDirectory {
            guard requiredDirectory.standardized.pathComponents.starts(with: root.pathComponents) else {
                throw CocoaError(.fileWriteNoPermission)
            }
        }
        let data: Data?
        let identity: Identity?
        if preferences != nil {
            identity = try await Task.detached(priority: .userInitiated) { try Identity.read(root) }.value
            data = try await createBookmark(url, mode: mode)
        } else { data = nil; identity = nil }
        try Task.checkCancellation()
        let id = records.first { $0.path == root.path }?.id ?? UUID()
        if let data {
            records.removeAll { $0.id == id }
            records.append(Record(id: id, path: root.path, data: data, identity: identity, mode: mode))
            persist()
        }
        let access = DirectoryAccess(root: root, mode: mode) { stop(url) }
        adopted = true
        cache(access, id: id, data: data, identity: identity)
        return access
    }

    private func cache(_ access: DirectoryAccess, id: UUID, data: Data?, identity: Identity?) {
        roots.removeAll { $0.access == nil }
        let location = data.map { Location(id: id, data: $0, identity: identity, mode: access.mode) }
        roots.append(Root(id: id, access: access, location: location))
    }

    private func existing(_ url: URL, requiring mode: DirectoryAccess.Mode = .readOnly) -> DirectoryAccess? {
        let path = url.standardized.pathComponents
        return roots.compactMap(\.access).filter {
            path.starts(with: $0.root.pathComponents) && (mode == .readOnly || $0.mode == .readWrite)
        }.max {
            if $0.root.pathComponents.count == $1.root.pathComponents.count { return $0.mode == .readOnly && $1.mode == .readWrite }
            return $0.root.pathComponents.count < $1.root.pathComponents.count
        }
    }

    func location(for directory: URL) -> Location? {
        locations.last { $0.path == directory.path && $0.access != nil }?.location
    }

    private func active(_ id: UUID, requiring mode: DirectoryAccess.Mode) -> DirectoryAccess? {
        let matches = roots.filter { $0.id == id }.compactMap(\.access)
        return matches.first { $0.mode == .readWrite } ?? (mode == .readOnly ? matches.first : nil)
    }

    private func acquire(_ record: Record) async throws -> DirectoryAccess {
        if let access = active(record.id, requiring: record.mode ?? .readOnly) { return try await validated(access, expected: record.identity) }
        let resolve = bookmarking.resolve
        let resolution = try await Task.detached(priority: .userInitiated) { try resolve(record.data) }.value
        try Task.checkCancellation()
        guard BrowserState.acceptsDropSources([resolution.url]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        // Another pane may have acquired this bookmark while resolution was in flight.
        if let access = active(record.id, requiring: record.mode ?? .readOnly) { return try await validated(access, expected: record.identity) }
        guard bookmarking.start(resolution.url) else { throw CocoaError(.fileReadNoPermission) }
        let stop = stop
        let root = await Task.detached(priority: .userInitiated) { resolution.url.resolvingSymlinksInPath() }.value
        let access = DirectoryAccess(root: root, mode: record.mode ?? .readOnly) { stop(resolution.url) }
        _ = try await validated(access, expected: record.identity)
        if let existing = active(record.id, requiring: record.mode ?? .readOnly) { return try await validated(existing, expected: record.identity) }
        var data = record.data
        if resolution.stale {
            data = try await createBookmark(resolution.url, mode: record.mode ?? .readOnly)
            _ = try await validated(access, expected: record.identity)
            if let index = records.firstIndex(where: { $0.id == record.id && $0.data == record.data }) {
                records[index].data = data
                records[index].path = root.path
                persist()
            }
        }
        try Task.checkCancellation()
        if let existing = active(record.id, requiring: record.mode ?? .readOnly) { return try await validated(existing, expected: record.identity) }
        cache(access, id: record.id, data: data, identity: record.identity)
        return access
    }

    private func validated(_ access: DirectoryAccess, expected: Identity?) async throws -> DirectoryAccess {
        let identity = try await Task.detached(priority: .userInitiated) { try Identity.read(access.root) }.value
        guard let expected, identity == expected else { throw CocoaError(.fileReadNoPermission) }
        try Task.checkCancellation()
        return access
    }

    private func createBookmark(_ url: URL, mode: DirectoryAccess.Mode) async throws -> Data {
        let create = bookmarking.create
        return try await Task.detached(priority: .userInitiated) { try create(url, mode) }.value
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) { preferences?.set(data, forKey: Self.key) }
    }

    private func savedAccess(_ directory: URL, requiring mode: DirectoryAccess.Mode = .readOnly) async throws -> (DirectoryAccess, URL)? {
        if let access = existing(directory, requiring: mode) { return (access, directory) }
        let path = directory.standardized.pathComponents
        if let record = records.filter({ path.starts(with: URL(fileURLWithPath: $0.path).pathComponents) && (mode == .readOnly || $0.mode == .readWrite) })
            .max(by: { $0.path.count < $1.path.count }) {
            let access = try await acquire(record)
            let components = path.dropFirst(URL(fileURLWithPath: record.path).pathComponents.count)
            return (access, components.reduce(access.root) { $0.appendingPathComponent($1, isDirectory: true) })
        }
        // A remembered child can move with its granted parent while the root's path hint remains old.
        let resolve = bookmarking.resolve
        for record in records where mode == .readOnly || record.mode == .readWrite {
            try Task.checkCancellation()
            guard let resolved = try? await Task.detached(priority: .userInitiated, operation: { try resolve(record.data) }).value,
                  BrowserState.acceptsDropSources([resolved.url]),
                  path.starts(with: resolved.url.standardized.pathComponents) else { continue }
            let access = try await acquire(record)
            return (access, directory)
        }
        return nil
    }

    /// Reuse the captured source folder or request an explicit read-only parent grant.
    func readAccess(for directory: URL, choose: Choose? = nil) async throws -> DirectoryAccess {
        guard BrowserState.acceptsDropSources([directory]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        do {
            if let (access, target) = try await savedAccess(directory),
               target.standardized.path == directory.standardized.path { return access }
        } catch is CancellationError { throw CancellationError() }
        catch { if choose == nil { throw error } }
        guard let choose else { throw CocoaError(.fileReadNoPermission) }
        guard let access = try await select(initial: directory, mode: .readOnly, requiredDirectory: directory, choose: choose) else {
            throw CancellationError()
        }
        return access
    }

    /// Upgrade only through a remembered writable grant or a new containing-folder selection.
    func writeAccess(for directory: URL, choose: Choose) async throws -> DirectoryAccess? {
        guard BrowserState.acceptsDropSources([directory]) else { throw CocoaError(.fileWriteUnsupportedScheme) }
        do {
            if let (access, target) = try await savedAccess(directory, requiring: .readWrite),
               target.standardized.path == directory.standardized.path {
                return access
            }
        } catch is CancellationError { throw CancellationError() }
        catch { /* Unavailable saved access requires an explicit new grant. */ }
        return try await select(initial: directory, mode: .readWrite, requiredDirectory: directory, choose: choose)
    }

    /// Restores saved access without presenting permission UI or falling back to a different location.
    func readSaved(_ directory: URL, location: Location?) async throws -> DirectoryListing {
        guard BrowserState.acceptsDropSources([directory]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let access: DirectoryAccess
        let target: URL
        if let location {
            access = try await acquire(Record(id: location.id, path: directory.path, data: location.data, identity: location.identity, mode: location.mode))
            target = access.root
        } else {
            guard let saved = try await savedAccess(directory) else { throw CancellationError() }
            (access, target) = saved
        }
        let result = try await listing(target, access: access)
        if let location { _ = try await validated(access, expected: location.identity) }
        return result
    }

    /// Exact reads reconnect the requested location instead of choosing a replacement folder.
    func read(_ directory: URL, exact: Bool = false, choose: Choose) async throws -> DirectoryListing {
        guard BrowserState.acceptsDropSources([directory]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        var saved: (DirectoryAccess, URL)?
        do { saved = try await savedAccess(directory) }
        catch is CancellationError { throw CancellationError() }
        catch { saved = nil }
        var access: DirectoryAccess
        var target: URL
        if let saved { (access, target) = saved }
        else {
            guard let selected = try await select(initial: directory, requiredDirectory: exact ? directory : nil, choose: choose) else { throw CancellationError() }
            access = selected
            target = exact ? directory : selected.root
        }
        let requested = target
        let canonical = await Task.detached(priority: .userInitiated) { requested.resolvingSymlinksInPath() }.value
        if !canonical.pathComponents.starts(with: access.root.pathComponents) {
            if let saved = try await savedAccess(canonical) { (access, target) = saved }
            else {
                guard let selected = try await select(initial: canonical, requiredDirectory: exact ? canonical : nil, choose: choose) else { throw CancellationError() }
                access = selected
                target = exact ? canonical : selected.root
            }
        }
        return try await listing(target, access: access)
    }

    private func listing(_ target: URL, access: DirectoryAccess) async throws -> DirectoryListing {
        try Task.checkCancellation()
        let canonical = await Task.detached(priority: .userInitiated) { target.resolvingSymlinksInPath() }.value
        guard canonical.pathComponents.starts(with: access.root.pathComponents) else { throw CocoaError(.fileReadNoPermission) }
        let listing = try await DirectoryListing.read(canonical, followingLinks: false)
        guard listing.directory.pathComponents.starts(with: access.root.pathComponents) else { throw CocoaError(.fileReadNoPermission) }
        guard preferences != nil else {
            return DirectoryListing(directory: listing.directory, entries: listing.entries, access: access)
        }
        let identity = try await Task.detached(priority: .userInitiated) { try Identity.read(listing.directory) }.value
        let location: Location
        if listing.directory.path == access.root.path, let source = roots.last(where: { $0.access === access })?.location {
            guard source.identity == identity, source.mode == access.mode else { throw CocoaError(.fileReadNoPermission) }
            location = source
        } else {
            let data = try await createBookmark(listing.directory, mode: access.mode)
            location = Location(id: UUID(), data: data, identity: identity, mode: access.mode)
        }
        try Task.checkCancellation()
        let consumer = DirectoryAccess(root: access.root, mode: access.mode) { withExtendedLifetime(access) {} }
        locations.removeAll { $0.access == nil }
        locations.append(ListedLocation(path: listing.directory.path, location: location, access: consumer))
        return DirectoryListing(directory: listing.directory, entries: listing.entries, access: consumer)
    }

    func toggleFavourite(_ directory: URL, favourites: Favourites) {
        if favourites.contains(directory) { favourites.remove(directory); return }
        guard let location = location(for: directory), let data = try? JSONEncoder().encode(location) else { return }
        favourites.toggle(directory, bookmark: data)
    }

    func openFavourite(_ directory: URL, in pane: DirectoryPane, favourites: Favourites, choose: @escaping Choose) async {
        let data = favourites.bookmark(for: directory)
        let location = data.flatMap { try? JSONDecoder().decode(Location.self, from: $0) }
        let published = await pane.navigate(to: directory, using: { target in
            try await self.favouriteListing(target, location: location, pane: pane, choose: choose)
        })
        guard published, let current = self.location(for: pane.directory),
              let updated = try? JSONEncoder().encode(current) else { return }
        let matches: Bool
        if let identity = location?.identity { matches = current.identity == identity }
        else { matches = pane.directory.path == directory.path }
        if matches { favourites.updateLocation(directory, resolved: pane.directory, bookmark: updated, replacing: data) }
    }

    private func favouriteListing(_ directory: URL, location: Location?, pane: DirectoryPane, choose: Choose) async throws -> DirectoryListing {
        let request = pane.navigationRevision
        if let location {
            do { return try await readSaved(directory, location: location) }
            catch is CancellationError { throw CancellationError() }
            catch { /* Keep the saved record available for explicit reconnection. */ }
        }
        try Task.checkCancellation()
        guard pane.navigationRevision == request,
              let access = try await select(initial: directory, choose: choose) else { throw CancellationError() }
        return try await listing(access.root, access: access)
    }

    enum Purpose { case browsing, reading, editing, managing }

    static func chooseFolder(initial: URL, window: NSWindow?, purpose: Purpose = .browsing) async throws -> URL? {
        guard let window, window.attachedSheet == nil else { throw CancellationError() }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = initial
        switch purpose {
        case .browsing:
            panel.title = "Allow Folder Access"
            panel.message = "Choose a folder to let PanePeek browse and manage its files."
            panel.prompt = "Allow Access"
        case .reading:
            panel.title = "Allow Reading"
            panel.message = "Choose this folder or a parent folder to allow copying its files."
            panel.prompt = "Allow Reading"
        case .editing:
            panel.title = "Allow Editing"
            panel.message = "Choose this file’s containing folder or a parent folder to allow editing and saving."
            panel.prompt = "Allow Editing"
        case .managing:
            panel.title = "Allow Changes"
            panel.message = "Choose this folder or a parent folder to allow changes to its files."
            panel.prompt = "Allow Changes"
        }
        let response = await panel.beginSheetModal(for: window)
        return response == .OK ? panel.url : nil
    }
}
