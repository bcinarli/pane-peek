import Foundation
import Observation

@MainActor @Observable
public final class Favourites {
    public private(set) var directories: [URL] = []
    private var bookmarks: [String: Data] = [:]
    private let preferences: UserDefaults
    private static let preferenceKey = "favouriteDirectories"
    private static let bookmarkKey = "favouriteBookmarks"

    /// The caller supplies the app's preferences or an isolated test suite.
    public init(preferences: UserDefaults) {
        self.preferences = preferences
        for path in preferences.stringArray(forKey: Self.preferenceKey) ?? [] where path.hasPrefix("/") {
            let directory = Self.normalized(URL(fileURLWithPath: path, isDirectory: true))
            if !directories.contains(directory) { directories.append(directory) }
        }
        let saved = preferences.dictionary(forKey: Self.bookmarkKey) as? [String: Data] ?? [:]
        for directory in directories { bookmarks[directory.path] = saved[directory.path] }
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
        bookmarks.removeValue(forKey: Self.normalized(directory).path)
        persist()
    }

    /// Toggle a pane's already resolved, displayed directory without checking its availability.
    public func toggle(_ directory: URL, bookmark: Data? = nil) {
        guard directory.isFileURL else { return }
        let directory = Self.normalized(directory)
        if contains(directory) { remove(directory) }
        else {
            directories.append(directory)
            bookmarks[directory.path] = bookmark
            persist()
        }
    }

    /// Opaque access data is interpreted by the app's permission layer.
    public func bookmark(for directory: URL) -> Data? { bookmarks[Self.normalized(directory).path] }

    /// Keep delayed resolution from recreating a removed or replaced favourite.
    public func updateLocation(_ directory: URL, resolved: URL, bookmark: Data, replacing expected: Data?) {
        guard directory.isFileURL, resolved.isFileURL else { return }
        let directory = Self.normalized(directory)
        let resolved = Self.normalized(resolved)
        guard let index = directories.firstIndex(of: directory), bookmarks[directory.path] == expected else { return }
        directories[index] = resolved
        var seen = Set<URL>()
        directories = directories.filter { seen.insert($0).inserted }
        bookmarks.removeValue(forKey: directory.path)
        bookmarks[resolved.path] = bookmark
        persist()
    }

    private func persist() {
        preferences.set(directories.map(\.path), forKey: Self.preferenceKey)
        if !bookmarks.isEmpty { preferences.set(bookmarks, forKey: Self.bookmarkKey) }
        else if preferences.object(forKey: Self.bookmarkKey) != nil { preferences.removeObject(forKey: Self.bookmarkKey) }
    }

    private static func normalized(_ directory: URL) -> URL {
        URL(fileURLWithPath: directory.standardizedFileURL.path, isDirectory: true)
    }
}
