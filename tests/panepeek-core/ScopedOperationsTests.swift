import Foundation
import Synchronization
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1)))
@MainActor struct ScopedOperationsTests {
    @Test(arguments: ["copy", "move", "rename", "create", "trash"])
    func scopedOperationsUseTheRequiredFolderCapabilities(action: String) async throws {
        let fixture = try ScopedOperationFixture()
        defer { fixture.remove() }
        var requests: [(URL, DirectoryAccess.Mode)] = []
        let browser = fixture.browser(acquire: { directory, mode in
            requests.append((directory, mode))
            return DirectoryAccess(root: directory, mode: mode) {}
        })
        await fixture.load(browser)
        let result: URL
        switch action {
        case "copy":
            try #require(browser.canCopy(in: .left))
            #expect(await browser.copyToOtherPane(from: .left)?.succeeded == true)
            result = fixture.destination.appendingPathComponent("notes.txt")
            #expect(requests.contains { $0.path == fixture.source.path && $1 == .readOnly })
            #expect(requests.contains { $0.path == fixture.destination.path && $1 == .readWrite })
        case "move":
            try #require(browser.canMove(in: .left))
            #expect(await browser.moveToOtherPane(from: .left)?.succeeded == true)
            result = fixture.destination.appendingPathComponent("notes.txt")
            #expect(!FileManager.default.fileExists(atPath: fixture.item.path))
        case "rename":
            try #require(browser.canRename())
            await browser.beginRename()
            result = fixture.source.appendingPathComponent("renamed.txt")
            #expect(await browser.submitRename(named: "renamed.txt") == result)
        case "create":
            try #require(browser.canCreate())
            browser.beginCreation(.folder)
            try await waitForState { browser.creationRequest != nil || browser.creationError != nil }
            try #require(browser.creationRequest != nil)
            await browser.submitCreation(named: "New folder")
            result = fixture.source.appendingPathComponent("New folder")
        default:
            try #require(browser.canTrash())
            #expect(await browser.moveToTrash()?.succeeded == true)
            result = fixture.root.appendingPathComponent("recycled.txt")
            #expect(!FileManager.default.fileExists(atPath: fixture.item.path))
        }
        #expect(FileManager.default.fileExists(atPath: result.path))
        if action != "copy" {
            #expect(requests.contains { $0.path == fixture.source.path && $1 == .readWrite })
        }
        browser.setMode(.onePane)
        #expect(!browser.canCopy(in: .left) && !browser.canMove(in: .left))
    }

    @Test(arguments: [false, true])
    func copyRetainsBothListingAndOperationScopesThroughWindowClosureAndRefresh(slowController: Bool) async throws {
        let fixture = try ScopedOperationFixture()
        defer { fixture.remove() }
        let releasedListings = Mutex(0)
        let releasedOperations = Mutex(0)
        try await withOperationGate { gate in
            let browser = fixture.browser(listingReleased: { releasedListings.withLock { $0 += 1 } }, acquire: { directory, mode in
                DirectoryAccess(root: directory, mode: mode) { releasedOperations.withLock { $0 += 1 } }
            }, copy: { item in
                do { try await gate.pause() } catch { return ItemCopy.Outcome(succeeded: false, message: error.localizedDescription) }
                #expect(releasedListings.withLock { $0 } == 0 && releasedOperations.withLock { $0 } == 0)
                return await item.copy()
            })
            await fixture.load(browser)
            try #require(browser.canCopy(in: .left))
            let operation = Task { await browser.copyToOtherPane(from: .left) }
            gate.track(operation)
            try await gate.waitForRequest()
            if slowController { try await Task.sleep(for: .seconds(11)) }
            browser.operations.unregister(browser)
            browser.left.releaseAccess()
            browser.right.releaseAccess()
            #expect(releasedListings.withLock { $0 } == 0 && releasedOperations.withLock { $0 } == 0)
            try await gate.finish()
            #expect(await operation.value?.succeeded == true)
            #expect(releasedListings.withLock { $0 } == 2 && releasedOperations.withLock { $0 } == 2)
            #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("notes.txt")) == Data("original".utf8))
        }
    }

    @Test func operationScopeFailureJoinsTheWorkerBeforeFixtureCleanup() async throws {
        let fixture = try ScopedOperationFixture()
        defer { fixture.remove() }
        let result = Mutex<[Bool]>([])
        let expected = OperationGate.Failure(message: "Operation controller stopped")
        await #expect(throws: expected) {
            try await withOperationGate { gate in
                let browser = fixture.browser(acquire: { directory, mode in
                    DirectoryAccess(root: directory, mode: mode) {}
                }, copy: { item in
                    do { try await gate.pause() }
                    catch { return ItemCopy.Outcome(succeeded: false, message: error.localizedDescription) }
                    return await item.copy()
                })
                await fixture.load(browser)
                let operation = Task {
                    let outcome = await browser.copyToOtherPane(from: .left)
                    result.withLock { $0 = [outcome?.succeeded == false, !browser.isCopying] }
                }
                gate.track(operation)
                try await gate.waitForRequest()
                throw expected
            }
        }
        #expect(result.withLock { $0 } == [true, true])
        #expect(try Data(contentsOf: fixture.item) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test(arguments: ["create", "rename"])
    func namingRequestsAndWorkersRetainTheirWriteGrantAfterWindowClosure(action: String) async throws {
        let fixture = try ScopedOperationFixture()
        defer { fixture.remove() }
        let released = Mutex(0)
        try await withOperationGate { gate in
            let browser = fixture.browser(acquire: { directory, mode in
                DirectoryAccess(root: directory, mode: mode) { released.withLock { $0 += 1 } }
            }, create: { kind, name, directory in
                try await gate.pause()
                #expect(released.withLock { $0 } == 0)
                return try await ItemCreation.create(kind, named: name, in: directory)
            }, rename: { item, name in
                try await gate.pause()
                #expect(released.withLock { $0 } == 0)
                return try await item.rename(to: name)
            })
            await fixture.load(browser)
            let task: Task<Void, Never>
            if action == "create" {
                browser.beginCreation(.textFile)
                try await waitForState { browser.creationRequest != nil }
                try #require(browser.creationRequest != nil)
                #expect(released.withLock { $0 } == 0)
                task = Task { await browser.submitCreation(named: "result.txt") }
            } else {
                await browser.beginRename()
                try #require(browser.renameRequest != nil)
                #expect(released.withLock { $0 } == 0)
                task = Task { _ = await browser.submitRename(named: "result.txt") }
            }
            gate.track(task)
            try await gate.waitForRequest()
            browser.operations.unregister(browser)
            browser.left.releaseAccess()
            browser.right.releaseAccess()
            #expect(released.withLock { $0 } == 0)
            try await gate.finish()
            await task.value
            #expect(released.withLock { $0 } == 1)
            #expect(FileManager.default.fileExists(atPath: fixture.source.appendingPathComponent("result.txt").path))
        }
    }

