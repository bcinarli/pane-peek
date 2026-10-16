import Darwin
import Foundation

extension ItemMove {
    /// Metadata version of the regular file explicitly offered for replacement.
    struct Replacement: Sendable {
        let identity: ItemCopy.Identity
        let size: off_t
        let mode: mode_t
        let modifiedSeconds: time_t
        let modifiedNanoseconds: Int
        let changedSeconds: time_t
        let changedNanoseconds: Int

        init(_ url: URL) throws {
            var attributes = stat()
            guard lstat(url.path, &attributes) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw POSIXError(.ENOTSUP) }
            identity = ItemCopy.Identity(device: attributes.st_dev, inode: attributes.st_ino, kind: mode_t(S_IFREG))
            size = attributes.st_size
            mode = attributes.st_mode
            modifiedSeconds = attributes.st_mtimespec.tv_sec
            modifiedNanoseconds = attributes.st_mtimespec.tv_nsec
            changedSeconds = attributes.st_ctimespec.tv_sec
            changedNanoseconds = attributes.st_ctimespec.tv_nsec
        }

        func validate(_ url: URL, afterRename: Bool = false) throws {
            let current = try Replacement(url)
            guard current.identity == identity, current.size == size, current.mode == mode,
                  current.modifiedSeconds == modifiedSeconds, current.modifiedNanoseconds == modifiedNanoseconds,
                  afterRename || (current.changedSeconds == changedSeconds && current.changedNanoseconds == changedNanoseconds) else {
                throw ItemCopy.CopyError.changedItem
            }
        }
    }

    func replacementCandidate() async throws -> Replacement? {
        try await Task.detached(priority: .userInitiated) {
            try item.validateSource()
            guard item.isRegularFile, (try? source.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true,
                  (try? destination.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true else { return nil }
            return try? Replacement(destination)
        }.value
    }

    func replacing(_ candidate: Replacement) async throws -> ItemMove {
        try await Task.detached(priority: .userInitiated) {
            try item.validateSource()
            try candidate.validate(destination)
            return ItemMove(item: item, replacement: candidate)
        }.value
    }

    func acceptingSavedDestination(_ snapshot: TextFileSnapshot?) async throws -> ItemMove {
        try await Task.detached(priority: .userInitiated) {
            try item.validateSource()
            guard replacement != nil, let snapshot else { throw ItemCopy.CopyError.changedItem }
            try snapshot.validate(destination)
            let candidate = try Replacement(destination)
            try snapshot.validate(destination)
            return ItemMove(item: item, replacement: candidate)
        }.value
    }

    func validate() throws {
        if let replacement {
            try item.validateSource()
            try replacement.validate(destination)
        } else { try item.validate() }
    }

    /// Retain the previous destination until transfer success; recovery never overwrites a late winner.
    func moveReplacing(_ replacement: Replacement,
                       rename: @escaping @Sendable (URL, URL) throws -> Void,
                       copy: @escaping @Sendable (URL, URL) throws -> Void,
                       remove: @escaping @Sendable (URL) throws -> Void) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            let directory = destination.deletingLastPathComponent().appendingPathComponent(".panepeek-replace-\(UUID().uuidString)", isDirectory: true)
            let previous = directory.appendingPathComponent(destination.lastPathComponent)
            var directoryIdentity: ItemCopy.Identity?
            var previousIdentity: ItemCopy.Identity?
            var previousMoved = false
            var result: Outcome?
            var restored: URL?
            var errors: [String] = []
            do {
                try validate()
                try Task.checkCancellation()
                guard mkdir(directory.path, 0o700) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                directoryIdentity = try ItemCopy.Identity.read(directory)
                try validate()
                try Self.exclusiveRename(destination, previous)
                previousMoved = true
                previousIdentity = try ItemCopy.Identity.read(previous)
                try replacement.validate(previous, afterRename: true)
                result = await ItemMove(item: item).move(using: rename, copy: copy, remove: remove)
            } catch { errors.append(error.localizedDescription) }

            if let directoryIdentity {
                do {
                    try item.validateDestinationParent()
                    guard try ItemCopy.Identity.read(directory) == directoryIdentity else { throw ItemCopy.CopyError.changedItem }
                    if previousMoved {
                        guard let previousIdentity else { throw ItemCopy.CopyError.changedItem }
                        guard try ItemCopy.Identity.read(previous) == previousIdentity else { throw ItemCopy.CopyError.changedItem }
                        if result?.destinationPublished != true {
                            try Self.exclusiveRename(previous, destination)
                            restored = destination
                        } else if result?.succeeded != true {
                            throw POSIXError(.ECANCELED)
                        } else {
                            try replacement.validate(previous, afterRename: true)
                        }
                    }
                    try remove(directory)
                } catch {
                    errors.append("Recovery or cleanup did not complete. Previous destination may be retained at \(previous.path). \(error.localizedDescription) Inspect this path and \(destination.path) before retrying.")
                }
            }
            let succeeded = result?.succeeded == true && errors.isEmpty
            let message = result?.message ?? "Couldn’t replace \(destination.path) from \(source.path)."
            return Outcome(succeeded: succeeded, sourceRemoved: result?.sourceRemoved == true,
                           message: ([message] + errors).joined(separator: "\n"), destinationPublished: result?.destinationPublished == true, restoredDestination: restored)
        }.value
    }
}
