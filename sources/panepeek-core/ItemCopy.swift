import Darwin
import Foundation

/// Captures listed link identity and the directories used by one copy request.
public struct ItemCopy: Sendable {
    public let source: URL
    public let destination: URL
    public let isDirectory: Bool
    private let sourceIdentity: Identity
    private let parentIdentity: Identity
    private let destinationIdentity: Identity

    public struct Outcome: Identifiable, Sendable {
        public let id = UUID()
        public let succeeded: Bool
        public let message: String
        public let completed: [URL]
        public let failed: URL?
        public let unattempted: [URL]
        public init(succeeded: Bool, message: String, completed: [URL] = [], failed: URL? = nil, unattempted: [URL] = []) {
            self.succeeded = succeeded
            self.message = message
            self.completed = completed
            self.failed = failed
            self.unattempted = unattempted
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
            try await Task.detached(priority: .userInitiated) {
                guard !sources.isEmpty, directory.isFileURL, sources.allSatisfy(\.isFileURL) else { throw POSIXError(.EINVAL) }
                let directory = directory.resolvingSymlinksInPath()
                let caseSensitive = (try? directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames
                var names: Set<Data> = []
                var items: [ItemCopy] = []
                for source in sources {
                    do {
                        let item = try ItemCopy.captured(source, to: directory)
                        let name = caseSensitive == false
                            ? item.destination.lastPathComponent.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
                            : item.destination.lastPathComponent
                        guard names.insert(Data(name.utf8)).inserted else { throw ItemName.ValidationError.collision }
                        items.append(item)
                    } catch {
                        throw PreflightError(source: source, destination: directory.appendingPathComponent(source.lastPathComponent),
                                             reason: error.localizedDescription)
                    }
                }
                return Batch(items: items)
            }.value
        }

        /// Stop on the first execution failure; completed copies remain at their destinations.
        public func copy(using step: @escaping @Sendable (ItemCopy) async -> Outcome = { await $0.copy() }) async -> Outcome {
            if let rejection = await preflightRejection() { return rejection }
            var completed: [URL] = []
            for (index, item) in items.enumerated() {
                let result = await step(item)
                if !result.succeeded {
                    return Self.report(completed: completed, failed: item.source,
                                       unattempted: items.dropFirst(index + 1).map(\.source), error: result.message)
                }
                completed.append(item.destination)
            }
            return Self.report(completed: completed, failed: nil, unattempted: [], error: nil)
        }

        private func preflightRejection() async -> Outcome? {
            await Task.detached(priority: .userInitiated) {
                for (index, item) in items.enumerated() {
                    do { try item.validate() } catch {
                        let unattempted = items.enumerated().filter { $0.offset != index }.map { $0.element.source }
                        let error = "Copy request rejected before any item was copied. "
                            + PreflightError(source: item.source, destination: item.destination, reason: error.localizedDescription).localizedDescription
                        return Self.report(completed: [], failed: item.source, unattempted: unattempted, error: error)
                    }
                }
                return nil
            }.value
        }

        private static func report(completed: [URL], failed: URL?, unattempted: [URL], error: String?) -> Outcome {
            let count = "\(completed.count) \(completed.count == 1 ? "item" : "items")"
            var lines = [failed == nil ? "Copied \(count)." : "Copy stopped. Completed \(count)."]
            if !completed.isEmpty { lines.append("Completed:\n" + completed.map(\.path).joined(separator: "\n")) }
            if let error { lines.append("Failed:\n" + error) }
            if !unattempted.isEmpty { lines.append("Unattempted:\n" + unattempted.map(\.path).joined(separator: "\n")) }
            return Outcome(succeeded: failed == nil, message: lines.joined(separator: "\n"),
                           completed: completed, failed: failed, unattempted: unattempted)
        }
    }

    public enum CopyError: LocalizedError, Equatable {
        case ancestry, changedItem
        public var errorDescription: String? {
            switch self {
            case .ancestry: "A folder cannot be transferred into itself or a descendant. Choose another destination."
            case .changedItem: "The source or one of the captured directories changed. Refresh and try again."
            }
        }
    }

