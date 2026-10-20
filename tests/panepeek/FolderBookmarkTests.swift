import Foundation
import Synchronization
import Testing
import PanePeekCore
@testable import PanePeek

@MainActor struct FolderBookmarkTests {
    @Test func movedRootRestoresItsChildAndRefreshesStaleData() async throws {
        let fixture = try BookmarkFixture()
        defer { fixture.finish() }
        let child = fixture.root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        let first = fixture.access()
        var listing: DirectoryListing? = try await first.read(child) { _ in fixture.root }
        #expect(listing?.directory == fixture.root)
        listing = try await first.read(child) { _ in Issue.record("Repeated grant"); return nil }
        let location = try #require(first.location(for: child))
        listing = nil
        let moved = fixture.base.appendingPathComponent("moved", isDirectory: true)
        try FileManager.default.moveItem(at: fixture.root, to: moved)
        // A replacement at the old path must not redirect the saved location.
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let created = Mutex<[URL]>([])
        var bookmarking = fixture.bookmarking
        let originalRoot = fixture.root
        bookmarking.resolve = { data in
            let path = String(decoding: data, as: UTF8.self)
            let suffix = URL(fileURLWithPath: path).pathComponents.dropFirst(originalRoot.pathComponents.count)
            return .init(url: suffix.reduce(moved) { $0.appendingPathComponent($1, isDirectory: true) }, stale: true)
        }
        bookmarking.create = { url, _ in created.withLock { $0.append(url) }; return Data(url.path.utf8) }
        let next = fixture.access(bookmarking: bookmarking)
        var restored: DirectoryListing? = try await next.readSaved(child, location: location)
        #expect(restored?.directory == moved.appendingPathComponent("child", isDirectory: true))
        #expect(created.withLock { $0 } == [moved.appendingPathComponent("child", isDirectory: true)])
        let restoredDirectory = try #require(restored).directory
        let updated = try #require(next.location(for: restoredDirectory))
        restored = nil
        let afterRefresh = fixture.access()
        let refreshed = try await afterRefresh.readSaved(child, location: updated)
        #expect(refreshed.directory == moved.appendingPathComponent("child", isDirectory: true))
        let parent = try await next.read(moved) { _ in Issue.record("Moved grant prompted again"); return nil }
        #expect(parent.directory == moved)
    }

    @Test(arguments: [false, true]) func aReplacementAtTheOldPathCannotInheritSavedAccess(cached: Bool) async throws {
        let fixture = try BookmarkFixture()
        defer { fixture.finish() }
        let first = fixture.access()
        var listing: DirectoryListing? = try await first.read(fixture.root) { _ in fixture.root }
        let location = try #require(first.location(for: fixture.root))
        #expect(listing != nil)
        listing = nil
        let stopped = Mutex(0)
        let next = fixture.access(stop: { _ in stopped.withLock { $0 += 1 } })
        var held: DirectoryListing? = cached ? try await next.readSaved(fixture.root, location: location) : nil
        #expect(!cached || held != nil)
        try FileManager.default.moveItem(at: fixture.root, to: fixture.base.appendingPathComponent("moved"))
        try FileManager.default.createDirectory(at: fixture.root, withIntermediateDirectories: false)
        await #expect(throws: (any Error).self) { _ = try await next.readSaved(fixture.root, location: location) }
        #expect(stopped.withLock { $0 } == (cached ? 0 : 1))
        held = nil
        #expect(stopped.withLock { $0 } == 1)
    }

