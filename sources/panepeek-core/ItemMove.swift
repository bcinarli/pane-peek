import Darwin
import Foundation

/// A captured move retains the listed source link and never overwrites a destination.
public struct ItemMove: Sendable {
    let item: ItemCopy
    public var source: URL { item.source }
    public var destination: URL { item.destination }
    public var isDirectory: Bool { item.isDirectory }

    public struct Outcome: Identifiable, Sendable {
        public let id = UUID()
        public let succeeded: Bool
        public let sourceRemoved: Bool
        public let message: String
    }

    public struct PreflightError: LocalizedError, Sendable {
        public let source: URL
        public let destination: URL
        public let reason: String
        public var errorDescription: String? { "Couldn’t move \(source.path) to \(destination.path). \(reason)" }
    }

    /// An ordered selection captured before confirmation, with all known conflicts rejected.
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
        }

        public static func capture(_ sources: [URL], to directory: URL) async throws -> Batch {
            do {
                let captured = try await ItemCopy.Batch.capture(sources, to: directory)
                return Batch(items: captured.items.map { ItemMove(item: $0) })
            } catch let error as ItemCopy.PreflightError {
                throw PreflightError(source: error.source, destination: error.destination, reason: error.reason)
            }
        }

        /// Stop on the first failure; source removal still counts when only cleanup failed.
        public func move(using step: @escaping @Sendable (ItemMove) async -> ItemMove.Outcome = { await $0.move() }) async -> Outcome {
            if let rejection = await preflightRejection() { return rejection }
            var relocated: [ItemMove] = []
            for (index, item) in items.enumerated() {
                let result = await step(item)
                if result.sourceRemoved { relocated.append(item) }
                if !result.succeeded {
                    return Self.report(relocated: relocated, failed: item.source,
                                       unattempted: items.dropFirst(index + 1).map(\.source), error: result.message)
                }
            }
            return Self.report(relocated: relocated, failed: nil, unattempted: [], error: nil)
        }

        private func preflightRejection() async -> Outcome? {
            guard let error = await ItemCopy.Batch(items: items.map(\.item)).validationError() else { return nil }
            let reason = "Move request rejected before any item was moved. "
                + PreflightError(source: error.source, destination: error.destination, reason: error.reason).localizedDescription
            return Self.report(relocated: [], failed: error.source,
                               unattempted: items.map(\.source).filter { $0 != error.source }, error: reason)
        }

        static func report(relocated: [ItemMove], failed: URL?, unattempted: [URL], error: String?) -> Outcome {
            let completed = relocated.map(\.destination)
            let succeeded = failed == nil && error == nil
            let count = "\(completed.count) \(completed.count == 1 ? "item" : "items")"
            var lines = [succeeded ? "Moved \(count)." : "Move stopped. Completed \(count)."]
            if !completed.isEmpty { lines.append("Completed:\n" + completed.map(\.path).joined(separator: "\n")) }
            if let error { lines.append("Failed:\n" + error) }
            if !unattempted.isEmpty { lines.append("Unattempted:\n" + unattempted.map(\.path).joined(separator: "\n")) }
            return Outcome(succeeded: succeeded, message: lines.joined(separator: "\n"), completed: completed,
                           failed: failed, unattempted: unattempted, relocated: relocated)
        }
    }

    public static func capture(_ source: URL, to directory: URL) async throws -> ItemMove {
        ItemMove(item: try await ItemCopy.capture(source, to: directory))
    }

    public func affects(_ url: URL) -> Bool { item.affects(url) }

    public func relocated(_ url: URL) -> URL {
        guard affects(url) else { return url }
        return URL(fileURLWithPath: destination.path + String(url.path.dropFirst(source.path.count)), isDirectory: url.hasDirectoryPath)
    }

    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemMove {
        ItemMove(item: try await item.acceptingSavedSource(snapshot))
    }

    public func move() async -> Outcome { await move(using: Self.exclusiveRename) }

    func move(using rename: @escaping @Sendable (URL, URL) throws -> Void,
              copy: @escaping @Sendable (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) },
              remove: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            var staging: (url: URL, identity: ItemCopy.Identity)?
            var sourceRemoved = false
            var published = false
            var publishedIdentity: ItemCopy.Identity?
            var removingSource = false
            var errors: [String] = []
            do {
                try item.validate()
                do {
                    try rename(source, destination)
                    sourceRemoved = true
                    published = true
                } catch let error as POSIXError where error.code == .EXDEV {
                    let directory = destination.deletingLastPathComponent().appendingPathComponent(".panepeek-move-\(UUID().uuidString)", isDirectory: true)
                    guard mkdir(directory.path, 0o700) == 0 else { throw Self.posixError() }
                    staging = (directory, try ItemCopy.Identity.read(directory))
                    let copied = directory.appendingPathComponent(source.lastPathComponent)
                    try copy(source, copied)
                    try item.validate()
                    publishedIdentity = try ItemCopy.Identity.read(copied)
                    try rename(copied, destination)
                    published = true
                    guard try ItemCopy.Identity.read(destination) == publishedIdentity else { throw ItemCopy.CopyError.changedItem }
                    try item.validateSource()
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
                    guard try ItemCopy.Identity.read(staging.url) == staging.identity else { throw ItemCopy.CopyError.changedItem }
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
                let intact = (try? ItemCopy.Identity.read(destination)) == publishedIdentity
                lines.append(intact
                    ? "A complete destination exists at \(destination.path). Source removal did not complete; inspect \(source.path) and the destination before retrying."
                    : "The published destination changed at \(destination.path). Source removal was stopped; inspect both paths before retrying.")
                if removingSource, isDirectory { lines.append("Source removal may be partial. The destination copy has been retained.") }
            }
            return Outcome(succeeded: errors.isEmpty && sourceRemoved, sourceRemoved: sourceRemoved, message: lines.joined(separator: "\n"))
        }.value
    }

    static func exclusiveRename(_ source: URL, _ destination: URL) throws {
        guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
