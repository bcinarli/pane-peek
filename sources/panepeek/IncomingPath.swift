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
    private let saveBaseline: UUID?
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

        func matches(_ snapshot: TextFileSnapshot) -> Bool {
            type == S_IFREG && snapshot.identifiesFile(device: device, inode: file)
        }
    }

    @MainActor static func prepare(_ request: IncomingRequest, access: FolderAccess?,
                                   readSave: @MainActor () async throws -> BrowserState.ExternalOpenSave? = { nil },
                                   choose: @escaping FolderAccess.Choose) async throws -> IncomingPath {
        let url = request.url
        guard BrowserState.acceptsDropSources([url]) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let started = request.carriesNativeAccess && url.startAccessingSecurityScopedResource()
        let nativeScope = started ? DirectoryAccess(root: url) { url.stopAccessingSecurityScopedResource() } : nil
        // File access alone never grants a containing-directory listing.
        let observed = try? await classify(url)
        let reveal = request.intent == .reveal && url.path != "/"
        let ordinaryDirectory = observed?.isBrowsableDirectory == true
        let parent = ordinaryDirectory && !reveal ? url : url.deletingLastPathComponent()
        let grant: DirectoryAccess?
        if let access {
            let nativeDirectory = request.carriesNativeAccess && ordinaryDirectory && !reveal ? url : nil
            grant = try await access.incomingAccess(for: parent, nativeDirectory: nativeDirectory, choose: choose)
        } else { grant = nil }
        let captured: (identity: Identity, isBrowsableDirectory: Bool)
        if let observed { captured = observed }
        else { captured = try await classify(url) }
        let requiredDirectoryIdentity = request.requiresDirectory ? try await inspect(url, following: true) : nil
        if let requiredDirectoryIdentity, requiredDirectoryIdentity.type != S_IFDIR { throw POSIXError(.ENOTDIR) }
        let browseDirectory: Bool
        if reveal { browseDirectory = false }
        else if captured.identity.type == S_IFLNK {
            browseDirectory = (try? await classify(url, resolvingLinks: true))?.isBrowsableDirectory == true
        } else {
            browseDirectory = captured.isBrowsableDirectory
        }
        let directory = browseDirectory ? url : parent
        func read(_ save: BrowserState.ExternalOpenSave?) async throws -> IncomingPath {
            let current = try await inspect(url)
            let saved = save.flatMap { current.matches($0.after) ? $0 : nil }
            guard current == captured.identity || saved.map({ captured.identity.matches($0.before) }) == true else {
                throw CocoaError(.fileReadUnknown)
            }
            let listing: DirectoryListing
            if let access, let grant { listing = try await access.incomingListing(directory, access: grant, choose: choose) }
            else { listing = try await DirectoryListing.read(directory) }
            let selection: URL?
            if !browseDirectory {
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
            let verifiedSave = saved.flatMap { selection?.path == $0.url.path ? $0 : nil }
            guard current == captured.identity || verifiedSave != nil else { throw CocoaError(.fileReadUnknown) }
            let directoryIdentity = try await inspect(listing.directory)
            let result = IncomingPath(url: url, listing: listing, selection: selection, identity: captured.identity,
                                      directoryIdentity: directoryIdentity, requiredDirectoryIdentity: requiredDirectoryIdentity,
                                      saveBaseline: verifiedSave?.baseline, nativeScope: nativeScope)
            try await result.validate(identifying: current, saved: verifiedSave?.after)
            return result
        }

        var save = try await readSave()
        while true {
            do { return try await read(save) }
            catch is CancellationError { throw CancellationError() }
            catch {
                guard let latest = try await readSave(), latest.revision != save?.revision else { throw error }
                save = latest
            }
        }
    }

    @MainActor static func prepare(_ url: URL, access: FolderAccess?, choose: @escaping FolderAccess.Choose) async throws -> IncomingPath {
        try await prepare(.native(url), access: access, choose: choose)
    }

    private static func inspect(_ url: URL, following: Bool = false) async throws -> Identity {
        try await Task.detached(priority: .userInitiated) { try Identity(url, following: following) }.value
    }

    private static func classify(_ url: URL, resolvingLinks: Bool = false) async throws -> (identity: Identity, isBrowsableDirectory: Bool) {
        try await Task.detached(priority: .userInitiated) {
            let item = resolvingLinks ? url.resolvingSymlinksInPath() : url
            let identity = try Identity(item)
            let isBrowsableDirectory = identity.type == S_IFDIR && (try? item.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true
            return (identity, isBrowsableDirectory)
        }.value
    }

    func validate() async throws { try await validate(identifying: identity) }

    /// Retain the same expected identity for the listing read and the final publication check.
    func listingForOpen(after save: BrowserState.ExternalOpenSave?, refresh: Bool, access: FolderAccess?) async throws -> BrowserState.ExternalOpenListing {
        let expected: Identity
        let saved: TextFileSnapshot?
        if let save, let selection, selection.path == save.url.path,
           identity.matches(save.before) || saveBaseline == save.baseline {
            let replacement = try await Self.inspect(selection)
            guard replacement.matches(save.after) else {
                throw CocoaError(.fileReadUnknown)
            }
            expected = replacement
            saved = save.after
        } else {
            expected = identity
            saved = nil
        }
        try await validate(identifying: expected)
        let prepared: DirectoryListing
        if refresh || saved != nil {
            if let access, let grant = listing.access {
                prepared = try await access.incomingListing(listing.directory, access: grant) { _ in
                    throw CocoaError(.fileReadNoPermission)
                }
            } else {
                prepared = try await DirectoryListing.read(listing.directory)
            }
            guard prepared.directory == listing.directory,
                  selection == nil || prepared.entries.contains(where: { $0.url == selection }) else { throw CocoaError(.fileReadUnknown) }
        } else {
            prepared = listing
        }
        return BrowserState.ExternalOpenListing(prepared) { try await validate(identifying: expected, saved: saved) }
    }

    private func validate(identifying identity: Identity, saved: TextFileSnapshot? = nil) async throws {
        try Task.checkCancellation()
        try await Task.detached(priority: .userInitiated) {
            defer { withExtendedLifetime(nativeScope) {} }
            guard try Identity(url) == identity, try Identity(listing.directory) == directoryIdentity else {
                throw CocoaError(.fileReadUnknown)
            }
            if let selection {
                guard try Identity(selection) == identity else { throw CocoaError(.fileReadUnknown) }
                try saved?.validate(selection)
            }
            if let requiredDirectoryIdentity, try Identity(url, following: true) != requiredDirectoryIdentity {
                throw CocoaError(.fileReadUnknown)
            }
        }.value
        try Task.checkCancellation()
    }
}
