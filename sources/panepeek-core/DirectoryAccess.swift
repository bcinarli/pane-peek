import Foundation

/// Retains one acquired resource scope until its last consumer releases it.
public final class DirectoryAccess: Sendable {
    public enum Mode: String, Codable, Sendable { case readOnly, readWrite }
    public let mode: Mode
    public let root: URL
    private let release: @Sendable () -> Void

    public init(root: URL, mode: Mode = .readOnly, release: @escaping @Sendable () -> Void) {
        self.root = root
        self.mode = mode
        self.release = release
    }

    deinit { release() }
}
