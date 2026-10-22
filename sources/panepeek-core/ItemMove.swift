import Darwin
import Foundation

/// A captured move retains source identity and replaces only an explicitly approved regular file.
public struct ItemMove: Sendable {
    let item: ItemCopy
    let replacement: Replacement?

    init(item: ItemCopy, replacement: Replacement? = nil) {
        self.item = item
        self.replacement = replacement
    }
    public var source: URL { item.source }
    public var destination: URL { item.destination }
    public var isDirectory: Bool { item.isDirectory }

    public enum CollisionChoice: Sendable, Equatable {
        case keepBoth(String), replace, cancel
    }

    public struct Collision: Sendable {
        public enum Operation: Sendable { case copy, move }
        public let operation: Operation
        public let source: URL
        public let destination: URL
        public let suggestedName: String
        public let errorMessage: String?
        public let canReplace: Bool
        public init(source: URL, destination: URL, suggestedName: String, errorMessage: String? = nil, canReplace: Bool = false, operation: Operation = .move) {
            self.operation = operation
            self.source = source
            self.destination = destination
            self.suggestedName = suggestedName
            self.errorMessage = errorMessage
            self.canReplace = canReplace
        }
    }

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
            do {
                let captured = try await ItemCopy.Batch.capture(sources, to: directory)
                return Batch(items: captured.items.map { ItemMove(item: $0) })
            } catch let error as ItemCopy.PreflightError {
                throw PreflightError(source: error.source, destination: error.destination, reason: error.reason)
            }
        }

        static func captureForResolvingCollisions(_ sources: [URL], to directory: URL) async throws -> Batch {
            do {
                let captured = try await ItemCopy.Batch.capture(sources, to: directory, allowingCollisions: true)
                return Batch(items: captured.items.map { ItemMove(item: $0) })
            } catch let error as ItemCopy.PreflightError {
                throw PreflightError(source: error.source, destination: error.destination, reason: error.reason)
            }
        }

        @MainActor func resolvingCollisions(operation kind: Collision.Operation = .move, _ choose: (Collision) async -> CollisionChoice) async throws -> Batch? {
            var resolved = items
            for index in resolved.indices {
                let operation = resolved[index]
                do {
                    let sameFolderCopy = kind == .copy && operation.item.hasSameContainingDirectory
                    guard var suggestion = try await operation.availableName(reserving: resolved, rejectingSameItem: !sameFolderCopy) else { continue }
                    if sameFolderCopy {
                        resolved[index] = try await operation.retargeted(named: suggestion, reserving: resolved)
                        continue
                    }
                    let replacement = try await operation.replacementCandidate()
                    var errorMessage: String?
                    while true {
                        let collision = Collision(source: operation.source, destination: operation.destination,
                                                  suggestedName: suggestion, errorMessage: errorMessage, canReplace: replacement != nil, operation: kind)
                        let choice = await choose(collision)
                        do {
                            switch choice {
                            case .cancel: return nil
                            case .keepBoth(let name): resolved[index] = try await operation.retargeted(named: name, reserving: resolved)
                            case .replace:
                                guard let replacement else { throw POSIXError(.ENOTSUP) }
                                resolved[index] = try await operation.replacing(replacement)
                            }
                            break
                        } catch let error as ItemName.ValidationError {
                            errorMessage = error.localizedDescription
                            suggestion = try await operation.availableName(reserving: resolved) ?? suggestion
                        }
                    }
                } catch {
                    throw PreflightError(source: operation.source, destination: operation.destination, reason: error.localizedDescription)
                }
            }
            return Batch(items: resolved)
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
                    do { try operation.validate() } catch {
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
        ItemMove(item: try await ItemCopy.capture(source, to: directory))
    }

    private func availableName(reserving operations: [ItemMove], rejectingSameItem: Bool = true) async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            guard try item.destinationIsOccupied(rejectingSameItem: rejectingSameItem) else { return nil }
            let directory = destination.deletingLastPathComponent()
            let caseSensitive = (try? directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames
            let reserved = Set(operations.filter { $0.source.path != source.path }.map { Self.nameKey($0.destination.lastPathComponent, caseSensitive: caseSensitive) })
            let hasExtension = !isDirectory || (try? source.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
            let ext = hasExtension ? source.pathExtension : ""
            let stem = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
            let filesystemLimit = pathconf(directory.path, _PC_NAME_MAX)
            let nameLimit = filesystemLimit > 0 ? Int(filesystemLimit) : 255
            var number = 2
            while true {
                try Task.checkCancellation()
                let suffix = " (\(number))" + (ext.isEmpty ? "" : "." + ext)
                guard suffix.utf8.count < nameLimit else { throw POSIXError(.ENAMETOOLONG) }
                var shortened = stem
                while shortened.utf8.count + suffix.utf8.count > nameLimit { shortened.removeLast() }
                let name = shortened + suffix
                let candidate = directory.appendingPathComponent(name)
                if !reserved.contains(Self.nameKey(name, caseSensitive: caseSensitive)) {
                    var attributes = stat()
                    if lstat(candidate.path, &attributes) != 0 {
                        guard errno == ENOENT else { throw Self.posixError() }
                        return name
                    }
                }
                number += 1
            }
        }.value
    }

    private func retargeted(named name: String, reserving operations: [ItemMove]) async throws -> ItemMove {
        try await Task.detached(priority: .userInitiated) {
            try ItemName.validate(name)
            let directory = destination.deletingLastPathComponent()
            let caseSensitive = (try? directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames
            guard !operations.contains(where: {
                $0.source.path != source.path && Self.nameKey($0.destination.lastPathComponent, caseSensitive: caseSensitive) == Self.nameKey(name, caseSensitive: caseSensitive)
            }) else { throw ItemName.ValidationError.collision }
            return ItemMove(item: try item.retargeted(named: name))
        }.value
    }

    private static func nameKey(_ name: String, caseSensitive: Bool?) -> String {
        caseSensitive == false ? name.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX")) : name
    }

    public func affects(_ url: URL) -> Bool { item.affects(url) }

    public func relocated(_ url: URL) -> URL {
        guard affects(url) else { return url }
        return URL(fileURLWithPath: destination.path + String(url.path.dropFirst(source.path.count)), isDirectory: url.hasDirectoryPath)
    }

    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemMove {
        ItemMove(item: try await item.acceptingSavedSource(snapshot), replacement: replacement)
    }

    public func move() async -> Outcome { await move(using: Self.exclusiveRename) }

    func move(using rename: @escaping @Sendable (URL, URL) throws -> Void,
              copy: @escaping @Sendable (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) },
              remove: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) async -> Outcome {
        if let replacement { return await moveReplacing(replacement, rename: rename, copy: copy, remove: remove) }
        return await Task.detached(priority: .userInitiated) {
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
            return Outcome(succeeded: errors.isEmpty && sourceRemoved, sourceRemoved: sourceRemoved, message: lines.joined(separator: "\n"), destinationPublished: published)
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
