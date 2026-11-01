import Darwin
import Foundation

/// Captured identity and destination decisions shared by copy and move requests.
public struct ItemTransfer: Sendable {
    let source: URL
    let destination: URL
    let isDirectory: Bool
    private let sourceIdentity: Identity
    private let parentIdentity: Identity
    private let destinationIdentity: Identity
    var replacement: Replacement? = nil

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

    public enum ValidationError: LocalizedError, Equatable {
        case ancestry, changedItem, sameItem
        public var errorDescription: String? {
            switch self {
            case .ancestry: "A folder cannot be transferred into itself or a descendant. Choose another destination."
            case .sameItem: "An item cannot be transferred onto itself. Choose another destination."
            case .changedItem: "The source or one of the captured directories changed. Refresh and try again."
            }
        }
    }

    struct PreflightError: Error, Sendable {
        let source: URL
        let destination: URL
        let reason: String
    }

    static func capture(_ sources: [URL], to directory: URL, allowingCollisions: Bool = false,
                        allowingSameFolderCopies: Bool = false) async throws -> [ItemTransfer] {
        try await Task.detached(priority: .userInitiated) {
            guard !sources.isEmpty, directory.isFileURL, sources.allSatisfy(\.isFileURL) else { throw POSIXError(.EINVAL) }
            let directory = directory.resolvingSymlinksInPath()
            let caseSensitive = (try? directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames
            var names: Set<Data> = []
            var items: [ItemTransfer] = []
            for source in sources {
                do {
                    let item = try ItemTransfer.captured(source, to: directory, allowingCollision: allowingCollisions,
                                                         allowingSameFolderCopy: allowingSameFolderCopies)
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
            return items
        }.value
    }

    @MainActor static func resolvingCollisions(_ items: [ItemTransfer], operation kind: Collision.Operation, _ choose: (Collision) async -> CollisionChoice) async throws -> [ItemTransfer]? {
        var resolved = items
        for index in resolved.indices {
            let operation = resolved[index]
            do {
                let sameFolderCopy = kind == .copy && operation.hasSameContainingDirectory
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
        return resolved
    }

    /// Preflight before prompting for affected drafts, without following the final source link.
    static func capture(_ source: URL, to directory: URL) async throws -> ItemTransfer {
        try await Task.detached(priority: .userInitiated) { try captured(source, to: directory) }.value
    }

    private static func captured(_ source: URL, to directory: URL, allowingCollision: Bool = false,
                                 allowingSameFolderCopy: Bool = false) throws -> ItemTransfer {
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
            throw ValidationError.ancestry
        }
        let request = ItemTransfer(source: source, destination: directory.appendingPathComponent(source.lastPathComponent),
                                   isDirectory: isDirectory, sourceIdentity: identity,
                                   parentIdentity: try Identity.read(parent), destinationIdentity: destinationIdentity)
        let rejectSameItem = allowingCollision && !(allowingSameFolderCopy && request.hasSameContainingDirectory)
        if try request.destinationIsOccupied(rejectingSameItem: rejectSameItem), !allowingCollision { throw ItemName.ValidationError.collision }
        return request
    }

    var isRegularFile: Bool { sourceIdentity.kind == mode_t(S_IFREG) }
    var hasSameContainingDirectory: Bool { parentIdentity == destinationIdentity }

    func affects(_ url: URL) -> Bool {
        url.path == source.path || (isDirectory && url.path.hasPrefix(source.path + "/"))
    }

    /// An explicit Save changes the inode; accept only the saved document's verified baseline.
    func acceptingSavedSource(_ snapshot: TextFileSnapshot?) async throws -> ItemTransfer {
        try await Task.detached(priority: .userInitiated) {
            try validateParents()
            guard let snapshot else { throw ValidationError.changedItem }
            try snapshot.validate(source)
            return ItemTransfer(source: source, destination: destination, isDirectory: isDirectory,
                                sourceIdentity: try Identity.read(source), parentIdentity: parentIdentity,
                                destinationIdentity: destinationIdentity, replacement: replacement)
        }.value
    }

    private func availableName(reserving operations: [ItemTransfer], rejectingSameItem: Bool = true) async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            guard try destinationIsOccupied(rejectingSameItem: rejectingSameItem) else { return nil }
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

    private func retargeted(named name: String, reserving operations: [ItemTransfer]) async throws -> ItemTransfer {
        try await Task.detached(priority: .userInitiated) {
            try ItemName.validate(name)
            let directory = destination.deletingLastPathComponent()
            let caseSensitive = (try? directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames
            guard !operations.contains(where: {
                $0.source.path != source.path && Self.nameKey($0.destination.lastPathComponent, caseSensitive: caseSensitive) == Self.nameKey(name, caseSensitive: caseSensitive)
            }) else { throw ItemName.ValidationError.collision }
            return try retargeted(named: name)
        }.value
    }

    private static func nameKey(_ name: String, caseSensitive: Bool?) -> String {
        caseSensitive == false ? name.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX")) : name
    }

    private func validateParents() throws {
        guard try Identity.read(source.deletingLastPathComponent()) == parentIdentity else { throw ValidationError.changedItem }
        try validateDestinationParent()
    }

    func validateDestinationParent() throws {
        guard try Identity.read(destination.deletingLastPathComponent()) == destinationIdentity else { throw ValidationError.changedItem }
    }

    func validateSource() throws {
        try validateParents()
        guard try Identity.read(source) == sourceIdentity else { throw ValidationError.changedItem }
    }

    func validate() throws {
        if let replacement {
            try validateSource()
            try replacement.validate(destination)
        } else if try destinationIsOccupied() { throw ItemName.ValidationError.collision }
    }

    func destinationIsOccupied(rejectingSameItem: Bool = false) throws -> Bool {
        try validateSource()
        var occupied = stat()
        if lstat(destination.path, &occupied) == 0 {
            if rejectingSameItem {
                guard try Identity.read(destination) != sourceIdentity else { throw ValidationError.sameItem }
            }
            return true
        }
        guard errno == ENOENT else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return false
    }

    /// Keep the captured source identity when only the destination name changes.
    func retargeted(named name: String) throws -> ItemTransfer {
        try ItemName.validate(name)
        let request = ItemTransfer(source: source, destination: destination.deletingLastPathComponent().appendingPathComponent(name),
                                   isDirectory: isDirectory, sourceIdentity: sourceIdentity,
                                   parentIdentity: parentIdentity, destinationIdentity: destinationIdentity)
        try request.validate()
        return request
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

    static func exclusiveRename(_ source: URL, _ destination: URL) throws {
        guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
