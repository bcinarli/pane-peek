import Darwin
import Foundation

public enum TextPreview: Sendable, Equatable {
    case text(String)
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
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard item.url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
            if item.isPackage { return TextPreview.unavailable(.package) }
            if item.isDirectory { return TextPreview.unavailable(.folder) }
            let target = item.url.resolvingSymlinksInPath()
            if (try? target.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true {
                return .unavailable(.package)
            }

            // Nonblocking open prevents a stale row or retargeted link from waiting on a FIFO.
            let descriptor = Darwin.open(item.url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
            guard descriptor >= 0 else { throw posixError() }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var attributes = stat()
            guard fstat(descriptor, &attributes) == 0 else { throw posixError() }
            let type = attributes.st_mode & mode_t(S_IFMT)
            if type == mode_t(S_IFDIR) { return .unavailable(.folder) }
            guard type == mode_t(S_IFREG) else { return .unavailable(.nonRegularFile) }
            if attributes.st_size > maximumBytes { return .unavailable(.tooLarge) }
            try Task.checkCancellation()
            var bytes = try handle.read(upToCount: maximumBytes + 1) ?? Data()
            try Task.checkCancellation()
            guard bytes.count <= maximumBytes else { return .unavailable(.tooLarge) }
            if bytes.contains(0) { return .unavailable(.binary) }
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
            guard let text = String(data: bytes, encoding: .utf8) else { return .unavailable(.invalidUTF8) }
            return .text(text)
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
