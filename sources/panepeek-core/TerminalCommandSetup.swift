import Darwin
import Foundation

/// Installs the bundled launcher and optionally configures the zsh login profile.
public struct TerminalCommandSetup: Sendable {
    public enum Status: Equatable, Sendable {
        case absent, launcherOnly, installed, profileOnly, moved, staleLink, unverifiedStaleLink, conflict
        case profileUnavailable(launcherInstalled: Bool)
        case profileNeedsAttention(launcherInstalled: Bool)
    }

    public enum RemovalResult: Equatable, Sendable { case complete, profileNeedsAttention }

    public struct Ownership: Codable, Sendable {
        fileprivate let target: String
        fileprivate let app: Identity
        // Earlier receipts came from installations that always managed .zprofile.
        fileprivate let managesProfile: Bool?
        fileprivate let linkIdentity: LinkIdentity?
    }

    public enum Failure: LocalizedError {
        case conflict, profile, profileWrite, moved, launcher, partialInstall, partialRemoval
        public var errorDescription: String? {
            switch self {
            case .conflict: "Another item is using the command location. PanePeek has left it untouched."
            case .profile: "PanePeek can only update a regular UTF-8 .zprofile file. Your profile has been left untouched."
            case .profileWrite: "PanePeek couldn’t update .zprofile. Check its permissions or recent edits and try again."
            case .moved: "Remove the old command before installing it for this app location."
            case .launcher: "The bundled command is unavailable. Open an installed copy of PanePeek and try again."
            case .partialInstall: "Installation did not finish. Check the command status before trying again."
            case .partialRemoval: "Removal did not finish. Check the command status before trying again."
            }
        }
    }

    public let home: URL
    public let app: URL
    public var command: URL { Self.folders.reduce(home) { $0.appendingPathComponent($1, isDirectory: true) }.appendingPathComponent(Self.name) }
    public var profile: URL { home.appendingPathComponent(".zprofile") }
    public var launcher: URL { app.appendingPathComponent("Contents/Resources/panepeek") }

    /// PATH entry for using an installed launcher from a separate shell profile.
    public var manualPathEntry: String? { (try? editor())?.pathEntry }

    private static let folders = ["Library", "Application Support", "PanePeek", "bin"]
    private static let name = "panepeek"

    public init(home: URL, app: URL) { self.home = home; self.app = app }

    public func status(ownership: Ownership?) async throws -> Status {
        try await Task.detached(priority: .userInitiated) {
            let entry = try link(in: directory(create: false))
            if let entry, try !owns(entry, receipt: ownership) {
                guard let ownership, hasRecordedTarget(entry, receipt: ownership), Self.targetIsMissing(ownership.target) else { return .conflict }
                return entry.identity == ownership.linkIdentity ? .staleLink : .unverifiedStaleLink
            }
            if let entry, entry.target != launcher.path { return .moved }
            do {
                let text = try await readProfile().text
                let configured = try editor().installing(in: text) == text
                if entry != nil { return configured ? .installed : .launcherOnly }
                return configured ? .profileOnly : .absent
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if let entry {
                    return managesProfile(ownership: ownership, entry: entry)
                        ? .profileNeedsAttention(launcherInstalled: true) : .profileUnavailable(launcherInstalled: true)
                }
                if let ownership, ownership.managesProfile != false,
                   ownership.target == launcher.path || (try? appIdentity()) == ownership.app {
                    return .profileNeedsAttention(launcherInstalled: false)
                }
                return .profileUnavailable(launcherInstalled: false)
            }
        }.value
    }

