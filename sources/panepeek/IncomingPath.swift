import Foundation
import Darwin
import PanePeekCore

/// Keeps a native URL and the access used to inspect it through guarded navigation.
struct IncomingPath: Sendable {
    let url: URL
    let listing: DirectoryListing
    let selection: URL?
    private let identity: Identity
    private let directoryIdentity: Identity
    private let nativeScope: DirectoryAccess?

    private struct Identity: Equatable, Sendable {
        let device: dev_t
        let file: ino_t
        let type: mode_t

        init(_ url: URL) throws {
            var value = stat()
            guard url.withUnsafeFileSystemRepresentation({ lstat($0!, &value) }) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            device = value.st_dev
            file = value.st_ino
            type = value.st_mode & S_IFMT
        }
    }

    @MainActor static func prepare(_ url: URL, access: FolderAccess?, choose: @escaping FolderAccess.Choose) async throws -> IncomingPath {
        guard BrowserState.acceptsDropSources([url]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let started = url.startAccessingSecurityScopedResource()
        let nativeScope = started ? DirectoryAccess(root: url) { url.stopAccessingSecurityScopedResource() } : nil
        // File access alone never grants a containing-directory listing.
        let observed = try? await inspect(url)
        let ordinaryDirectory = observed?.type == S_IFDIR && (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true
        let parent = ordinaryDirectory ? url : url.deletingLastPathComponent()
        let grant: DirectoryAccess?
        if let access {
            grant = try await access.incomingAccess(for: parent, nativeDirectory: ordinaryDirectory ? url : nil, choose: choose)
        } else { grant = nil }
        let current = try await inspect(url)
        if let observed, observed != current { throw CocoaError(.fileReadUnknown) }
        var directory = parent
        var selectsItem = !ordinaryDirectory
        if current.type == S_IFLNK {
            let canonical = await Task.detached(priority: .userInitiated) { url.resolvingSymlinksInPath() }.value
            if let target = try? await inspect(canonical), target.type == S_IFDIR,
               (try? canonical.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true {
                directory = url
                selectsItem = false
            }
        } else if current.type == S_IFDIR && !ordinaryDirectory,
                  (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true {
            directory = url
            selectsItem = false
        }
        let listing: DirectoryListing
        if let access, let grant { listing = try await access.incomingListing(directory, access: grant, choose: choose) }
        else { listing = try await DirectoryListing.read(directory) }
        let selection: URL?
        if selectsItem {
            // Canonicalise ancestors only. The requested link or hard-link name is the selected entry.
            let named = listing.entries.filter { $0.name == url.lastPathComponent }
            let candidates = named.isEmpty ? listing.entries.filter {
                $0.name.compare(url.lastPathComponent, options: [.caseInsensitive, .literal]) == .orderedSame
            } : named
            let matches = await Task.detached(priority: .userInitiated) {
                candidates.filter { (try? Identity($0.url)) == current }
            }.value
            guard matches.count == 1, let item = matches.first else { throw CocoaError(.fileReadNoSuchFile) }
            selection = item.url
        } else { selection = nil }
        let directoryIdentity = try await inspect(listing.directory)
        let result = IncomingPath(url: url, listing: listing, selection: selection, identity: current,
                                  directoryIdentity: directoryIdentity, nativeScope: nativeScope)
        try await result.validate()
        return result
    }

    private static func inspect(_ url: URL) async throws -> Identity {
        try await Task.detached(priority: .userInitiated) { try Identity(url) }.value
    }

    func validate() async throws {
        try Task.checkCancellation()
        guard try await Self.inspect(url) == identity else { throw CocoaError(.fileReadUnknown) }
        guard try await Self.inspect(listing.directory) == directoryIdentity else { throw CocoaError(.fileReadUnknown) }
        if let selection, try await Self.inspect(selection) != identity { throw CocoaError(.fileReadUnknown) }
        withExtendedLifetime(nativeScope) {}
    }
}
