import Darwin
import Foundation

public enum TextPreview: Sendable, Equatable {
    case text(String, editable: Bool = true)
    case unavailable(UnavailableReason)

    public enum UnavailableReason: Sendable, Equatable {
        case folder, package, tooLarge, binary, invalidUTF8, nonRegularFile

        public var message: String {
            switch self {
            case .folder: "No text preview for folders."
            case .package: "No text preview for packages."
            case .tooLarge: "Text preview is limited to files up to 1 MiB."
            case .binary: "No text preview for binary files."
            case .invalidUTF8: "This file is not valid UTF-8 text."
            case .nonRegularFile: "No text preview for this file type."
            }
        }
    }

    public static let maximumBytes = 1_048_576

    /// Read at most 1 MiB plus one boundary byte off the UI thread. Links may read regular text targets.
    public static func read(_ item: DirectoryEntry) async throws -> TextPreview {
        try await load(item).preview
    }

    struct Loaded: Sendable {
        let preview: TextPreview
        var snapshot: TextFileSnapshot? = nil
    }

    static func load(_ item: DirectoryEntry) async throws -> Loaded {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard item.url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
            if item.isPackage { return Loaded(preview: .unavailable(.package)) }
            if item.isDirectory { return Loaded(preview: .unavailable(.folder)) }
            let target = item.url.resolvingSymlinksInPath()
            if (try? target.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true {
                return Loaded(preview: .unavailable(.package))
            }

            // Nonblocking open prevents a stale row or retargeted link from waiting on a FIFO.
            let descriptor = Darwin.open(item.url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
            guard descriptor >= 0 else { throw posixError() }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var attributes = stat()
            guard fstat(descriptor, &attributes) == 0 else { throw posixError() }
            let type = attributes.st_mode & mode_t(S_IFMT)
            if type == mode_t(S_IFDIR) { return Loaded(preview: .unavailable(.folder)) }
            guard type == mode_t(S_IFREG) else { return Loaded(preview: .unavailable(.nonRegularFile)) }
            if attributes.st_size > maximumBytes { return Loaded(preview: .unavailable(.tooLarge)) }
            var listed = stat()
            let editable = !item.isSymbolicLink && lstat(item.url.path, &listed) == 0
                && listed.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG)
                && listed.st_dev == attributes.st_dev && listed.st_ino == attributes.st_ino
            try Task.checkCancellation()
            var bytes = try handle.read(upToCount: maximumBytes + 1) ?? Data()
            try Task.checkCancellation()
            guard bytes.count <= maximumBytes else { return Loaded(preview: .unavailable(.tooLarge)) }
            if bytes.contains(0) { return Loaded(preview: .unavailable(.binary)) }
            let snapshot = editable ? TextFileSnapshot(bytes: bytes, attributes: attributes) : nil
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
            guard let text = String(data: bytes, encoding: .utf8) else { return Loaded(preview: .unavailable(.invalidUTF8)) }
            return Loaded(preview: .text(text, editable: editable), snapshot: snapshot)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
