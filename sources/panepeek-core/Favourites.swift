import Foundation
import Observation

@MainActor @Observable
public final class Favourites {
    public private(set) var directories: [URL] = []
    private let preferences: UserDefaults
    private static let preferenceKey = "favouriteDirectories"

    /// The caller supplies the app's preferences or an isolated test suite.
    public init(preferences: UserDefaults) {
        self.preferences = preferences
        for path in preferences.stringArray(forKey: Self.preferenceKey) ?? [] where path.hasPrefix("/") {
            let directory = Self.normalized(URL(fileURLWithPath: path, isDirectory: true))
            if !directories.contains(directory) { directories.append(directory) }
        }
    }

    /// Filter saved names and paths without changing their order or checking availability.
    public func directories(matching query: String) -> [URL] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return directories }
        return directories.filter { $0.path.localizedStandardContains(query) }
    }

    public func contains(_ directory: URL) -> Bool {
        directories.contains(Self.normalized(directory))
    }

    /// Remove a saved path without checking availability; repeated removal has no effect.
    public func remove(_ directory: URL) {
        guard directory.isFileURL,
              let index = directories.firstIndex(of: Self.normalized(directory)) else { return }
        directories.remove(at: index)
        preferences.set(directories.map(\.path), forKey: Self.preferenceKey)
    }

    /// Toggle a pane's already resolved, displayed directory without checking its availability.
    public func toggle(_ directory: URL) {
        guard directory.isFileURL else { return }
        let directory = Self.normalized(directory)
        if let index = directories.firstIndex(of: directory) {
            directories.remove(at: index)
        } else {
            directories.append(directory)
        }
        preferences.set(directories.map(\.path), forKey: Self.preferenceKey)
    }

    private static func normalized(_ directory: URL) -> URL {
        URL(fileURLWithPath: directory.standardizedFileURL.path, isDirectory: true)
    }
}
