import Darwin
import Foundation

/// The bytes and file identity read with a document, used to reject obsolete saves.
public struct TextFileSnapshot: Sendable {
    private let bytes: Data
    private let version: Version

    init(bytes: Data, attributes: stat) {
        self.bytes = bytes
        version = Version(attributes)
    }

    /// Save unchanged on-disk text by same-directory atomic replacement, preserving Unix permissions.
    public func save(_ text: String, to url: URL) async throws -> TextFileSnapshot {
        let worker = Task.detached(priority: .userInitiated) {
            var updated = Data(text.utf8)
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { updated.insert(contentsOf: [0xEF, 0xBB, 0xBF], at: 0) }
            guard updated.count <= TextPreview.maximumBytes else { throw SaveError.tooLarge }
            try validate(url)
            guard access(url.path, W_OK) == 0 else { throw Self.posixError() }

            var temporary = Array(url.deletingLastPathComponent().appendingPathComponent(".panepeek-save-XXXXXX").path.utf8CString)
            let descriptor = mkstemp(&temporary)
            guard descriptor >= 0 else { throw Self.posixError() }
            let temporaryPath = String(cString: temporary)
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer {
                try? handle.close()
                // Only our uncommitted staging file is removed; the source is never removed first.
                unlink(temporaryPath)
            }
            try handle.write(contentsOf: updated)
            guard fchmod(descriptor, version.mode & 0o7777) == 0, fsync(descriptor) == 0 else { throw Self.posixError() }
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

    func validate(_ url: URL) throws {
        var listed = stat()
        guard lstat(url.path, &listed) == 0, Version(listed) == version else { throw SaveError.conflict }
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw Self.posixError() }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, Version(opened) == version,
              opened.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw SaveError.conflict }
        let current = try handle.read(upToCount: TextPreview.maximumBytes + 1) ?? Data()
        guard current == bytes, fstat(descriptor, &opened) == 0, Version(opened) == version,
              lstat(url.path, &listed) == 0, Version(listed) == version else { throw SaveError.conflict }
    }

    private struct Version: Sendable, Equatable {
        let device: dev_t
        let inode: ino_t
        let size: off_t
        let mode: mode_t
        let modifiedSeconds: time_t
        let modifiedNanoseconds: Int
        let changedSeconds: time_t
        let changedNanoseconds: Int

        init(_ attributes: stat) {
            device = attributes.st_dev
            inode = attributes.st_ino
            size = attributes.st_size
            mode = attributes.st_mode
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
