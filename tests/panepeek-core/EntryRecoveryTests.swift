import Foundation
import Synchronization
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1))) @MainActor
struct EntryRecoveryTests {
    @Test(arguments: [false, true], [false, true])
    func movedEntriesMatchListingAfterRefreshFailure(followingLinks: Bool, listed: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try items(fixture)
        let failRefresh = Mutex(false)
        let load: @Sendable (URL) async throws -> DirectoryListing = { directory in
            if failRefresh.withLock({ $0 }) { throw CocoaError(.fileReadNoPermission) }
            let listing = try await DirectoryListing.read(directory, followingLinks: followingLinks)
            return DirectoryListing(directory: listing.directory, entries: listing.entries,
                                    access: DirectoryAccess(root: directory) {})
        }
        let operations = FileOperationCoordinator()
        let browser = BrowserState(homeDirectory: listed ? fixture.source : fixture.destination,
            requiresFolderAccess: !followingLinks,
            acquireOperationAccess: { directory, mode in DirectoryAccess(root: directory, mode: mode) {} },
            load: load, operations: operations, move: { item in
                let result = await item.move()
                if result.sourceRemoved { failRefresh.withLock { $0 = true } }
                return result
            })
        let receiving = BrowserState(homeDirectory: fixture.destination, requiresFolderAccess: !followingLinks,
            acquireOperationAccess: { directory, mode in DirectoryAccess(root: directory, mode: mode) {} },
            load: load, operations: operations)
        for window in [browser, receiving] {
            operations.register(window)
            await window.left.refresh()
            window.left.showHiddenFiles = true
        }
        if listed {
            await browser.right.navigate(to: fixture.destination)
            browser.right.showHiddenFiles = true
            let displayed = browser.left.entries.map(\.url)
            try #require(displayed.count == sources.count)
            browser.select(Set(displayed), in: .left)
            #expect(await browser.moveToOtherPane(from: .left)?.succeeded == true)
        } else {
            let task = try #require(browser.submitDrop(sources, into: .left, operation: .move))
            await task.value
            #expect(browser.moveOutcome?.succeeded == true)
        }
        let target = listed ? browser.right : browser.left
        let expected = try await DirectoryListing.read(fixture.destination, followingLinks: followingLinks).entries
        #expect(expected.count == sources.count && operations.canMutate)
        for pane in [target, receiving.left] {
            #expect(pane.directory == fixture.destination && pane.errorMessage != nil)
            #expect(Set(pane.entries.map(\.name)) == Set(expected.map(\.name)))
            for item in expected {
                let recovered = try #require(pane.entries.first { $0.name == item.name })
                #expect(recovered.url.deletingLastPathComponent() == item.url.deletingLastPathComponent())
                #expect(recovered.isDirectory == item.isDirectory)
                #expect(recovered.isPackage == item.isPackage)
                #expect(recovered.isSymbolicLink == item.isSymbolicLink)
                #expect(recovered.isHidden == item.isHidden)
                #expect(recovered.modifiedDate == item.modifiedDate)
                #expect(recovered.size == item.size)
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.source.path).isEmpty)
    }