    /// Preflight before prompting for affected drafts, without following the final source link.
    public static func capture(_ source: URL, to directory: URL) async throws -> ItemCopy {
        try await Task.detached(priority: .userInitiated) { try captured(source, to: directory) }.value
    }

    private static func captured(_ source: URL, to directory: URL) throws -> ItemCopy {
        guard source.isFileURL, directory.isFileURL else { throw POSIXError(.EINVAL) }
        let parent = source.deletingLastPathComponent().resolvingSymlinksInPath()
        let source = parent.appendingPathComponent(source.lastPathComponent)
        let identity = try Identity.read(source)
        guard [mode_t(S_IFREG), mode_t(S_IFDIR), mode_t(S_IFLNK)].contains(identity.kind) else {
            throw POSIXError(.ENOTSUP)
        }
        let directory = directory.resolvingSymlinksInPath()
        let destinationIdentity = try Identity.read(directory)
        guard destinationIdentity.kind == mode_t(S_IFDIR) else { throw POSIXError(.ENOTDIR) }
        let isDirectory = identity.kind == mode_t(S_IFDIR)
        if isDirectory, directory.path == source.path || directory.path.hasPrefix(source.path + "/") {
            throw CopyError.ancestry
        }
        let request = ItemCopy(source: source, destination: directory.appendingPathComponent(source.lastPathComponent),
                               isDirectory: isDirectory, sourceIdentity: identity,
                               parentIdentity: try Identity.read(parent), destinationIdentity: destinationIdentity)
        try request.validate()
        return request
    }

    public func affects(_ url: URL) -> Bool {
        url.path == source.path || (isDirectory && url.path.hasPrefix(source.path + "/"))
    }

    /// An explicit Save changes the inode; accept only the saved document's verified baseline.
    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemCopy {
        try await Task.detached(priority: .userInitiated) {
            try validateParents()
            guard let snapshot else { throw CopyError.changedItem }
            try snapshot.validate(source)
            return ItemCopy(source: source, destination: destination, isDirectory: isDirectory,
                            sourceIdentity: try Identity.read(source), parentIdentity: parentIdentity,
                            destinationIdentity: destinationIdentity)
        }.value
    }

    /// Copies away from the UI actor. A failed copy may leave a partial destination for inspection.
    public func copy() async -> Outcome {
        await copy(using: { try FileManager.default.copyItem(at: $0, to: $1) })
    }

    func copy(using write: @escaping @Sendable (URL, URL) throws -> Void) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            var started = false
            do {
                try validate()
                started = true
                try write(source, destination)
                return Outcome(succeeded: true, message: "Copied \(source.path) to \(destination.path).", completed: [destination])
            } catch {
                let incomplete = started && (try? Identity.read(destination)) != nil
                    ? " A destination item exists at \(destination.path) and may be incomplete. Inspect it before retrying." : ""
                return Outcome(succeeded: false,
                               message: "Couldn’t copy \(source.path) to \(destination.path). \(error.localizedDescription)\(incomplete)", failed: source)
            }
        }.value
    }

    private func validateParents() throws {
        guard try Identity.read(source.deletingLastPathComponent()) == parentIdentity,
              try Identity.read(destination.deletingLastPathComponent()) == destinationIdentity else { throw CopyError.changedItem }
    }

    func validateSource() throws {
        try validateParents()
        guard try Identity.read(source) == sourceIdentity else { throw CopyError.changedItem }
    }

    func validate() throws {
        try validateSource()
        var occupied = stat()
        if lstat(destination.path, &occupied) == 0 { throw ItemName.ValidationError.collision }
        guard errno == ENOENT else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    struct Identity: Sendable, Equatable {
        let device: dev_t
        let inode: ino_t
        let kind: mode_t
        static func read(_ url: URL) throws -> Identity {
            var attributes = stat()
            guard lstat(url.path, &attributes) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            return Identity(device: attributes.st_dev, inode: attributes.st_ino, kind: attributes.st_mode & mode_t(S_IFMT))
        }
    }
}
