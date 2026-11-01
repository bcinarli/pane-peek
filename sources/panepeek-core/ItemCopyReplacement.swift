import Darwin
import Foundation

extension ItemCopy {
    func acceptingSavedDestination(_ snapshot: TextFileSnapshot?) async throws -> ItemCopy {
        ItemCopy(transfer: try await transfer.acceptingSavedDestination(snapshot))
    }

    /// Copy privately before displacing the approved destination; recovery never overwrites a late winner.
    func copyReplacing(_ replacement: ItemTransfer.Replacement,
                       using write: @escaping @Sendable (URL, URL) throws -> Void,
                       publish: @escaping @Sendable (URL, URL) throws -> Void = ItemTransfer.exclusiveRename) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            let directory = destination.deletingLastPathComponent().appendingPathComponent(".panepeek-replace-\(UUID().uuidString)", isDirectory: true)
            let previous = directory.appendingPathComponent("previous")
            let incoming = directory.appendingPathComponent("incoming")
            var directoryIdentity: ItemTransfer.Identity?
            var previousIdentity: ItemTransfer.Identity?
            var previousMoved = false
            var published = false
            var restored = false
            var errors: [String] = []
            do {
                try transfer.validate()
                try Task.checkCancellation()
                guard mkdir(directory.path, 0o700) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                directoryIdentity = try ItemTransfer.Identity.read(directory)
                try write(source, incoming)
                try transfer.validate()
                try Task.checkCancellation()
                try ItemTransfer.exclusiveRename(destination, previous)
                previousMoved = true
                previousIdentity = try ItemTransfer.Identity.read(previous)
                try replacement.validate(previous, afterRename: true)
                try transfer.validateSource()
                try publish(incoming, destination)
                published = true
            } catch { errors.append(error.localizedDescription) }

            if let directoryIdentity {
                do {
                    try transfer.validateDestinationParent()
                    guard try ItemTransfer.Identity.read(directory) == directoryIdentity else { throw ItemTransfer.ValidationError.changedItem }
                    if previousMoved {
                        guard let previousIdentity else { throw ItemTransfer.ValidationError.changedItem }
                        guard try ItemTransfer.Identity.read(previous) == previousIdentity else { throw ItemTransfer.ValidationError.changedItem }
                        if !published {
                            try ItemTransfer.exclusiveRename(previous, destination)
                            restored = true
                        } else { try replacement.validate(previous, afterRename: true) }
                    }
                    try FileManager.default.removeItem(at: directory)
                } catch {
                    errors.append("Recovery or cleanup did not complete. Previous destination may be retained at \(previous.path). \(error.localizedDescription) Inspect this path and \(destination.path) before retrying.")
                }
            }
            let message = published ? "Copied \(source.path) to \(destination.path)." : "Couldn’t replace \(destination.path) from \(source.path)."
            return Outcome(succeeded: published && errors.isEmpty, message: ([message] + errors).joined(separator: "\n"),
                           completed: published ? [destination] : [], failed: errors.isEmpty ? nil : source,
                           replaced: published ? [destination] : [], restored: restored ? [destination] : [])
        }.value
    }
}
