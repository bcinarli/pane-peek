import Darwin
import Foundation

/// The bytes and file identity read with a document, used to reject obsolete saves.
public struct TextFileSnapshot: Sendable {
    public enum QuarantinePolicy: Sendable, Equatable { case preserveExisting, systemManaged }
    private let bytes: Data
    private let version: Version

    init(bytes: Data, attributes: stat) {
        self.bytes = bytes
        version = Version(attributes)
    }

    /// Save by atomic replacement, retaining ownership, Unix permissions and ACLs. Sandboxed callers leave quarantine to macOS.
    public func save(_ text: String, to url: URL, quarantine: QuarantinePolicy = .preserveExisting) async throws -> TextFileSnapshot {
        let worker = Task.detached(priority: .userInitiated) {
            var updated = Data(text.utf8)
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { updated.insert(contentsOf: [0xEF, 0xBB, 0xBF], at: 0) }
            guard updated.count <= TextPreview.maximumBytes else { throw SaveError.tooLarge }
            try validate(url)
            guard access(url.path, W_OK) == 0 else { throw Self.posixError() }

            var temporary = Array(url.deletingLastPathComponent().appendingPathComponent(".panepeek-save-XXXXXX").path.utf8CString)
            let descriptor = mkstemp(&temporary)
            guard descriptor >= 0 else { throw Self.posixError() }
            let temporaryPath = String(decoding: temporary.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer {
                try? handle.close()
                // Only our uncommitted staging file is removed; the source is never removed first.
                unlink(temporaryPath)
            }
            try Task.checkCancellation()
            _ = try validatedSnapshot(at: url, preservingMetadataTo: descriptor, quarantine: quarantine)
            try handle.write(contentsOf: updated)
            guard fchmod(descriptor, version.mode & 0o7777) == 0 else { throw Self.posixError() }
            guard fsync(descriptor) == 0 else { throw Self.posixError() }
            try Task.checkCancellation()
            try validate(url)
            guard rename(temporaryPath, url.path) == 0 else { throw Self.posixError() }
            var saved = stat()
            guard fstat(descriptor, &saved) == 0 else { throw Self.posixError() }
            return TextFileSnapshot(bytes: updated, attributes: saved)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    func validate(_ url: URL) throws { _ = try validatedSnapshot(at: url) }

    func acceptingRestoredFile(at url: URL) async throws -> TextFileSnapshot {
        try await Task.detached(priority: .userInitiated) {
            try validatedSnapshot(at: url, acceptingRename: true)
        }.value
    }

    private func validatedSnapshot(at url: URL, acceptingRename: Bool = false,
                                   preservingMetadataTo target: Int32? = nil,
                                   quarantine: QuarantinePolicy = .preserveExisting) throws -> TextFileSnapshot {
        var listed = stat()
        guard lstat(url.path, &listed) == 0 else { throw SaveError.conflict }
        let current = Version(listed)
        guard current == version || (acceptingRename && current.matchesBeforeRename(version)) else { throw SaveError.conflict }
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw Self.posixError() }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, Version(opened) == current,
              opened.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw SaveError.conflict }
        let bytesRead = try handle.read(upToCount: TextPreview.maximumBytes + 1) ?? Data()
        if let target {
            try Self.preserveOwnership(opened, to: target)
            if quarantine == .preserveExisting { try Self.preserveQuarantine(from: descriptor, to: target) }
            try Self.preserveACL(from: descriptor, to: target)
        }
        guard bytesRead == bytes, fstat(descriptor, &opened) == 0, Version(opened) == current,
              lstat(url.path, &listed) == 0, Version(listed) == current else { throw SaveError.conflict }
        return TextFileSnapshot(bytes: bytes, attributes: opened)
    }

    private static func preserveOwnership(_ source: stat, to target: Int32) throws {
        var staged = stat()
        guard fstat(target, &staged) == 0 else { throw posixError() }
        guard staged.st_uid != source.st_uid || staged.st_gid != source.st_gid else { return }
        guard fchown(target, source.st_uid, source.st_gid) == 0 else { throw posixError() }
    }

    private static func preserveACL(from source: Int32, to target: Int32) throws {
        var acl = acl_get_fd_np(source, ACL_TYPE_EXTENDED)
        // On an open descriptor, ENOENT means no ACL. Clear any rules inherited by staging.
        if acl == nil && errno == ENOENT { acl = acl_init(0) }
        guard let acl else { throw posixError() }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        guard acl_set_fd_np(target, acl, ACL_TYPE_EXTENDED) == 0 else { throw posixError() }
    }

    private static func preserveQuarantine(from source: Int32, to target: Int32) throws {
        let name = "com.apple.quarantine"
        let size = fgetxattr(source, name, nil, 0, 0, 0)
        if size < 0, errno == ENOATTR || errno == ENOTSUP { return }
        guard size >= 0 else { throw posixError() }
        var value = Data(count: size)
        let count = value.withUnsafeMutableBytes { fgetxattr(source, name, $0.baseAddress, $0.count, 0, 0) }
        guard count >= 0 else { throw posixError() }
        guard count == size else { throw SaveError.conflict }
        // Carry opaque metadata only; an absent source attribute never clears the staging file’s quarantine.
        try value.withUnsafeBytes {
            guard fsetxattr(target, name, $0.baseAddress, $0.count, 0, 0) == 0 else { throw posixError() }
        }
    }

    private struct Version: Sendable, Equatable {
        let device: dev_t
        let inode: ino_t
        let size: off_t
        let mode: mode_t
        let owner: uid_t
        let group: gid_t
        let modifiedSeconds: time_t
        let modifiedNanoseconds: Int
        let changedSeconds: time_t
        let changedNanoseconds: Int

        // Renaming changes ctime; bytes and every other captured field must still match.
        func matchesBeforeRename(_ prior: Version) -> Bool {
            device == prior.device && inode == prior.inode && size == prior.size && mode == prior.mode
                && owner == prior.owner && group == prior.group
                && modifiedSeconds == prior.modifiedSeconds && modifiedNanoseconds == prior.modifiedNanoseconds
        }

        init(_ attributes: stat) {
            device = attributes.st_dev
            inode = attributes.st_ino
            size = attributes.st_size
            mode = attributes.st_mode
            owner = attributes.st_uid
            group = attributes.st_gid
            modifiedSeconds = attributes.st_mtimespec.tv_sec
            modifiedNanoseconds = attributes.st_mtimespec.tv_nsec
            changedSeconds = attributes.st_ctimespec.tv_sec
            changedNanoseconds = attributes.st_ctimespec.tv_nsec
        }
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    private enum SaveError: LocalizedError {
        case conflict, tooLarge
        var errorDescription: String? {
            switch self {
            case .conflict: "The file changed, was replaced or is missing. Your draft is still open. Discard and refresh to read the disk version."
            case .tooLarge: "The saved file exceeds 1 MiB, including its UTF-8 BOM. Shorten the draft and try again."
            }
        }
    }
}
