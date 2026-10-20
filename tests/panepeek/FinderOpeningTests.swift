import Foundation
import Testing
import Synchronization
import PanePeekCore
@testable import PanePeek

@MainActor
struct FinderOpeningTests {
    @Test func mixedSelectionOpensDirectoriesAndRevealsFilesPackagesAndLinks() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Folder", isDirectory: true)
        let package = root.appendingPathComponent("Example.app", isDirectory: true)
        let file = root.appendingPathComponent("café 👀\nnotes.txt")
        let link = root.appendingPathComponent("file link")
        let broken = root.appendingPathComponent("broken link")
        let folderLink = root.appendingPathComponent("folder link")
        for url in [folder, package] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        try Data("text".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        try FileManager.default.createSymbolicLink(at: broken, withDestinationURL: root.appendingPathComponent("missing"))
        try FileManager.default.createSymbolicLink(at: folderLink, withDestinationURL: folder)
        let listing = try await DirectoryListing.read(root)
        let urls = [file, folder, package, link, broken, folderLink]
        let items = try urls.map { url in try #require(listing.entries.first { $0.url.path == url.path }) }
        var opened: [[URL]] = []
        var revealed: [[URL]] = []
        let finder = FinderOpening(openDirectories: { opened.append($0) }, revealFiles: { revealed.append($0) })

        try await finder.open(items.map(\.url))

        #expect(opened.map { $0.map(\.path) } == [[folder.path, folderLink.path]])
        #expect(revealed.map { $0.map(\.path) } == [[file.path, package.path, link.path, broken.path]])
        #expect(try String(contentsOf: file, encoding: .utf8) == "text")
    }

    @Test func currentItemTypeOverridesAStaleListingWithoutOpeningAFile() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("was a folder")
        let folder = root.appendingPathComponent("was a file", isDirectory: true)
        try Data().write(to: file)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        var opened: [URL] = []
        var revealed: [URL] = []
        let finder = FinderOpening(openDirectories: { opened = $0 }, revealFiles: { revealed = $0 })

        try await finder.open([
            DirectoryEntry(url: file, isDirectory: true),
            DirectoryEntry(url: folder, isDirectory: false)
        ].map(\.url))

        #expect(opened == [folder])
        #expect(revealed == [file])
    }

    @Test func missingItemRejectsTheSelectionBeforeAnyFinderRequest() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appendingPathComponent("missing.txt")
        var requests = 0
        let finder = FinderOpening(openDirectories: { _ in requests += 1 }, revealFiles: { _ in requests += 1 })

        await #expect(throws: CocoaError.self) {
            try await finder.open([
                DirectoryEntry(url: root, isDirectory: true),
                DirectoryEntry(url: missing, isDirectory: false)
            ].map(\.url))
        }
        #expect(requests == 0)
    }

    @Test func finderFailureIsReportedWithoutRevealingOtherItems() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("notes.txt")
        try Data("original".utf8).write(to: file)
        var revealed = false
        let finder = FinderOpening(openDirectories: { _ in throw CocoaError(.fileReadNoPermission) },
                                   revealFiles: { _ in revealed = true })

        await #expect(throws: CocoaError(.fileReadNoPermission)) {
            try await finder.open([
                DirectoryEntry(url: root, isDirectory: true),
                DirectoryEntry(url: file, isDirectory: false)
            ].map(\.url))
        }
        #expect(!revealed)
        #expect(try String(contentsOf: file, encoding: .utf8) == "original")
    }

    @Test func scopedFinderHandoffRevealsTheListedLinkWithoutFollowingItsDirectoryTarget() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Folder", isDirectory: true)
        let link = root.appendingPathComponent("Folder link")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        var opened: [URL] = []
        var revealed: [URL] = []
        let finder = FinderOpening(openDirectories: { opened = $0 }, revealFiles: { revealed = $0 })
        try await finder.open([link], followingLinks: false)
        #expect(opened.isEmpty)
        #expect(revealed == [link])
    }

    @Test func finderHandoffOwnsAccessUntilNativeOpeningFinishes() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let released = Mutex(0)
        var access: DirectoryAccess? = DirectoryAccess(root: root) { released.withLock { $0 += 1 } }
        var started = false
        var finish: CheckedContinuation<Void, Never>?
        let finder = FinderOpening(openDirectories: { _ in
            started = true
            await withCheckedContinuation { finish = $0 }
            #expect(released.withLock { $0 } == 0)
        })
        let task = Task { @MainActor [access] in try await finder.open([root], access: access) }
        access = nil
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !started && ContinuousClock.now < deadline { await Task.yield() }
        try #require(started)
        #expect(released.withLock { $0 } == 0)
        finish?.resume()
        try await task.value
        #expect(released.withLock { $0 } == 1)
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-finder-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