    @Test func replacementDuringBookmarkRefreshCannotPublishASavedListing() async throws {
        let fixture = try BookmarkFixture()
        defer { fixture.finish() }
        let first = fixture.access()
        var original: DirectoryListing? = try await first.read(fixture.root) { _ in fixture.root }
        let location = try #require(first.location(for: fixture.root))
        #expect(original != nil)
        original = nil
        var bookmarking = fixture.bookmarking
        let root = fixture.root
        let moved = fixture.base.appendingPathComponent("moved")
        bookmarking.create = { url, _ in
            try FileManager.default.moveItem(at: root, to: moved)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            return Data(url.path.utf8)
        }
        await #expect(throws: (any Error).self) {
            _ = try await fixture.access(bookmarking: bookmarking).readSaved(root, location: location)
        }
    }

    @Test func unavailableBookmarkSurvivesAndCanBeRetriedWithoutAChooser() async throws {
        let fixture = try BookmarkFixture()
        defer { fixture.finish() }
        let first = fixture.access()
        var listing: DirectoryListing? = try await first.read(fixture.root) { _ in fixture.root }
        let directory = try #require(listing).directory
        let location = try #require(first.location(for: directory))
        listing = nil
        let original = fixture.preferences.data(forKey: "sandboxFolderBookmarks")
        var unavailable = fixture.bookmarking
        unavailable.resolve = { _ in throw CocoaError(.fileNoSuchFile) }
        await #expect(throws: (any Error).self) {
            _ = try await fixture.access(bookmarking: unavailable).readSaved(fixture.root, location: location)
        }
        #expect(fixture.preferences.data(forKey: "sandboxFolderBookmarks") == original)
        let retried = try await fixture.access().readSaved(fixture.root, location: location)
        #expect(retried.directory == fixture.root)
    }

    @Test func failedScopeStartIsNotReleasedAndFailedBookmarkCreationReleasesNativeGrant() async throws {
        let fixture = try BookmarkFixture()
        defer { fixture.finish() }
        let first = fixture.access()
        var listing: DirectoryListing? = try await first.read(fixture.root) { _ in fixture.root }
        #expect(listing != nil)
        listing = nil
        let stopped = Mutex(0)
        var denied = fixture.bookmarking
        denied.start = { _ in false }
        let next = fixture.access(bookmarking: denied, stop: { _ in stopped.withLock { $0 += 1 } })
        await #expect(throws: (any Error).self) { _ = try await next.readSaved(fixture.root, location: nil) }
        #expect(stopped.withLock { $0 } == 0)
        var broken = fixture.bookmarking
        broken.create = { _, _ in throw CocoaError(.fileWriteUnknown) }
        let chosen = fixture.access(bookmarking: broken, stop: { _ in stopped.withLock { $0 += 1 } })
        await #expect(throws: (any Error).self) { _ = try await chosen.select(initial: fixture.root) { _ in fixture.root } }
        #expect(stopped.withLock { $0 } == 1)
    }

    @Test func restorationRejectsInvalidBookmarkURLsAndUngrantableLinkTargets() async throws {
        let fixture = try BookmarkFixture()
        defer { fixture.finish() }
        let first = fixture.access()
        let listing = try await first.read(fixture.root) { _ in fixture.root }
        let location = try #require(first.location(for: listing.directory))
        var invalid = fixture.bookmarking
        invalid.resolve = { _ in .init(url: URL(string: "https://example.com")!, stale: false) }
        let next = fixture.access(bookmarking: invalid)
        await #expect(throws: (any Error).self) {
            _ = try await next.readSaved(fixture.root, location: location)
        }
        let outside = fixture.base.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("link"), withDestinationURL: outside)
        await #expect(throws: (any Error).self) {
            _ = try await first.readSaved(fixture.root.appendingPathComponent("link"), location: nil)
        }
    }

    @Test func windowRestorationRetainsAnUnavailableLocationAndKeepsFreshWindowsIndependent() async throws {
        let fixture = try BookmarkFixture()
        defer { fixture.finish() }
        let access = fixture.access()
        let browser = fixture.browser(access)
        let sizing = DetailsSizing()
        await WindowRestoration(preferences: fixture.preferences, folderAccess: access).start(browser, sizing: sizing)
        #expect(!browser.left.hasLoaded && !browser.right.hasLoaded)
        await browser.left.navigate(to: fixture.root)
        #expect(browser.left.hasLoaded)
        let restoration = WindowRestoration(preferences: fixture.preferences, folderAccess: access)
        restoration.remember(browser, sizing: sizing)
        let original = try #require(fixture.preferences.dictionary(forKey: "rememberedWindow"))
        browser.left.releaseAccess()
        var unavailable = fixture.bookmarking
        unavailable.resolve = { _ in throw CocoaError(.fileNoSuchFile) }
        let missingAccess = fixture.access(bookmarking: unavailable)
        let missing = fixture.browser(missingAccess, choose: false)
        let missingRestoration = WindowRestoration(preferences: fixture.preferences, folderAccess: missingAccess)
        await missingRestoration.start(missing, sizing: sizing)
        #expect(missing.left.directory == fixture.root && !missing.left.hasLoaded)
        missingRestoration.remember(missing, sizing: sizing)
        #expect(NSDictionary(dictionary: try #require(fixture.preferences.dictionary(forKey: "rememberedWindow"))).isEqual(to: original))
        let nextAccess = fixture.access()
        let next = fixture.browser(nextAccess, choose: false)
        let nextRestoration = WindowRestoration(preferences: fixture.preferences, folderAccess: nextAccess)
        await nextRestoration.start(next, sizing: sizing)
        #expect(next.left.hasLoaded && next.left.directory == fixture.root)
        #expect(!next.right.hasLoaded)
        let fresh = fixture.browser(nextAccess, choose: false)
        await nextRestoration.start(fresh, sizing: DetailsSizing())
        #expect(fresh.left.directory == fixture.home && !fresh.left.hasLoaded)
        #expect(fresh.mode == .twoPanes)
        next.left.releaseAccess()
    }
}

@MainActor private final class BookmarkFixture {
    let domain = "panepeek-bookmarks-" + UUID().uuidString
    let preferences: UserDefaults
    let base: URL
    let root: URL
    let home: URL
    let bookmarking = FolderAccess.Bookmarking(
        create: { url, _ in Data(url.path.utf8) },
        resolve: { .init(url: URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true), stale: false) },
        start: { _ in true })

    init() throws {
        preferences = try #require(UserDefaults(suiteName: domain))
        base = FileManager.default.temporaryDirectory.appendingPathComponent(domain, isDirectory: true).resolvingSymlinksInPath()
        root = base.appendingPathComponent("project", isDirectory: true)
        home = base.appendingPathComponent("home", isDirectory: true)
        for directory in [root, home] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }
    func access(bookmarking: FolderAccess.Bookmarking? = nil, stop: @escaping @Sendable (URL) -> Void = { _ in }) -> FolderAccess {
        FolderAccess(preferences: preferences, bookmarking: bookmarking ?? self.bookmarking, stop: stop)
    }
    func browser(_ access: FolderAccess, choose: Bool = true) -> BrowserState {
        BrowserState(homeDirectory: home, requiresFolderAccess: true, load: { [root] url in
            try await access.read(url) { _ in
                if !choose { Issue.record("Unexpected restoration prompt"); return nil }
                return root
            }
        })
    }
    func finish() {
        preferences.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: base)
    }
}
