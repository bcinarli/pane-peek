import Darwin
import Foundation

/// Captures listed link identity and the directories used by one copy request.
public struct ItemCopy: Sendable {
    public let source: URL
    public let destination: URL
    public let isDirectory: Bool
    private let sourceIdentity: Identity
    private let parentIdentity: Identity
    private let destinationIdentity: Identity

    public struct Outcome: Identifiable, Sendable {
        public let id = UUID()
        public let succeeded: Bool
        public let message: String
    }

    public enum CopyError: LocalizedError, Equatable {
        case ancestry, changedItem
        public var errorDescription: String? {
            switch self {
            case .ancestry: "A folder cannot be copied into itself or a descendant. Choose another destination."
            case .changedItem: "The source or one of the captured directories changed. Refresh and try Copy again."
            }
        }
    }

    /// Preflight before prompting for affected drafts, without following the final source link.
    public static func capture(_ source: URL, to directory: URL) async throws -> ItemCopy {
        try await Task.detached(priority: .userInitiated) {
            guard source.isFileURL, directory.isFileURL else { throw POSIXError(.EINVAL) }
            let parent = source.deletingLastPathComponent().resolvingSymlinksInPath()
            let source = parent.appendingPathComponent(source.lastPathComponent)
            let identity = try Identity.read(source)
            guard [mode_t(S_IFREG), mode_t(S_IFDIR), mode_t(S_IFLNK)].contains(identity.kind) else {
                throw POSIXError(.ENOTSUP)
            }
            let directory = directory.resolvingSymlinksInPath()
            let destinationIdentity = try Identity.read(directory)
            guard destinationIdentity.kind == mode_t(S_IFDIR) else { throw POSIXError(.ENOTDIR) }
            let isDirectory = identity.kind == mode_t(S_IFDIR)
            if isDirectory, directory.path == source.path || directory.path.hasPrefix(source.path + "/") {
                throw CopyError.ancestry
            }
            let request = ItemCopy(source: source, destination: directory.appendingPathComponent(source.lastPathComponent),
                                   isDirectory: isDirectory, sourceIdentity: identity,
                                   parentIdentity: try Identity.read(parent), destinationIdentity: destinationIdentity)
            try request.validate()
            return request
        }.value
    }

    public func affects(_ url: URL) -> Bool {
        url.path == source.path || (isDirectory && url.path.hasPrefix(source.path + "/"))
    }

    /// An explicit Save changes the inode; accept only the saved document's verified baseline.
    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemCopy {
        try await Task.detached(priority: .userInitiated) {
            try validateParents()
            guard let snapshot else { throw CopyError.changedItem }
            try snapshot.validate(source)
            return ItemCopy(source: source, destination: destination, isDirectory: isDirectory,
                            sourceIdentity: try Identity.read(source), parentIdentity: parentIdentity,
                            destinationIdentity: destinationIdentity)
        }.value
    }

    /// Copies away from the UI actor. A failed copy may leave a partial destination for inspection.
    public func copy() async -> Outcome {
        await copy(using: { try FileManager.default.copyItem(at: $0, to: $1) })
    }

    func copy(using write: @escaping @Sendable (URL, URL) throws -> Void) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            var started = false
            do {
                try validate()
                started = true
                try write(source, destination)
                return Outcome(succeeded: true, message: "Copied \(source.path) to \(destination.path).")
            } catch {
                let incomplete = started && (try? Identity.read(destination)) != nil
                    ? " A destination item exists at \(destination.path) and may be incomplete. Inspect it before retrying." : ""
                return Outcome(succeeded: false,
                               message: "Couldn’t copy \(source.path) to \(destination.path). \(error.localizedDescription)\(incomplete)")
            }
        }.value
    }

    private func validateParents() throws {
        guard try Identity.read(source.deletingLastPathComponent()) == parentIdentity,
              try Identity.read(destination.deletingLastPathComponent()) == destinationIdentity else { throw CopyError.changedItem }
    }

    private func validate() throws {
        try validateParents()
        guard try Identity.read(source) == sourceIdentity else { throw CopyError.changedItem }
        var occupied = stat()
        if lstat(destination.path, &occupied) == 0 { throw ItemName.ValidationError.collision }
        guard errno == ENOENT else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    private struct Identity: Sendable, Equatable {
        let device: dev_t
        let inode: ino_t
        let kind: mode_t
        static func read(_ url: URL) throws -> Identity {
            var attributes = stat()
            guard lstat(url.path, &attributes) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            return Identity(device: attributes.st_dev, inode: attributes.st_ino, kind: attributes.st_mode & mode_t(S_IFMT))
        }
    }
}
