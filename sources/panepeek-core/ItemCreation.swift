import Darwin
import Foundation

public enum ItemName {
    public enum ValidationError: LocalizedError, Equatable {
        case invalid, collision

        public var errorDescription: String? {
            switch self {
            case .invalid: "Enter a filename without / or NUL. Empty names, . and .. are not allowed."
            case .collision: "An item with that name already exists. Choose another name."
            }
        }
    }

    /// Validates one filename without trimming or changing its spelling.
    public static func validate(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\0") else {
            throw ValidationError.invalid
        }
    }
}

public enum ItemCreation {
    public enum Kind: CaseIterable, Sendable { case textFile, folder }

    /// Creates an empty item without replacing an existing file, directory or link.
    public static func create(_ kind: Kind, named name: String, in directory: URL) async throws -> URL {
        let worker = Task.detached(priority: .userInitiated) {
            try ItemName.validate(name)
            guard directory.isFileURL else { throw POSIXError(.EINVAL) }
            let url = directory.appendingPathComponent(name, isDirectory: kind == .folder)
            try Task.checkCancellation()
            switch kind {
            case .textFile:
                let descriptor = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o666)
                guard descriptor >= 0 else { throw creationError() }
                close(descriptor)
            case .folder:
                guard mkdir(url.path, 0o777) == 0 else { throw creationError() }
            }
            return url
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func creationError() -> any Error {
        errno == EEXIST ? ItemName.ValidationError.collision : POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
