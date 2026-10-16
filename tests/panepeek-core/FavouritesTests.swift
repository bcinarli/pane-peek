import Foundation
import Testing
@testable import PanePeekCore

struct FavouritesTests {
    @Test @MainActor func favouriteSearchMatchesNamesAndFullPathsWithoutChangingSavedOrder() throws {
        let suite = "com.bcinarli.PanePeek.tests.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let paths = ["/Work/Projects", "/Personal/Projects", "/Archive/Café Notes", "/"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        let favourites = Favourites(preferences: preferences)
        for directory in paths { favourites.toggle(directory) }

        for (query, indices) in [
            ("pRoJeCts", [0, 1]), (" /PERSONAL/ ", [1]), ("cafe notes", [2]),
            ("/Archive/Café Notes", [2]), ("not saved", []),
            ("", [0, 1, 2, 3]), (" \n ", [0, 1, 2, 3]), ("/", [0, 1, 2, 3])
        ] {
            #expect(favourites.directories(matching: query) == indices.map { paths[$0] })
        }
        #expect(favourites.directories == paths)
        #expect(Favourites(preferences: preferences).directories == paths)
    }

    @Test @MainActor func favouriteSearchTracksRemovalWithoutPersistingAFilteredList() throws {
        let suite = "com.bcinarli.PanePeek.tests.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let project = URL(fileURLWithPath: "/search/Projects", isDirectory: true)
        let notes = URL(fileURLWithPath: "/search/Notes", isDirectory: true)
        let favourites = Favourites(preferences: preferences)
        favourites.toggle(project)
        favourites.toggle(notes)
        #expect(favourites.directories(matching: "projects") == [project])
        favourites.remove(project)
        #expect(favourites.directories(matching: "projects").isEmpty)
        #expect(favourites.directories(matching: "notes") == [notes])
        #expect(favourites.directories == [notes])
        #expect(Favourites(preferences: preferences).directories == [notes])
    }

    @Test @MainActor func removesDeletedFavouriteWithoutReaddingItOrChangingOtherSavedPaths() throws {
        let fixture = try FavouritesFixture()
        defer { fixture.remove() }
        let suite = "com.bcinarli.PanePeek.tests.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let before = fixture.root.appendingPathComponent("before", isDirectory: true)
        let deleted = fixture.root.appendingPathComponent("deleted ü with spaces", isDirectory: true)
        let after = fixture.root.appendingPathComponent("after", isDirectory: true)
        let favourites = Favourites(preferences: preferences)
        for directory in [before, deleted, after] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            favourites.toggle(directory)
        }
        try FileManager.default.removeItem(at: deleted)

        let reloaded = Favourites(preferences: preferences)
        #expect(reloaded.directories == [before, deleted, after])
        let equivalent = deleted.appendingPathComponent("child/..", isDirectory: true)
        reloaded.remove(equivalent)
        #expect(reloaded.directories == [before, after])
        reloaded.remove(deleted)
        #expect(Favourites(preferences: try #require(UserDefaults(suiteName: suite))).directories == [before, after])
    }

    @Test @MainActor func togglesPersistAndEquivalentDisplayedDirectoriesShareOneFavourite() async throws {
        let fixture = try FavouritesFixture()
        defer { fixture.remove() }
        let suite = "com.bcinarli.PanePeek.tests.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let directory = fixture.root.appendingPathComponent("shared ü", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let link = fixture.root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        let displayed = try await DirectoryListing.read(link).directory
        let equivalent = directory.appendingPathComponent("child/..", isDirectory: true)
        let favourites = Favourites(preferences: preferences)
        favourites.toggle(displayed)
        try FileManager.default.moveItem(at: directory, to: fixture.root.appendingPathComponent("moved"))

        let reloaded = Favourites(preferences: try #require(UserDefaults(suiteName: suite)))
        #expect(reloaded.directories == [directory])
        #expect(reloaded.contains(equivalent))
        reloaded.toggle(equivalent)
        #expect(reloaded.directories.isEmpty)
        #expect(Favourites(preferences: preferences).directories.isEmpty)
    }

    @Test @MainActor func favouriteNavigationCapturesFocusAndRetainsSelectionOnFailure() async throws {
        let fixture = try FavouritesFixture()
        defer { fixture.remove() }
        let directory = fixture.root.appendingPathComponent("saved", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let leftItem = fixture.root.appendingPathComponent("left.txt")
        let rightItem = fixture.root.appendingPathComponent("right.txt")
        for item in [leftItem, rightItem] { try Data("fixture".utf8).write(to: item) }
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.navigate(to: fixture.root)
        await browser.right.navigate(to: fixture.root)
        browser.left.setSelection([leftItem])
        browser.right.setSelection([rightItem])

        browser.focus(.right)
        let request = browser.openFavourite(directory)
        browser.focus(.left)
        await request.value
        #expect(browser.right.directory == directory)
        #expect(browser.left.directory == fixture.root)
        #expect(browser.left.selectedItems == [leftItem])
        #expect(browser.focusedPane == .left)

        await browser.right.navigate(to: fixture.root)
        browser.right.setSelection([rightItem])
        try FileManager.default.moveItem(at: directory, to: fixture.root.appendingPathComponent("moved"))
        browser.focus(.right)
        await browser.openFavourite(directory).value
        #expect(browser.right.errorMessage?.contains(directory.path) == true)
        #expect(browser.right.directory == fixture.root)
        #expect(browser.right.selectedItems == [rightItem])
    }
}

private struct FavouritesFixture {
    let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        .appendingPathComponent("panepeek-favourites-\(UUID())", isDirectory: true)
    init() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
