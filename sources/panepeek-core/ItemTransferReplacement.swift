import Darwin
import Foundation

extension ItemTransfer {
    /// Metadata version of the regular file explicitly offered for replacement.
    struct Replacement: Sendable {
        let identity: Identity
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
            identity = Identity(device: attributes.st_dev, inode: attributes.st_ino, kind: mode_t(S_IFREG))
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
                throw ValidationError.changedItem
            }
        }
    }

    func replacementCandidate() async throws -> Replacement? {
        try await Task.detached(priority: .userInitiated) {
            try validateSource()
            guard isRegularFile, (try? source.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true,
                  (try? destination.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true else { return nil }
            return try? Replacement(destination)
        }.value
    }

    func replacing(_ candidate: Replacement) async throws -> ItemTransfer {
        try await Task.detached(priority: .userInitiated) {
            try validateSource()
            try candidate.validate(destination)
            var transfer = self
            transfer.replacement = candidate
            return transfer
        }.value
    }

    func acceptingSavedDestination(_ snapshot: TextFileSnapshot?) async throws -> ItemTransfer {
        try await Task.detached(priority: .userInitiated) {
            try validateSource()
            guard replacement != nil, let snapshot else { throw ValidationError.changedItem }
            try snapshot.validate(destination)
            let candidate = try Replacement(destination)
            try snapshot.validate(destination)
            var transfer = self
            transfer.replacement = candidate
            return transfer
        }.value
    }
}
