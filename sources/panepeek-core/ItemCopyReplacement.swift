import Darwin
import Foundation

extension ItemCopy {
    func acceptingSavedDestination(_ snapshot: TextFileSnapshot?) async throws -> ItemCopy {
        let transfer = try await ItemMove(item: self, replacement: replacement).acceptingSavedDestination(snapshot)
        var copy = self
        copy.replacement = transfer.replacement
        return copy
    }

    /// Copy privately before displacing the approved destination; recovery never overwrites a late winner.
    func copyReplacing(_ replacement: ItemMove.Replacement,
                       using write: @escaping @Sendable (URL, URL) throws -> Void,
                       publish: @escaping @Sendable (URL, URL) throws -> Void = ItemMove.exclusiveRename) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            let directory = destination.deletingLastPathComponent().appendingPathComponent(".panepeek-replace-\(UUID().uuidString)", isDirectory: true)
            let previous = directory.appendingPathComponent("previous")
            let incoming = directory.appendingPathComponent("incoming")
            var directoryIdentity: Identity?
            var previousIdentity: Identity?
            var previousMoved = false
            var published = false
            var restored = false
            var errors: [String] = []
            do {
                try validate()
                try Task.checkCancellation()
                guard mkdir(directory.path, 0o700) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                directoryIdentity = try Identity.read(directory)
                try write(source, incoming)
                try validate()
                try Task.checkCancellation()
                try ItemMove.exclusiveRename(destination, previous)
                previousMoved = true
                previousIdentity = try Identity.read(previous)
                try replacement.validate(previous, afterRename: true)
                try validateSource()
                try publish(incoming, destination)
                published = true
            } catch { errors.append(error.localizedDescription) }

            if let directoryIdentity {
                do {
                    try validateDestinationParent()
                    guard try Identity.read(directory) == directoryIdentity else { throw CopyError.changedItem }
                    if previousMoved {
                        guard let previousIdentity else { throw CopyError.changedItem }
                        guard try Identity.read(previous) == previousIdentity else { throw CopyError.changedItem }
                        if !published {
                            try ItemMove.exclusiveRename(previous, destination)
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
