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

    public struct PreflightError: LocalizedError, Sendable {
        public let source: URL
        public let reason: String
        public var errorDescription: String? { "Couldn’t move \(source.path) to Trash. \(reason)" }
    }

    /// An ordered selection revalidated before the first Trash call.
    public struct Batch: Sendable {
        public let items: [ItemTrash]

        public struct Outcome: Identifiable, Sendable {
            public let id = UUID()
            public let succeeded: Bool
            public let message: String
            public let completed: [URL]
            public let failed: URL?
            public let unattempted: [URL]
            public let removed: [ItemTrash]
        }

        public static func capture(_ sources: [URL]) async throws -> Batch {
            guard !sources.isEmpty else { throw POSIXError(.EINVAL) }
            var items: [ItemTrash] = []
            var captured: Set<URL> = []
            for source in sources {
                do {
                    let item = try await ItemTrash.capture(source)
                    guard captured.insert(item.source).inserted else { throw POSIXError(.EINVAL) }
                    items.append(item)
                } catch { throw PreflightError(source: source, reason: error.localizedDescription) }
            }
            return Batch(items: items)
        }

        /// Revalidate the whole selection before the first mutation, then stop on the first failure.
        public func trash(using step: (@Sendable (ItemTrash) async -> ItemTrash.Outcome)? = nil) async -> Outcome {
            let step = step ?? { await $0.trash() }
            let rejection = await Task.detached(priority: .userInitiated) { () -> PreflightError? in
                for item in items {
                    do { try item.validate() } catch {
                        return PreflightError(source: item.source, reason: error.localizedDescription)
                    }
                }
                return nil
            }.value
            if let rejection {
                return Self.report(completed: [], removed: [], failed: rejection.source,
                                   unattempted: items.map(\.source).filter { $0 != rejection.source },
                                   error: "Trash request rejected before mutation. " + rejection.localizedDescription)
            }
            var completed: [URL] = []
            var removed: [ItemTrash] = []
            for (index, item) in items.enumerated() {
                let result = await step(item)
                if result.sourceRemoved { removed.append(item) }
                if !result.succeeded {
                    return Self.report(completed: completed, removed: removed, failed: item.source,
                                       unattempted: items.dropFirst(index + 1).map(\.source), error: result.message)
                }
                completed.append(item.source)
            }
            return Self.report(completed: completed, removed: removed, failed: nil, unattempted: [], error: nil)
        }

        static func report(completed: [URL], removed: [ItemTrash], failed: URL?, unattempted: [URL], error: String?) -> Outcome {
            let succeeded = failed == nil && error == nil
            let count = "\(completed.count) \(completed.count == 1 ? "item" : "items")"
            var lines = [succeeded ? "Moved \(count) to Trash." : "Trash stopped. Completed \(count)."]
            if !completed.isEmpty { lines.append("Completed:\n" + completed.map(\.path).joined(separator: "\n")) }
            if let error { lines.append("Failed:\n" + error) }
            if !unattempted.isEmpty { lines.append("Unattempted:\n" + unattempted.map(\.path).joined(separator: "\n")) }
            return Outcome(succeeded: succeeded, message: lines.joined(separator: "\n"), completed: completed,
                           failed: failed, unattempted: unattempted, removed: removed)
        }
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
                try validate()
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

    private func validate() throws {
        guard try ItemCopy.Identity.read(source.deletingLastPathComponent()) == parentIdentity,
              try ItemCopy.Identity.read(source) == identity else { throw TrashError.changedSource }
    }

    private enum TrashError: LocalizedError {
        case changedSource
        var errorDescription: String? { "The item or its containing directory changed. Refresh and try Trash again." }
    }
}
