import Foundation
import Testing
@testable import PanePeekCore

@MainActor struct ScopedTransferTests {
    @Test(arguments: [BrowserState.DropOperation.copy, .move])
    func incomingTransfersAcquireCapturedParentsAndKeepTheirDestination(operation: BrowserState.DropOperation) async throws {
        let fixture = try ScopedTransferFixture()
        defer { fixture.remove() }
        var requests: [(String, DirectoryAccess.Mode)] = []
        let browser = fixture.receiver { directory, mode in
            requests.append((directory.path, mode))
            return DirectoryAccess(root: directory, mode: mode) {}
        }
        await browser.left.refresh()
        browser.setMode(.onePane)
        let task = try #require(browser.submitDrop([fixture.source], into: .left, operation: operation))
        #expect(browser.submitDrop([fixture.source], into: .left, operation: operation) == nil)
        await browser.left.navigate(to: fixture.later)
        await task.value
        #expect(requests.contains { $0.0 == fixture.source.deletingLastPathComponent().path && $0.1 == (operation == .copy ? .readOnly : .readWrite) })
        #expect(requests.contains { $0.0 == fixture.destination.path && $0.1 == .readWrite })
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("source.txt")) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.later.path).isEmpty)
        #expect(FileManager.default.fileExists(atPath: fixture.source.path) == (operation == .copy))
    }

    @Test func aSourceReplacedDuringItsParentPermissionDecisionIsRejected() async throws {
        let fixture = try ScopedTransferFixture()
        defer { fixture.remove() }
        let browser = fixture.receiver { directory, mode in
            if directory.path == fixture.source.deletingLastPathComponent().path {
                try Data("replacement".utf8).write(to: fixture.source, options: .atomic)
            }
            return DirectoryAccess(root: directory, mode: mode) {}
        }
        await browser.left.refresh()
        let task = try #require(browser.submitDrop([fixture.source], into: .left, operation: .copy))
        await task.value
        #expect(browser.copyOutcome?.succeeded == false)
        #expect(try Data(contentsOf: fixture.source) == Data("replacement".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func cancellingASourcePermissionUpgradeDoesNotMoveOrClearTheFiles() async throws {
        let fixture = try ScopedTransferFixture()
        defer { fixture.remove() }
        let browser = fixture.receiver { _, _ in nil }
        await browser.left.refresh()
        var completed = false
        let submitted = browser.submitDrop([fixture.source], into: .left, operation: .move, moveCompletion: { result in
            completed = true
            #expect(result == nil)
        })
        let task = try #require(submitted)
        await task.value
        #expect(completed && browser.moveOutcome == nil)
        #expect(try Data(contentsOf: fixture.source) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }
}

private struct ScopedTransferFixture: Sendable {
    let root: URL
    let source: URL
    let destination: URL
    let later: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-scoped-transfer-" + UUID().uuidString).resolvingSymlinksInPath()
        source = root.appendingPathComponent("source/source.txt")
        destination = root.appendingPathComponent("destination", isDirectory: true)
        later = root.appendingPathComponent("later", isDirectory: true)
        for directory in [source.deletingLastPathComponent(), destination, later] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try Data("original".utf8).write(to: source)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    @MainActor func receiver(acquire: @escaping @MainActor (URL, DirectoryAccess.Mode) async throws -> DirectoryAccess?) -> BrowserState {
        BrowserState(homeDirectory: destination, requiresFolderAccess: true, acquireOperationAccess: acquire, load: { directory in
            let listing = try await DirectoryListing.read(directory, followingLinks: false)
            return DirectoryListing(directory: directory, entries: listing.entries, access: DirectoryAccess(root: directory) {})
        })
    }
}