    @Test(arguments: ["cancel", "read-only", "unrelated"])
    func refusedWriteAccessLeavesTheCapturedFilesUntouched(response: String) async throws {
        let fixture = try ScopedOperationFixture()
        defer { fixture.remove() }
        let browser = fixture.browser(acquire: { directory, mode in
            if mode == .readOnly { return DirectoryAccess(root: directory) {} }
            if response == "cancel" { return nil }
            return DirectoryAccess(root: response == "unrelated" ? fixture.root.appendingPathComponent("unrelated") : directory,
                                   mode: response == "read-only" ? .readOnly : .readWrite) {}
        })
        await fixture.load(browser)
        try #require(browser.canCopy(in: .left))
        let result = await browser.copyToOtherPane(from: .left)
        #expect(result?.succeeded != true)
        if response == "cancel" { #expect(result == nil && browser.copyOutcome == nil) }
        #expect(try Data(contentsOf: fixture.item) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test(arguments: ["create", "rename"], [false, true])
    func delayedPermissionCannotReopenARequestForAnObsoletePane(action: String, failing: Bool) async throws {
        let fixture = try ScopedOperationFixture()
        defer { fixture.remove() }
        try await withOperationGate { gate in
            let released = Mutex(0)
            let browser = fixture.browser(acquire: { directory, mode in
                try await gate.pause()
                if failing { throw CocoaError(.fileWriteNoPermission) }
                return DirectoryAccess(root: directory, mode: mode) { released.withLock { $0 += 1 } }
            })
            await fixture.load(browser)
            let preparing: Task<Void, Never>?
            if action == "create" {
                browser.beginCreation(.textFile)
                preparing = nil
            } else { preparing = Task { await browser.beginRename() } }
            gate.track(preparing)
            try await gate.waitForRequest()
            await browser.left.navigate(to: fixture.destination)
            browser.cancelCreation()
            try await gate.finish()
            await preparing?.value
            try await waitForState { !browser.isCreating }
            #expect(browser.creationRequest == nil && browser.renameRequest == nil)
            #expect(browser.creationError == nil && browser.renameError == nil)
            #expect(released.withLock { $0 } == (failing ? 0 : 1))
            #expect(try Data(contentsOf: fixture.item) == Data("original".utf8))
        }
    }

    @Test func sourceReplacementDuringPermissionSelectionCannotBeCopied() async throws {
        let fixture = try ScopedOperationFixture()
        defer { fixture.remove() }
        let browser = fixture.browser(acquire: { directory, mode in
            if mode == .readWrite { try Data("replacement".utf8).write(to: fixture.item, options: .atomic) }
            return DirectoryAccess(root: directory, mode: mode) {}
        })
        await fixture.load(browser)
        try #require(browser.canCopy(in: .left))
        #expect(await browser.copyToOtherPane(from: .left)?.succeeded == false)
        #expect(try Data(contentsOf: fixture.item) == Data("replacement".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }
}

private struct ScopedOperationFixture: Sendable {
    let root: URL
    let source: URL
    let destination: URL
    let item: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-scoped-operations-" + UUID().uuidString).resolvingSymlinksInPath()
        source = root.appendingPathComponent("source")
        destination = root.appendingPathComponent("destination")
        item = source.appendingPathComponent("notes.txt")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("original".utf8).write(to: item)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    @MainActor func browser(listingReleased: @escaping @Sendable () -> Void = {},
                            acquire: @escaping @MainActor (URL, DirectoryAccess.Mode) async throws -> DirectoryAccess?,
                            copy: (@Sendable (ItemCopy) async -> ItemCopy.Outcome)? = nil,
                            create: (@Sendable (ItemCreation.Kind, String, URL) async throws -> URL)? = nil,
                            rename: (@Sendable (ItemRename, String) async throws -> URL)? = nil) -> BrowserState {
        BrowserState(homeDirectory: source, requiresFolderAccess: true, acquireOperationAccess: acquire, load: { directory in
            let listing = try await DirectoryListing.read(directory, followingLinks: false)
            return DirectoryListing(directory: directory, entries: listing.entries,
                                    access: DirectoryAccess(root: directory, release: listingReleased))
        }, create: create, rename: rename, copy: copy, trash: { item in
            await item.trash { try FileManager.default.moveItem(at: $0, to: root.appendingPathComponent("recycled.txt")) }
        })
    }
    @MainActor func load(_ browser: BrowserState) async {
        await browser.left.refresh()
        await browser.right.navigate(to: destination)
        browser.select([item], in: .left)
    }
}
