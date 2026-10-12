import Darwin
import Foundation

/// Captures the listed item without following its final symlink component.
public struct ItemTrash: Sendable {
    public let source: URL
    public let isDirectory: Bool
    private let identity: ItemCopy.Identity
    private let parentIdentity: ItemCopy.Identity
    public var isSymbolicLink: Bool { identity.kind == mode_t(S_IFLNK) }

    public struct Outcome: Identifiable, Sendable {
        public let id = UUID()
        public let succeeded: Bool
        public let sourceRemoved: Bool
        public let message: String
    }

    public static func capture(_ source: URL) async throws -> ItemTrash {
        try await Task.detached(priority: .userInitiated) {
            guard source.isFileURL, source.path != "/" else { throw POSIXError(.EINVAL) }
            let parent = source.deletingLastPathComponent().resolvingSymlinksInPath()
            let source = parent.appendingPathComponent(source.lastPathComponent)
            let identity = try ItemCopy.Identity.read(source)
            guard [mode_t(S_IFREG), mode_t(S_IFDIR), mode_t(S_IFLNK)].contains(identity.kind) else { throw POSIXError(.ENOTSUP) }
            let parentIdentity = try ItemCopy.Identity.read(parent)
            guard parentIdentity.kind == mode_t(S_IFDIR) else { throw POSIXError(.ENOTDIR) }
            return ItemTrash(source: source, isDirectory: identity.kind == mode_t(S_IFDIR),
                             identity: identity, parentIdentity: parentIdentity)
        }.value
    }

    public func affects(_ url: URL) -> Bool {
        url.path == source.path || (isDirectory && url.path.hasPrefix(source.path + "/"))
    }

    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemTrash {
        try await Task.detached(priority: .userInitiated) {
            guard try ItemCopy.Identity.read(source.deletingLastPathComponent()) == parentIdentity,
                  let snapshot else { throw TrashError.changedSource }
            try snapshot.validate(source)
            return ItemTrash(source: source, isDirectory: isDirectory, identity: try ItemCopy.Identity.read(source),
                             parentIdentity: parentIdentity)
        }.value
    }

    /// Use system Trash only; a failure never enters a deletion fallback.
    public func trash() async -> Outcome {
        await trash { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    }

    func trash(using recycle: @escaping @Sendable (URL) throws -> Void) async -> Outcome {
        let worker = Task.detached(priority: .userInitiated) {
            var started = false
            do {
                guard try ItemCopy.Identity.read(source.deletingLastPathComponent()) == parentIdentity,
                      try ItemCopy.Identity.read(source) == identity else { throw TrashError.changedSource }
                try Task.checkCancellation()
                started = true
                try recycle(source)
                return Outcome(succeeded: true, sourceRemoved: true, message: "Moved to Trash:\n\(source.path)")
            } catch {
                var attributes = stat()
                let removed = started && lstat(source.path, &attributes) != 0 && errno == ENOENT
                let changed = removed ? "\nThe source is no longer at its original path. Inspect Trash before retrying." : ""
                return Outcome(succeeded: false, sourceRemoved: removed,
                               message: "Couldn’t move \(source.path) to Trash. \(error.localizedDescription)\(changed)")
            }
        }
        return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
    }

    private enum TrashError: LocalizedError {
        case changedSource
        var errorDescription: String? { "The item or its containing directory changed. Refresh and try Trash again." }
    }
}
