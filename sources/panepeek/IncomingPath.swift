import Foundation
import Darwin
import PanePeekCore

/// Keeps the requested item and authorised access through guarded navigation.
struct IncomingPath: Sendable {
    let url: URL
    let listing: DirectoryListing
    let selection: URL?
    private let identity: Identity
    private let directoryIdentity: Identity
    private let requiredDirectoryIdentity: Identity?
    private let nativeScope: DirectoryAccess?

    private struct Identity: Equatable, Sendable {
        let device: dev_t
        let file: ino_t
        let type: mode_t

        init(_ url: URL, following: Bool = false) throws {
            var value = stat()
            let code = url.withUnsafeFileSystemRepresentation { name in
                guard let name else { return EINVAL }
                let result = following ? fstatat(AT_FDCWD, name, &value, 0) : lstat(name, &value)
                return result == 0 ? 0 : errno
            }
            guard code == 0 else { throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO) }
            device = value.st_dev
            file = value.st_ino
            type = value.st_mode & S_IFMT
        }
    }

    @MainActor static func prepare(_ request: IncomingRequest, access: FolderAccess?, choose: @escaping FolderAccess.Choose) async throws -> IncomingPath {
        let url = request.url
        guard BrowserState.acceptsDropSources([url]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let started = request.carriesNativeAccess && url.startAccessingSecurityScopedResource()
        let nativeScope = started ? DirectoryAccess(root: url) { url.stopAccessingSecurityScopedResource() } : nil
        // File access alone never grants a containing-directory listing.
        let observed = try? await inspect(url)
        let reveal = request.intent == .reveal && url.path != "/"
        let ordinaryDirectory = observed?.type == S_IFDIR && (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true
        let parent = ordinaryDirectory && !reveal ? url : url.deletingLastPathComponent()
        let grant: DirectoryAccess?
        if let access {
            let nativeDirectory = request.carriesNativeAccess && ordinaryDirectory && !reveal ? url : nil
            grant = try await access.incomingAccess(for: parent, nativeDirectory: nativeDirectory, choose: choose)
        } else { grant = nil }
        let current = try await inspect(url)
        if let observed, observed != current { throw CocoaError(.fileReadUnknown) }
        let requiredDirectoryIdentity = request.requiresDirectory ? try await inspect(url, following: true) : nil
        if let requiredDirectoryIdentity, requiredDirectoryIdentity.type != S_IFDIR { throw POSIXError(.ENOTDIR) }
        var directory = parent
        var selectsItem = reveal || !ordinaryDirectory
        if !reveal && current.type == S_IFLNK {
            let canonical = await Task.detached(priority: .userInitiated) { url.resolvingSymlinksInPath() }.value
            if let target = try? await inspect(canonical), target.type == S_IFDIR,
               (try? canonical.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true {
                directory = url
                selectsItem = false
            }
        } else if !reveal && current.type == S_IFDIR && !ordinaryDirectory,
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
                                  directoryIdentity: directoryIdentity, requiredDirectoryIdentity: requiredDirectoryIdentity,
                                  nativeScope: nativeScope)
        try await result.validate()
        return result
    }

    @MainActor static func prepare(_ url: URL, access: FolderAccess?, choose: @escaping FolderAccess.Choose) async throws -> IncomingPath {
        try await prepare(.native(url), access: access, choose: choose)
    }

    private static func inspect(_ url: URL, following: Bool = false) async throws -> Identity {
        try await Task.detached(priority: .userInitiated) { try Identity(url, following: following) }.value
    }

    func validate() async throws {
        try Task.checkCancellation()
        guard try await Self.inspect(url) == identity else { throw CocoaError(.fileReadUnknown) }
        guard try await Self.inspect(listing.directory) == directoryIdentity else { throw CocoaError(.fileReadUnknown) }
        if let selection, try await Self.inspect(selection) != identity { throw CocoaError(.fileReadUnknown) }
        if let requiredDirectoryIdentity, try await Self.inspect(url, following: true) != requiredDirectoryIdentity {
            throw CocoaError(.fileReadUnknown)
        }
        withExtendedLifetime(nativeScope) {}
    }
}
