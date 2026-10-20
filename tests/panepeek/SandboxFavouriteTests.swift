import Foundation
import Synchronization
import Testing
import PanePeekCore
@testable import PanePeek

@MainActor struct SandboxFavouriteTests {
    @Test func renamedFavouriteReopensAndUpdatesItsSavedPathWithoutAChooser() async throws {
        let fixture = try FavouriteAccessFixture()
        defer { fixture.finish() }
        try await fixture.saveFavourite()
        let moved = fixture.base.appendingPathComponent("renamed", isDirectory: true)
        try FileManager.default.moveItem(at: fixture.target, to: moved)
        var bookmarking = fixture.bookmarking
        bookmarking.resolve = { _ in .init(url: moved, stale: true) }
        let access = fixture.access(bookmarking: bookmarking)
        let pane = fixture.pane()
        await pane.navigate(to: fixture.other)
        await access.openFavourite(fixture.target, in: pane, favourites: fixture.favourites) { _ in
            Issue.record("A valid saved favourite requested access again"); return nil
        }
        #expect(pane.directory == moved)
        #expect(fixture.favourites.directories == [moved])
        #expect(Favourites(preferences: fixture.preferences).bookmark(for: moved) != nil)
        pane.releaseAccess()
    }

    @Test func cancelledReconnectionKeepsTheListingSelectionAndSavedFavourite() async throws {
        let fixture = try FavouriteAccessFixture()
        defer { fixture.finish() }
        try await fixture.saveFavourite()
        let original = fixture.favourites.bookmark(for: fixture.target)
        var bookmarking = fixture.bookmarking
        bookmarking.resolve = { _ in throw CocoaError(.fileNoSuchFile) }
        let pane = fixture.pane()
        await pane.navigate(to: fixture.other)
        let item = try #require(pane.entries.first).url
        pane.setSelection([item])
        var choices = 0
        await fixture.access(bookmarking: bookmarking).openFavourite(fixture.target, in: pane, favourites: fixture.favourites) { _ in
            choices += 1; return nil
        }
        #expect(choices == 1 && pane.directory == fixture.other)
        #expect(pane.selectedItems == [item] && pane.errorMessage == nil)
        #expect(fixture.favourites.bookmark(for: fixture.target) == original)
    }

    @Test func choosingADifferentFolderDoesNotReplaceTheFavourite() async throws {
        let fixture = try FavouriteAccessFixture()
        defer { fixture.finish() }
        try await fixture.saveFavourite()
        let original = fixture.favourites.bookmark(for: fixture.target)
        var bookmarking = fixture.bookmarking
        bookmarking.resolve = { _ in throw CocoaError(.fileNoSuchFile) }
        let pane = fixture.pane()
        await fixture.access(bookmarking: bookmarking).openFavourite(fixture.target, in: pane, favourites: fixture.favourites) { _ in fixture.other }
        #expect(pane.directory == fixture.other)
        #expect(fixture.favourites.directories == [fixture.target])
        #expect(fixture.favourites.bookmark(for: fixture.target) == original)
        pane.releaseAccess()
    }

    @Test func legacyPathRequiresAnExplicitGrantBeforeItGainsABookmark() async throws {
        let fixture = try FavouriteAccessFixture()
        defer { fixture.finish() }
        fixture.favourites.toggle(fixture.target)
        let pane = fixture.pane()
        var choices = 0
        await fixture.access().openFavourite(fixture.target, in: pane, favourites: fixture.favourites) { hint in
            #expect(hint == fixture.target)
            choices += 1; return fixture.target
        }
        #expect(choices == 1 && pane.directory == fixture.target)
        #expect(fixture.favourites.bookmark(for: fixture.target) != nil)
        pane.releaseAccess()
    }

    @Test func staleChoiceCannotRedirectThePaneOrRecreateARemovedFavourite() async throws {
        let fixture = try FavouriteAccessFixture()
        defer { fixture.finish() }
        fixture.favourites.toggle(fixture.target)
        let pane = fixture.pane()
        await fixture.access().openFavourite(fixture.target, in: pane, favourites: fixture.favourites) { _ in
            fixture.favourites.remove(fixture.target)
            await pane.navigate(to: fixture.other)
            return fixture.target
        }
        #expect(pane.directory == fixture.other)
        #expect(fixture.favourites.directories.isEmpty)
    }

    @Test func removingAFavouriteDoesNotReleaseAPanesAccess() async throws {
        let fixture = try FavouriteAccessFixture()
        defer { fixture.finish() }
        let stops = Mutex(0)
        let access = fixture.access(stop: { _ in stops.withLock { $0 += 1 } })
        var listing: DirectoryListing? = try await access.read(fixture.target) { _ in fixture.target }
        access.toggleFavourite(fixture.target, favourites: fixture.favourites)
        fixture.favourites.remove(fixture.target)
        #expect(listing?.access != nil && stops.withLock { $0 } == 0)
        var second: DirectoryListing? = try await access.read(fixture.target) { _ in Issue.record("Existing scope was revoked"); return nil }
        #expect(second?.directory == fixture.target)
        listing = nil
        #expect(stops.withLock { $0 } == 0)
        second = nil
        #expect(stops.withLock { $0 } == 1)
    }
}

@MainActor private final class FavouriteAccessFixture {
    let domain = "panepeek-favourite-access-" + UUID().uuidString
    let preferences: UserDefaults
    let favourites: Favourites
    let base: URL
    let target: URL
    let other: URL
    let bookmarking = FolderAccess.Bookmarking(
        create: { url, _ in Data(url.path.utf8) },
        resolve: { .init(url: URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true), stale: false) },
        start: { _ in true })

    init() throws {
        preferences = try #require(UserDefaults(suiteName: domain))
        favourites = Favourites(preferences: preferences)
        base = FileManager.default.temporaryDirectory.appendingPathComponent(domain, isDirectory: true).resolvingSymlinksInPath()
        target = base.appendingPathComponent("project", isDirectory: true)
        other = base.appendingPathComponent("reference", isDirectory: true)
        for directory in [target, other] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        try Data("fixture".utf8).write(to: other.appendingPathComponent("note.txt"))
    }
    func access(bookmarking: FolderAccess.Bookmarking? = nil, stop: @escaping @Sendable (URL) -> Void = { _ in }) -> FolderAccess {
        FolderAccess(preferences: preferences, bookmarking: bookmarking ?? self.bookmarking, stop: stop)
    }
    func pane() -> DirectoryPane { DirectoryPane(directory: other, resolveBeforeLoading: false) }
    func saveFavourite() async throws {
        let access = access()
        let listing = try await access.read(target) { _ in self.target }
        withExtendedLifetime(listing) { access.toggleFavourite(listing.directory, favourites: favourites) }
    }
    func finish() {
        preferences.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: base)
    }
}