    public func install(ownership: Ownership?, configureZsh: Bool = false) async throws -> Ownership {
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) {
            var attributes = stat()
            guard lstat(launcher.path, &attributes) == 0, attributes.st_mode & S_IFMT == S_IFREG,
                  access(launcher.path, X_OK) == 0 else { throw Failure.launcher }
            // The profile points to the shared command directory, so it stays owned across app copies.
            let retainedProfile = ownership.map { $0.managesProfile != false } ?? false
            let managesProfile = configureZsh || retainedProfile
            let target = launcher.path
            let installationApp = try appIdentity()
            if let existing = try link(in: directory(create: false)) {
                guard try owns(existing, receipt: ownership) else { throw Failure.conflict }
                guard existing.target == target else { throw Failure.moved }
            }
            let profileUpdate: (original: Profile, updated: String)?
            if configureZsh {
                let current = try await readProfile()
                profileUpdate = (current, try editor().installing(in: current.text))
            } else {
                profileUpdate = nil
            }
            guard let parent = try directory(create: true) else { throw Failure.conflict }
            var created: Link?
            let recordedLink: LinkIdentity?
            if let existing = try link(in: parent) {
                guard existing.target == target else { throw Failure.conflict }
                // A same-target link can predate the installation record.
                recordedLink = ownership.flatMap {
                    hasRecordedTarget(existing, receipt: $0) && existing.identity == $0.linkIdentity ? existing.identity : nil
                }
            } else {
                guard symlinkat(target, parent.fileDescriptor, Self.name) == 0 else {
                    throw errno == EEXIST ? Failure.conflict : Self.posixError()
                }
                guard let entry = try? link(in: parent), entry.target == target else { throw Failure.partialInstall }
                created = entry
                recordedLink = entry.identity.birthSeconds == 0 && entry.identity.birthNanoseconds == 0 ? nil : entry.identity
            }
            do {
                if let profileUpdate { try await saveProfile(profileUpdate.updated, from: profileUpdate.original) }
            } catch {
                if let created {
                    do { try remove(created, in: parent) }
                    catch { throw Failure.partialInstall }
                }
                throw error
            }
            return Ownership(target: target, app: installationApp, managesProfile: managesProfile, linkIdentity: recordedLink)
        }.value
    }

    /// Remove a verified link from another copy after rechecking its recorded target.
    public func removeStaleLink(ownership: Ownership?) async throws {
        try Task.checkCancellation()
        try await Task.detached(priority: .userInitiated) {
            guard let parent = try directory(create: false), let entry = try link(in: parent) else { return }
            guard let ownership, hasRecordedTarget(entry, receipt: ownership), entry.identity == ownership.linkIdentity,
                  try !owns(entry, receipt: ownership) else { throw Failure.conflict }
            try remove(entry, in: parent, missingTarget: ownership.target)
        }.value
    }

    @discardableResult public func uninstall(ownership: Ownership?) async throws -> RemovalResult {
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) {
            let parent = try directory(create: false)
            let entry = try link(in: parent)
            if let entry, try !owns(entry, receipt: ownership) { throw Failure.conflict }
            if let parent, let entry {
                do { try remove(entry, in: parent) }
                catch { throw Failure.partialRemoval }
            }
            guard managesProfile(ownership: ownership, entry: entry) else { return RemovalResult.complete }
            do {
                let current = try await readProfile()
                let updated = try editor().removing(from: current.text)
                guard updated != current.text else { return .complete }
                guard try link(in: directory(create: false)) == nil else { return .profileNeedsAttention }
                try await saveProfile(updated, from: current)
                return .complete
            } catch {
                return .profileNeedsAttention
            }
        }.value
    }

    fileprivate struct Identity: Codable, Sendable, Equatable {
        let device: dev_t
        let inode: ino_t
        init(_ attributes: stat) { device = attributes.st_dev; inode = attributes.st_ino }
    }
    fileprivate struct LinkIdentity: Codable, Sendable, Equatable {
        let file: Identity
        let birthSeconds: Int
        let birthNanoseconds: Int

        init(_ attributes: stat) {
            file = Identity(attributes)
            birthSeconds = attributes.st_birthtimespec.tv_sec
            birthNanoseconds = attributes.st_birthtimespec.tv_nsec
        }
    }
    private struct Link: Equatable {
        let identity: LinkIdentity
        let target: String?
    }

    private func hasRecordedTarget(_ entry: Link, receipt: Ownership) -> Bool {
        entry.target?.utf8.elementsEqual(receipt.target.utf8) == true
    }

    private static func targetIsMissing(_ target: String) -> Bool {
        guard target.hasPrefix("/"), !target.contains("\0") else { return false }
        var attributes = stat()
        return lstat(target, &attributes) == -1 && errno == ENOENT
    }

    private func managesProfile(ownership: Ownership?, entry: Link?) -> Bool {
        guard let ownership, ownership.managesProfile == false else { return true }
        guard let entry else { return false }
        return entry.target != ownership.target
    }

    private func owns(_ entry: Link, receipt: Ownership?) throws -> Bool {
        if entry.target == launcher.path { return true }
        guard let receipt, entry.target == receipt.target else { return false }
        return try appIdentity() == receipt.app
    }

    private func appIdentity() throws -> Identity {
        var attributes = stat()
        guard fstatat(AT_FDCWD, app.path, &attributes, 0) == 0 else { throw Failure.launcher }
        return Identity(attributes)
    }

    private func directory(create: Bool) throws -> FileHandle? {
        let flags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        let root = Darwin.open(home.path, flags)
        guard root >= 0 else { throw Self.posixError() }
        var parent = FileHandle(fileDescriptor: root, closeOnDealloc: true)
        // Walk from the granted folder without following a replacement directory link.
        for component in Self.folders {
            var next = openat(parent.fileDescriptor, component, flags)
            if next < 0, errno == ENOENT {
                guard create else { return nil }
                guard mkdirat(parent.fileDescriptor, component, 0o700) == 0 || errno == EEXIST else { throw Self.posixError() }
                next = openat(parent.fileDescriptor, component, flags)
            }
            guard next >= 0 else {
                if errno == ENOTDIR || errno == ELOOP { throw Failure.conflict }
                throw Self.posixError()
            }
            parent = FileHandle(fileDescriptor: next, closeOnDealloc: true)
        }
        return parent
    }

    private func link(in parent: FileHandle?) throws -> Link? {
        guard let parent else { return nil }
        let descriptor = parent.fileDescriptor
        var attributes = stat()
        guard fstatat(descriptor, Self.name, &attributes, AT_SYMLINK_NOFOLLOW) == 0 else {
            if errno == ENOENT { return nil }
            throw Self.posixError()
        }
        let identity = LinkIdentity(attributes)
        guard attributes.st_mode & S_IFMT == S_IFLNK else { return Link(identity: identity, target: nil) }
        var bytes = [UInt8](repeating: 0, count: Int(PATH_MAX))
        let count = bytes.withUnsafeMutableBytes { readlinkat(descriptor, Self.name, $0.baseAddress, $0.count) }
        guard count >= 0 else { throw Self.posixError() }
        guard fstatat(descriptor, Self.name, &attributes, AT_SYMLINK_NOFOLLOW) == 0,
              LinkIdentity(attributes) == identity else { throw Failure.conflict }
        let target = count < bytes.count ? String(bytes: bytes.prefix(count), encoding: .utf8) : nil
        return Link(identity: identity, target: target)
    }

    private func remove(_ expected: Link, in parent: FileHandle, missingTarget: String? = nil) throws {
        guard let current = try link(in: parent) else { return }
        guard current == expected else { throw Failure.conflict }
        if let missingTarget, !Self.targetIsMissing(missingTarget) { throw Failure.conflict }
        guard unlinkat(parent.fileDescriptor, Self.name, 0) == 0 else { throw Self.posixError() }
    }

    private struct Profile {
        let text: String
        let snapshot: TextFileSnapshot?
    }

    private func editor() throws -> TerminalProfile { try TerminalProfile(directory: command.deletingLastPathComponent()) }

    private func readProfile() async throws -> Profile {
        var attributes = stat()
        guard lstat(profile.path, &attributes) == 0 else {
            if errno == ENOENT { return Profile(text: "", snapshot: nil) }
            throw Self.posixError()
        }
        guard attributes.st_mode & S_IFMT == S_IFREG else { throw Failure.profile }
        let loaded = try await TextPreview.load(DirectoryEntry(url: profile, isDirectory: false), followingLinks: false)
        guard case let .text(text, editable: true) = loaded.preview, let snapshot = loaded.snapshot else { throw Failure.profile }
        return Profile(text: text, snapshot: snapshot)
    }

    private func saveProfile(_ updated: String, from current: Profile) async throws {
        guard Data(updated.utf8) != Data(current.text.utf8) else { return }
        do {
            if let snapshot = current.snapshot {
                _ = try await snapshot.save(updated, to: profile, quarantine: .systemManaged)
                return
            }
            // Publish a new profile only if one has not appeared since inspection.
            var staging = Array(home.appendingPathComponent(".panepeek-profile-XXXXXX").path.utf8CString)
            let descriptor = mkstemp(&staging)
            guard descriptor >= 0 else { throw Self.posixError() }
            let path = staging.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            var published = false
            defer {
                try? handle.close()
                if !published { unlink(path) }
            }
            try handle.write(contentsOf: Data(updated.utf8))
            guard fsync(descriptor) == 0, renamex_np(path, profile.path, UInt32(RENAME_EXCL)) == 0 else { throw Self.posixError() }
            published = true
        } catch { throw Failure.profileWrite }
    }

    private static func posixError() -> POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}
