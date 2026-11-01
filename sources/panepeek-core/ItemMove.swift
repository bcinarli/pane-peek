import Darwin
import Foundation

/// A captured move retains source identity and replaces only an explicitly approved regular file.
public struct ItemMove: Sendable {
    let transfer: ItemTransfer
    var replacement: ItemTransfer.Replacement? { transfer.replacement }
    public var source: URL { transfer.source }
    public var destination: URL { transfer.destination }
    public var isDirectory: Bool { transfer.isDirectory }

    public struct Outcome: Identifiable, Sendable {
        public let id = UUID()
        public let succeeded: Bool
        public let sourceRemoved: Bool
        public let message: String
        public let destinationPublished: Bool
        public let restoredDestination: URL?

        public init(succeeded: Bool, sourceRemoved: Bool, message: String, destinationPublished: Bool = false, restoredDestination: URL? = nil) {
            self.succeeded = succeeded
            self.sourceRemoved = sourceRemoved
            self.message = message
            self.destinationPublished = destinationPublished
            self.restoredDestination = restoredDestination
        }
    }

    public struct PreflightError: LocalizedError, Sendable {
        public let source: URL
        public let destination: URL
        public let reason: String
        public var errorDescription: String? { "Couldn’t move \(source.path) to \(destination.path). \(reason)" }
    }

    /// An ordered selection captured before dirty-document choices and filesystem writes.
    public struct Batch: Sendable {
        public let items: [ItemMove]

        public struct Outcome: Identifiable, Sendable {
            public let id = UUID()
            public let succeeded: Bool
            public let message: String
            public let completed: [URL]
            public let failed: URL?
            public let unattempted: [URL]
            public let relocated: [ItemMove]
            public let replaced: [URL]
            public let restored: [URL]
        }

        public static func capture(_ sources: [URL], to directory: URL) async throws -> Batch {
            try await capture(sources, to: directory, allowingCollisions: false)
        }

        static func captureForResolvingCollisions(_ sources: [URL], to directory: URL) async throws -> Batch {
            try await capture(sources, to: directory, allowingCollisions: true)
        }

        private static func capture(_ sources: [URL], to directory: URL, allowingCollisions: Bool) async throws -> Batch {
            do {
                let transfers = try await ItemTransfer.capture(sources, to: directory, allowingCollisions: allowingCollisions)
                return Batch(items: transfers.map { ItemMove(transfer: $0) })
            } catch let error as ItemTransfer.PreflightError {
                throw PreflightError(source: error.source, destination: error.destination, reason: error.reason)
            }
        }

        @MainActor func resolvingCollisions(_ choose: (ItemTransfer.Collision) async -> ItemTransfer.CollisionChoice) async throws -> Batch? {
            do {
                guard let resolved = try await ItemTransfer.resolvingCollisions(items.map(\.transfer), operation: .move, choose) else { return nil }
                return Batch(items: resolved.map { ItemMove(transfer: $0) })
            } catch let error as ItemTransfer.PreflightError {
                throw PreflightError(source: error.source, destination: error.destination, reason: error.reason)
            }
        }

        /// Stop on the first failure; source removal still counts when only cleanup failed.
        public func move(using step: (@Sendable (ItemMove) async -> ItemMove.Outcome)? = nil) async -> Outcome {
            let step = step ?? { await $0.move() }
            if let rejection = await preflightRejection() { return rejection }
            var relocated: [ItemMove] = []
            var replaced: [URL] = []
            var restored: [URL] = []
            for (index, item) in items.enumerated() {
                let result = await step(item)
                if result.sourceRemoved { relocated.append(item) }
                if let destination = result.restoredDestination { restored.append(destination) }
                if item.replacement != nil, result.destinationPublished { replaced.append(item.destination) }
                if !result.succeeded {
                    return Self.report(relocated: relocated, replaced: replaced, restored: restored, failed: item.source,
                                       unattempted: items.dropFirst(index + 1).map(\.source), error: result.message)
                }
            }
            return Self.report(relocated: relocated, replaced: replaced, restored: restored, failed: nil, unattempted: [], error: nil)
        }

        private func preflightRejection() async -> Outcome? {
            let error = await Task.detached(priority: .userInitiated) { () -> PreflightError? in
                for operation in items {
                    do { try operation.transfer.validate() } catch {
                        return PreflightError(source: operation.source, destination: operation.destination, reason: error.localizedDescription)
                    }
                }
                return nil
            }.value
            guard let error else { return nil }
            let reason = "Move request rejected before any item was moved. " + error.localizedDescription
            return Self.report(relocated: [], failed: error.source,
                               unattempted: items.map(\.source).filter { $0 != error.source }, error: reason)
        }

