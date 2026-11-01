import Darwin
import Foundation

/// A captured copy retains source identity and its destination decisions.
public struct ItemCopy: Sendable {
    let transfer: ItemTransfer
    public var source: URL { transfer.source }
    public var destination: URL { transfer.destination }
    public var isDirectory: Bool { transfer.isDirectory }
    var replacement: ItemTransfer.Replacement? { transfer.replacement }

    public struct Outcome: Identifiable, Sendable {
        public let id = UUID()
        public let succeeded: Bool
        public let message: String
        public let completed: [URL]
        public let failed: URL?
        public let unattempted: [URL]
        public let replaced: [URL]
        public let restored: [URL]
        public init(succeeded: Bool, message: String, completed: [URL] = [], failed: URL? = nil, unattempted: [URL] = [], replaced: [URL] = [], restored: [URL] = []) {
            self.succeeded = succeeded
            self.message = message
            self.completed = completed
            self.failed = failed
            self.unattempted = unattempted
            self.replaced = replaced
            self.restored = restored
        }
    }

    public struct PreflightError: LocalizedError, Sendable {
        public let source: URL
        public let destination: URL
        public let reason: String
        public var errorDescription: String? { "Couldn’t copy \(source.path) to \(destination.path). \(reason)" }
    }

    /// An ordered selection with every known conflict checked before the first write.
    public struct Batch: Sendable {
        public let items: [ItemCopy]

        public static func capture(_ sources: [URL], to directory: URL) async throws -> Batch {
            try await capture(sources, to: directory, allowingCollisions: false)
        }

        static func capture(_ sources: [URL], to directory: URL, allowingCollisions: Bool,
                            allowingSameFolderCopies: Bool = false) async throws -> Batch {
            do {
                let transfers = try await ItemTransfer.capture(sources, to: directory, allowingCollisions: allowingCollisions,
                                                              allowingSameFolderCopies: allowingSameFolderCopies)
                return Batch(items: transfers.map { ItemCopy(transfer: $0) })
            } catch let error as ItemTransfer.PreflightError {
                throw PreflightError(source: error.source, destination: error.destination, reason: error.reason)
            }
        }

        @MainActor func resolvingCollisions(_ choose: (ItemTransfer.Collision) async -> ItemTransfer.CollisionChoice) async throws -> Batch? {
            do {
                guard let resolved = try await ItemTransfer.resolvingCollisions(items.map(\.transfer), operation: .copy, choose) else { return nil }
                return Batch(items: resolved.map { ItemCopy(transfer: $0) })
            } catch let error as ItemTransfer.PreflightError {
                throw PreflightError(source: error.source, destination: error.destination, reason: error.reason)
            }
        }

        /// Stop on the first execution failure; completed copies remain at their destinations.
        public func copy(using step: (@Sendable (ItemCopy) async -> Outcome)? = nil) async -> Outcome {
            let step = step ?? { await $0.copy() }
            if let rejection = await preflightRejection() { return rejection }
            var completed: [URL] = []
            var replaced: [URL] = []
            var restored: [URL] = []
            for (index, item) in items.enumerated() {
                let result = await step(item)
                replaced += result.replaced
                restored += result.restored
                if !result.succeeded {
                    if result.replaced.contains(item.destination) { completed.append(item.destination) }
                    return Self.report(completed: completed, failed: item.source,
                                       unattempted: items.dropFirst(index + 1).map(\.source), error: result.message, replaced: replaced, restored: restored)
                }
                completed.append(item.destination)
            }
            return Self.report(completed: completed, failed: nil, unattempted: [], error: nil, replaced: replaced, restored: restored)
        }

        private func preflightRejection() async -> Outcome? {
            guard let error = await validationError() else { return nil }
            let unattempted = items.map(\.source).filter { $0 != error.source }
            return Self.report(completed: [], failed: error.source, unattempted: unattempted,
                               error: "Copy request rejected before any item was copied. " + error.localizedDescription)
        }

        /// Validate the entire captured set again before any transfer writes.
        func validationError() async -> PreflightError? {
            await Task.detached(priority: .userInitiated) {
                for item in items {
                    do { try item.transfer.validate() } catch {
                        return PreflightError(source: item.source, destination: item.destination, reason: error.localizedDescription)
                    }
                }
                return nil
            }.value
        }

        private static func report(completed: [URL], failed: URL?, unattempted: [URL], error: String?, replaced: [URL] = [], restored: [URL] = []) -> Outcome {
            let count = "\(completed.count) \(completed.count == 1 ? "item" : "items")"
            var lines = [failed == nil ? "Copied \(count)." : "Copy stopped. Completed \(count)."]
            if !completed.isEmpty { lines.append("Completed:\n" + completed.map(\.path).joined(separator: "\n")) }
            if let error { lines.append("Failed:\n" + error) }
            if !unattempted.isEmpty { lines.append("Unattempted:\n" + unattempted.map(\.path).joined(separator: "\n")) }
            return Outcome(succeeded: failed == nil, message: lines.joined(separator: "\n"),
                           completed: completed, failed: failed, unattempted: unattempted, replaced: replaced, restored: restored)
        }
    }

    /// Preflight before prompting for affected drafts, without following the final source link.
    public static func capture(_ source: URL, to directory: URL) async throws -> ItemCopy {
        ItemCopy(transfer: try await ItemTransfer.capture(source, to: directory))
    }

    public func affects(_ url: URL) -> Bool { transfer.affects(url) }

    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemCopy {
        ItemCopy(transfer: try await transfer.acceptingSavedSource(snapshot))
    }

    /// Copies away from the UI actor. A failed copy may leave a partial destination for inspection.
    public func copy() async -> Outcome {
        await copy(using: { try FileManager.default.copyItem(at: $0, to: $1) })
    }

    func copy(using write: @escaping @Sendable (URL, URL) throws -> Void) async -> Outcome {
        if let replacement { return await copyReplacing(replacement, using: write) }
        return await Task.detached(priority: .userInitiated) {
            var started = false
            do {
                try transfer.validate()
                started = true
                try write(source, destination)
                return Outcome(succeeded: true, message: "Copied \(source.path) to \(destination.path).", completed: [destination])
            } catch {
                let incomplete = started && (try? ItemTransfer.Identity.read(destination)) != nil
                    ? " A destination item exists at \(destination.path) and may be incomplete. Inspect it before retrying." : ""
                return Outcome(succeeded: false,
                               message: "Couldn’t copy \(source.path) to \(destination.path). \(error.localizedDescription)\(incomplete)", failed: source)
            }
        }.value
    }
}
