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