        static func report(relocated: [ItemMove], replaced: [URL] = [], restored: [URL] = [], failed: URL?, unattempted: [URL], error: String?) -> Outcome {
            let completed = relocated.map(\.destination)
            let succeeded = failed == nil && error == nil
            let count = "\(completed.count) \(completed.count == 1 ? "item" : "items")"
            var lines = [succeeded ? "Moved \(count)." : "Move stopped. Completed \(count)."]
            if !completed.isEmpty { lines.append("Completed:\n" + completed.map(\.path).joined(separator: "\n")) }
            if let error { lines.append("Failed:\n" + error) }
            if !unattempted.isEmpty { lines.append("Unattempted:\n" + unattempted.map(\.path).joined(separator: "\n")) }
            return Outcome(succeeded: succeeded, message: lines.joined(separator: "\n"), completed: completed,
                           failed: failed, unattempted: unattempted, relocated: relocated, replaced: replaced, restored: restored)
        }
    }

    public static func capture(_ source: URL, to directory: URL) async throws -> ItemMove {
        ItemMove(transfer: try await ItemTransfer.capture(source, to: directory))
    }

    public func affects(_ url: URL) -> Bool { transfer.affects(url) }

    public func relocated(_ url: URL) -> URL {
        guard affects(url) else { return url }
        return URL(fileURLWithPath: destination.path + String(url.path.dropFirst(source.path.count)), isDirectory: url.hasDirectoryPath)
    }

    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemMove {
        ItemMove(transfer: try await transfer.acceptingSavedSource(snapshot))
    }

    public func move() async -> Outcome { await move(using: ItemTransfer.exclusiveRename) }

    func move(using rename: @escaping @Sendable (URL, URL) throws -> Void,
              copy: @escaping @Sendable (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) },
              remove: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) async -> Outcome {
        if let replacement { return await moveReplacing(replacement, rename: rename, copy: copy, remove: remove) }
        return await Task.detached(priority: .userInitiated) {
            var staging: (url: URL, identity: ItemTransfer.Identity)?
            var sourceRemoved = false
            var published = false
            var publishedIdentity: ItemTransfer.Identity?
            var removingSource = false
            var errors: [String] = []
            do {
                try transfer.validate()
                do {
                    try rename(source, destination)
                    sourceRemoved = true
                    published = true
                } catch let error as POSIXError where error.code == .EXDEV {
                    let directory = destination.deletingLastPathComponent().appendingPathComponent(".panepeek-move-\(UUID().uuidString)", isDirectory: true)
                    guard mkdir(directory.path, 0o700) == 0 else { throw Self.posixError() }
                    staging = (directory, try ItemTransfer.Identity.read(directory))
                    let copied = directory.appendingPathComponent(source.lastPathComponent)
                    try copy(source, copied)
                    try transfer.validate()
                    publishedIdentity = try ItemTransfer.Identity.read(copied)
                    try rename(copied, destination)
                    published = true
                    guard try ItemTransfer.Identity.read(destination) == publishedIdentity else { throw ItemTransfer.ValidationError.changedItem }
                    try transfer.validateSource()
                    removingSource = true
                    try remove(source)
                    sourceRemoved = true
                }
            } catch {
                errors.append(error.localizedDescription)
                if removingSource {
                    var attributes = stat()
                    sourceRemoved = lstat(source.path, &attributes) != 0 && errno == ENOENT
                }
            }
            if let staging {
                do {
                    guard try ItemTransfer.Identity.read(staging.url) == staging.identity else { throw ItemTransfer.ValidationError.changedItem }
                    try remove(staging.url)
                } catch {
                    errors.append("Temporary copy cleanup failed at \(staging.url.path). \(error.localizedDescription) Inspect its contents before retrying.")
                }
            }
            let summary = sourceRemoved
                ? "Item moved from \(source.path) to \(destination.path)."
                : "Couldn’t move \(source.path) to \(destination.path)."
            var lines = [summary] + errors
            if published, !sourceRemoved {
                let intact = (try? ItemTransfer.Identity.read(destination)) == publishedIdentity
                lines.append(intact
                    ? "A complete destination exists at \(destination.path). Source removal did not complete; inspect \(source.path) and the destination before retrying."
                    : "The published destination changed at \(destination.path). Source removal was stopped; inspect both paths before retrying.")
                if removingSource, isDirectory { lines.append("Source removal may be partial. The destination copy has been retained.") }
            }
            return Outcome(succeeded: errors.isEmpty && sourceRemoved, sourceRemoved: sourceRemoved, message: lines.joined(separator: "\n"), destinationPublished: published)
        }.value
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
