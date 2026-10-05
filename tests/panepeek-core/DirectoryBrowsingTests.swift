import Foundation
import Testing
@testable import PanePeekCore

struct DirectoryBrowsingTests {
    @Test @MainActor func breadcrumbsKeepRootAndLiteralAncestorPaths() {
        let root = DirectoryPane(directory: URL(fileURLWithPath: "/", isDirectory: true))
        #expect(root.breadcrumbDirectories.map(\.path) == ["/"])

        let pane = DirectoryPane(directory: URL(fileURLWithPath: "/workspace/project space/notes ü#%", isDirectory: true))
        #expect(pane.breadcrumbDirectories.map(\.path) == [
            "/", "/workspace", "/workspace/project space", "/workspace/project space/notes ü#%"
        ])
    }

    @Test func realListingDistinguishesDirectoriesAndUsesNaturalOrder() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        try fixture.folder("folder10")
        try fixture.folder("folder2")
        try fixture.file("file10.txt")
        try fixture.file("file2.txt")

        let entries = try await DirectoryListing.read(fixture.root).entries
        #expect(entries.map(\.name) == ["folder2", "folder10", "file2.txt", "file10.txt"])
        #expect(entries.map(\.isDirectory) == [true, true, false, false])
        #expect(try await DirectoryListing.read(fixture.folder("empty")).entries.isEmpty)
    }

    @Test @MainActor func invalidNavigationRetainsTheSuccessfulDirectoryAndListing() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let valid = try fixture.folder("valid")
        try fixture.file("valid/kept.txt")
        let regularFile = try fixture.file("regular.txt")
        let deleted = try fixture.folder("deleted")
        try FileManager.default.removeItem(at: deleted)
        let pane = DirectoryPane(directory: fixture.root)
        await pane.navigate(to: valid)
        let entries = pane.entries

        for path in [fixture.root.appendingPathComponent("missing").path, regularFile.path, deleted.path, "relative", ""] {
            await pane.navigate(toPath: path)
            #expect(pane.directory == valid)
            #expect(pane.entries == entries)
            #expect(pane.errorMessage != nil)
            #expect(!pane.isLoading)
        }
        #expect(entries.map(\.name) == ["kept.txt"])
        await pane.navigate(to: fixture.root)
        #expect(pane.errorMessage == nil)
        #expect(pane.directory == fixture.root)
    }

    @Test @MainActor func sharedActionsTargetFocusAndLeaveTheOtherPaneAlone() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let first = try fixture.folder("first")
        let second = try fixture.folder("second")
        try fixture.file("first/one.txt")
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.navigate(to: first)
        let leftEntries = browser.left.entries
        browser.focus(.right)
        await browser.pane(browser.focusedPane).navigate(toPath: second.path)

        #expect(browser.focusedPane == .right)
        #expect(browser.right.directory == second)
        #expect(browser.left.directory == first)
        #expect(browser.left.entries == leftEntries)
    }

    @Test @MainActor func directoryLinksFollowFinderLocationAndPackagesAreNotBrowsable() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let target = try fixture.folder("storage/destination")
        try fixture.file("storage/destination/inside.txt")
        let aliases = try fixture.folder("aliases")
        let link = aliases.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try fixture.folder("Sample.app")

        let entries = try await DirectoryListing.read(fixture.root).entries
        #expect(entries.first { $0.name == "Sample.app" }?.isDirectory == false)
        let aliasesEntries = try await DirectoryListing.read(aliases).entries
        #expect(aliasesEntries.first?.url.path == link.path)
        #expect(aliasesEntries.first?.isDirectory == true)

        let pane = DirectoryPane(directory: fixture.root)
        await pane.navigate(toPath: link.path)
        #expect(pane.directory.path == target.path)
        #expect(pane.entries.first?.url.path == target.appendingPathComponent("inside.txt").path)
        #expect(pane.breadcrumbDirectories.suffix(2).map(\.lastPathComponent) == ["storage", "destination"])
        await pane.navigate(to: pane.directory.deletingLastPathComponent())
        #expect(pane.directory.path == target.deletingLastPathComponent().path)
        await pane.navigate(to: link)
        #expect(pane.directory.path == target.path)

        let retainedEntries = pane.entries
        let broken = aliases.appendingPathComponent("broken")
        try FileManager.default.createSymbolicLink(at: broken, withDestinationURL: fixture.root.appendingPathComponent("missing"))
        await pane.navigate(to: broken)
        #expect(pane.directory.path == target.path)
        #expect(pane.entries == retainedEntries)
        #expect(pane.errorMessage != nil)
    }

    @Test(arguments: [false, true]) @MainActor
    func olderSuccessOrErrorCannotReplaceNewerNavigation(olderFails: Bool) async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let older = try fixture.folder("older")
        let newer = try fixture.folder("newer")
        try fixture.file("newer/current.txt")
        let gate = ListingGate()
        let pane = DirectoryPane(directory: fixture.root, load: { try await gate.read($0) })

        let oldRequest = Task { await pane.navigate(to: older) }
        await gate.waitForRequest(older)
        #expect(pane.isLoading)
        #expect(pane.directory == fixture.root)
        let newRequest = Task { await pane.navigate(to: newer) }
        await gate.waitForRequest(newer)
        await gate.finish(newer, entries: try await DirectoryListing.read(newer).entries)
        await newRequest.value
        if olderFails {
            await gate.fail(older)
        } else {
            await gate.finish(older, entries: [])
        }
        await oldRequest.value

        #expect(pane.directory == newer)
        #expect(pane.entries.map(\.name) == ["current.txt"])
        #expect(pane.errorMessage == nil)
        #expect(!pane.isLoading)
    }

    @Test @MainActor func pendingSharedNavigationKeepsItsTargetWhileFocusChanges() async throws {
        let fixture = try DirectoryFixture()
        defer { fixture.remove() }
        let destination = try fixture.folder("destination")
        let gate = ListingGate()
        let browser = BrowserState(homeDirectory: fixture.root, load: { try await gate.read($0) })
        browser.focus(.right)
        let target = browser.pane(browser.focusedPane)
        let request = Task { await target.navigate(toPath: destination.path) }
        await gate.waitForRequest(destination)
        browser.focus(.left)
        #expect(browser.focusedPane == .left)
        await gate.finish(destination, entries: [])
        await request.value

        #expect(browser.left.directory == fixture.root)
        #expect(browser.right.directory == destination)
    }
}

private struct DirectoryFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-tests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @discardableResult func folder(_ path: String) throws -> URL {
        let url = root.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult func file(_ path: String) throws -> URL {
        let url = root.appendingPathComponent(path)
        try Data("fixture".utf8).write(to: url)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private actor ListingGate {
    private var requests: [URL: CheckedContinuation<DirectoryListing, any Error>] = [:]
    private var observers: [URL: CheckedContinuation<Void, Never>] = [:]

    func read(_ directory: URL) async throws -> DirectoryListing {
        try await withCheckedThrowingContinuation { continuation in
            requests[directory] = continuation
            observers.removeValue(forKey: directory)?.resume()
        }
    }

    func waitForRequest(_ directory: URL) async {
        if requests[directory] != nil { return }
        await withCheckedContinuation { observers[directory] = $0 }
    }

    func finish(_ directory: URL, entries: [DirectoryEntry]) {
        requests.removeValue(forKey: directory)?.resume(returning: DirectoryListing(directory: directory, entries: entries))
    }

    func fail(_ directory: URL) {
        requests.removeValue(forKey: directory)?.resume(throwing: CocoaError(.fileReadNoPermission))
    }
}