    @Test(arguments: [false, true], ["regular.txt", "folder", "Sample.app", "folder-link", "package-link", "broken-link", ".hidden.txt", "flagged.txt"])
    func renamedHiddenStateMatchesListingAfterRefreshFailure(followingLinks: Bool, name: String) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        _ = try items(fixture)
        let failRefresh = Mutex(false)
        let browser = BrowserState(homeDirectory: fixture.source, requiresFolderAccess: !followingLinks,
            acquireOperationAccess: { directory, mode in DirectoryAccess(root: directory, mode: mode) {} },
            load: { directory in
                if failRefresh.withLock({ $0 }) { throw CocoaError(.fileReadNoPermission) }
                let listing = try await DirectoryListing.read(directory, followingLinks: followingLinks)
                return DirectoryListing(directory: listing.directory, entries: listing.entries,
                                        access: DirectoryAccess(root: directory) {})
            }, rename: { item, name in
                let result = try await item.rename(to: name)
                failRefresh.withLock { $0 = true }
                return result
            })
        await browser.left.refresh()
        browser.left.showHiddenFiles = true
        let source = try #require(browser.left.entries.first { $0.name == name }?.url)
        browser.select([source], in: .left)
        await browser.beginRename()
        let result = await browser.submitRename(named: "renamed-" + name)
        let destination = try #require(result)
        let expected = try #require(try await DirectoryListing.read(fixture.source, followingLinks: followingLinks)
            .entries.first { $0.name == destination.lastPathComponent })
        let recovered = try #require(browser.left.entries.first { $0.name == expected.name })
        #expect(browser.left.directory == fixture.source && browser.left.errorMessage != nil)
        #expect(recovered.isHidden == expected.isHidden)
        #expect(recovered.isSymbolicLink == expected.isSymbolicLink)
        #expect(recovered.isDirectory == expected.isDirectory && recovered.isPackage == expected.isPackage)
        #expect(recovered.size == expected.size && recovered.modifiedDate == expected.modifiedDate)
    }

    @Test(arguments: [false, true])
    func renamedReplacementUsesCurrentHiddenState(followingLinks: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        _ = try items(fixture)
        let failRefresh = Mutex(false)
        let browser = BrowserState(homeDirectory: fixture.source, requiresFolderAccess: !followingLinks,
            acquireOperationAccess: { directory, mode in DirectoryAccess(root: directory, mode: mode) {} },
            load: { directory in
                if failRefresh.withLock({ $0 }) { throw CocoaError(.fileReadNoPermission) }
                let listing = try await DirectoryListing.read(directory, followingLinks: followingLinks)
                return DirectoryListing(directory: listing.directory, entries: listing.entries,
                                        access: DirectoryAccess(root: directory) {})
            }, rename: { item, name in
                let result = try await item.rename(to: name)
                failRefresh.withLock { $0 = true }
                return result
            })
        await browser.left.refresh()
        let listed = try #require(browser.left.entries.first { $0.name == "folder-link" })
        #expect(listed.isSymbolicLink)
        browser.select([listed.url], in: .left)
        try FileManager.default.removeItem(at: listed.url)
        var replacement = listed.url
        let contents = Data("replacement".utf8)
        try contents.write(to: replacement)
        var values = URLResourceValues()
        values.isHidden = true
        try replacement.setResourceValues(values)
        await browser.beginRename()
        let destination = try #require(await browser.submitRename(named: "renamed.txt"))
        #expect(browser.left.directory == fixture.source && browser.left.errorMessage != nil)
        #expect(!browser.left.entries.contains { $0.name == destination.lastPathComponent })
        browser.left.showHiddenFiles = true
        let recovered = try #require(browser.left.entries.first { $0.name == destination.lastPathComponent })
        let expected = try #require(try await DirectoryListing.read(fixture.source, followingLinks: followingLinks)
            .entries.first { $0.name == destination.lastPathComponent })
        #expect(expected.isHidden && recovered.isHidden == expected.isHidden)
        #expect(try Data(contentsOf: destination) == contents)
    }

    private func items(_ fixture: MoveFixture) throws -> [URL] {
        let files = FileManager.default
        let regular = try fixture.file("regular.txt")
        let empty = try fixture.file("empty.txt")
        try Data().write(to: empty)
        let folder = try fixture.file("folder/child.txt").deletingLastPathComponent()
        _ = try fixture.file("Sample.app/Contents/child.txt")
        let package = fixture.source.appendingPathComponent("Sample.app")
        let hidden = try fixture.file(".hidden.txt")
        var flagged = try fixture.file("flagged.txt")
        var values = URLResourceValues()
        values.isHidden = true
        try flagged.setResourceValues(values)
        let targets = fixture.root.appendingPathComponent("targets")
        try files.createDirectory(at: targets.appendingPathComponent("folder"), withIntermediateDirectories: true)
        try files.createDirectory(at: targets.appendingPathComponent("Target.app"), withIntermediateDirectories: false)
        try Data("target".utf8).write(to: targets.appendingPathComponent("file.txt"))
        var links: [URL] = []
        for (name, target) in [("folder-link", "folder"), ("package-link", "Target.app"),
                               ("file-link", "file.txt"), ("broken-link", "missing")] {
            let link = fixture.source.appendingPathComponent(name)
            try files.createSymbolicLink(at: link, withDestinationURL: targets.appendingPathComponent(target))
            links.append(link)
        }
        return [regular, empty, folder, package, hidden, flagged] + links
    }
}
