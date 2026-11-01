import Darwin
import Foundation

extension ItemMove {
    func acceptingSavedDestination(_ snapshot: TextFileSnapshot?) async throws -> ItemMove {
        ItemMove(transfer: try await transfer.acceptingSavedDestination(snapshot))
    }

    /// Retain the previous destination until transfer success; recovery never overwrites a late winner.
    func moveReplacing(_ replacement: ItemTransfer.Replacement,
                       rename: @escaping @Sendable (URL, URL) throws -> Void,
                       copy: @escaping @Sendable (URL, URL) throws -> Void,
                       remove: @escaping @Sendable (URL) throws -> Void) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            let directory = destination.deletingLastPathComponent().appendingPathComponent(".panepeek-replace-\(UUID().uuidString)", isDirectory: true)
            let previous = directory.appendingPathComponent(destination.lastPathComponent)
            var directoryIdentity: ItemTransfer.Identity?
            var previousIdentity: ItemTransfer.Identity?
            var previousMoved = false
            var result: Outcome?
            var restored: URL?
            var errors: [String] = []
            do {
                try transfer.validate()
                try Task.checkCancellation()
                guard mkdir(directory.path, 0o700) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                directoryIdentity = try ItemTransfer.Identity.read(directory)
                try transfer.validate()
                try ItemTransfer.exclusiveRename(destination, previous)
                previousMoved = true
                previousIdentity = try ItemTransfer.Identity.read(previous)
                try replacement.validate(previous, afterRename: true)
                var incoming = transfer
                incoming.replacement = nil
                result = await ItemMove(transfer: incoming).move(using: rename, copy: copy, remove: remove)
            } catch { errors.append(error.localizedDescription) }

            if let directoryIdentity {
                do {
                    try transfer.validateDestinationParent()
                    guard try ItemTransfer.Identity.read(directory) == directoryIdentity else { throw ItemTransfer.ValidationError.changedItem }
                    if previousMoved {
                        guard let previousIdentity else { throw ItemTransfer.ValidationError.changedItem }
                        guard try ItemTransfer.Identity.read(previous) == previousIdentity else { throw ItemTransfer.ValidationError.changedItem }
                        if result?.destinationPublished != true {
                            try ItemTransfer.exclusiveRename(previous, destination)
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
