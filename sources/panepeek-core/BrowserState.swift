import Foundation
import Observation

public enum PaneID: Sendable {
    case left, right
}

@MainActor @Observable
public final class DirectoryPane {
    public private(set) var directory: URL
    public private(set) var entries: [DirectoryEntry] = []
    public private(set) var isLoading = false
    public private(set) var hasLoaded = false
    public private(set) var errorMessage: String?
    private let load: @Sendable (URL) async throws -> DirectoryListing
    private var requestID = UUID()

    public init(directory: URL, load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read) {
        self.directory = directory
        self.load = load
    }

    /// Root-to-current directories for the pane's displayed location.
    public var breadcrumbDirectories: [URL] {
        var current = directory
        var ancestors = [current]
        while current.path != "/" {
            current.deleteLastPathComponent()
            ancestors.append(current)
        }
        return ancestors.reversed()
    }

    public func navigate(to directory: URL) async {
        let request = UUID()
        requestID = request
        isLoading = true
        errorMessage = nil
        do {
            let listing = try await load(directory)
            guard requestID == request else { return }
            self.directory = listing.directory
            self.entries = listing.entries
            hasLoaded = true
        } catch {
            guard requestID == request else { return }
            errorMessage = "Couldn’t open \(directory.path). \(error.localizedDescription)"
        }
        isLoading = false
    }

    public func navigate(toPath path: String) async {
        guard path.hasPrefix("/") else {
            requestID = UUID()
            isLoading = false
            errorMessage = "Enter an absolute directory path starting with /."
            return
        }
        await navigate(to: URL(fileURLWithPath: path, isDirectory: true))
    }
}

@MainActor @Observable
public final class BrowserState {
    public let left: DirectoryPane
    public let right: DirectoryPane
    public let homeDirectory: URL
    public private(set) var focusedPane: PaneID = .left

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
                load: @escaping @Sendable (URL) async throws -> DirectoryListing = DirectoryListing.read) {
        self.homeDirectory = homeDirectory
        left = DirectoryPane(directory: homeDirectory, load: load)
        right = DirectoryPane(directory: homeDirectory, load: load)
    }

    public func pane(_ id: PaneID) -> DirectoryPane {
        id == .left ? left : right
    }

    public func focus(_ id: PaneID) {
        focusedPane = id
    }

}
