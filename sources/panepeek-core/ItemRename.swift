import Darwin
import Foundation

/// Captures the listed item, retaining link identity and rejecting a replaced source.
public struct ItemRename: Sendable {
    public let source: URL
    public let isDirectory: Bool
    private let identity: Identity
    private let parentIdentity: Identity

    public enum RenameError: LocalizedError, Equatable {
        case changedSource

        public var errorDescription: String? {
            "The item or its containing directory changed. Refresh and try Rename again."
        }
    }

    public static func capture(_ source: URL, matching snapshot: TextFileSnapshot? = nil) async throws -> ItemRename {
        try await Task.detached(priority: .userInitiated) {
            guard source.isFileURL else { throw POSIXError(.EINVAL) }
            let parent = source.deletingLastPathComponent().resolvingSymlinksInPath()
            let url = parent.appendingPathComponent(source.lastPathComponent)
            let descriptor = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard descriptor >= 0 else { throw posixError() }
            defer { close(descriptor) }
            var parentAttributes = stat()
            var attributes = stat()
            guard fstat(descriptor, &parentAttributes) == 0,
                  fstatat(descriptor, url.lastPathComponent, &attributes, AT_SYMLINK_NOFOLLOW) == 0 else { throw posixError() }
            try snapshot?.validate(url)
            let isDirectory = attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR)
            return ItemRename(source: parent.appendingPathComponent(url.lastPathComponent, isDirectory: isDirectory),
                              isDirectory: isDirectory, identity: Identity(attributes), parentIdentity: Identity(parentAttributes))
        }.value
    }

    /// Preflight names and collisions before resolving an affected dirty document.
    public func destination(named name: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let descriptor = try openParent()
            defer { close(descriptor) }
            return try validatedDestination(name, in: descriptor)
        }.value
    }

    /// Renames in the same directory using the filesystem's exclusive operation.
    public func rename(to name: String) async throws -> URL {
        let worker = Task.detached(priority: .userInitiated) {
            let descriptor = try openParent()
            defer { close(descriptor) }
            let destination = try validatedDestination(name, in: descriptor)
            if source.lastPathComponent.utf8.elementsEqual(name.utf8) { return source }
            try Task.checkCancellation()
            guard renameatx_np(descriptor, source.lastPathComponent, descriptor, name, UInt32(RENAME_EXCL)) == 0 else {
                if errno == EEXIST { throw ItemName.ValidationError.collision }
                throw Self.posixError()
            }
            return destination
        }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    public func affects(_ url: URL) -> Bool {
        url.path == source.path || (isDirectory && url.path.hasPrefix(source.path + "/"))
    }

    /// Rebases listed descendants; renaming a link never relocates its target.
    public func relocated(_ url: URL, to destination: URL) -> URL {
        guard affects(url) else { return url }
        let suffix = String(url.path.dropFirst(source.path.count))
        return URL(fileURLWithPath: destination.path + suffix, isDirectory: url.hasDirectoryPath)
    }

    private func openParent() throws -> Int32 {
        let descriptor = open(source.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw Self.posixError() }
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0, Identity(attributes) == parentIdentity else {
            close(descriptor)
            throw RenameError.changedSource
        }
        return descriptor
    }

    private func validatedDestination(_ name: String, in descriptor: Int32) throws -> URL {
        try ItemName.validate(name)
        var original = stat()
        guard fstatat(descriptor, source.lastPathComponent, &original, AT_SYMLINK_NOFOLLOW) == 0,
              Identity(original) == identity else { throw RenameError.changedSource }
        let destination = source.deletingLastPathComponent().appendingPathComponent(name, isDirectory: isDirectory)
        if source.lastPathComponent.utf8.elementsEqual(name.utf8) { return destination }
        var occupied = stat()
        if fstatat(descriptor, name, &occupied, AT_SYMLINK_NOFOLLOW) == 0 {
            let names = try FileManager.default.contentsOfDirectory(atPath: source.deletingLastPathComponent().path)
            guard Identity(occupied) == identity,
                  !names.contains(where: { $0.utf8.elementsEqual(name.utf8) }) else { throw ItemName.ValidationError.collision }
        } else if errno != ENOENT {
            throw Self.posixError()
        }
        return destination
    }

    private struct Identity: Sendable, Equatable {
        let device: dev_t
        let inode: ino_t
        let kind: mode_t

        init(_ attributes: stat) {
            device = attributes.st_dev
            inode = attributes.st_ino
            kind = attributes.st_mode & mode_t(S_IFMT)
        }
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
