import Foundation
import Testing
import Synchronization
@testable import PanePeekCore

@Suite @MainActor struct TrashAccessRecoveryTests {
    @Test func permissionFailureAfterPartialSuccessRetriesOnlyPendingItems() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let attempts = TrashAttempts(denied: sources[1], destination: fixture.destination)
        var requested: [URL] = []
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await attempts.trash($0) },
            recoverTrashAccess: { directory in
                requested.append(directory)
                return ItemTrash.FolderAccess(directory: directory)
            })
        await browser.left.refresh()
        browser.select(Set(sources), in: .left)
        let outcome = await browser.moveToTrash()
        #expect(outcome?.succeeded == true && outcome?.completed == sources)
        #expect(requested == [fixture.source])
        #expect(await attempts.sources == [sources[0], sources[1], sources[1], sources[2]])
    }

    @Test(arguments: [false, true])
    func cancellationOrWrongFolderPreservesPendingItems(wrongFolder: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let attempts = TrashAttempts(denied: sources[1], destination: fixture.destination)
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await attempts.trash($0) }, recoverTrashAccess: { _ in
            prompts += 1
            return wrongFolder ? ItemTrash.FolderAccess(directory: fixture.destination) : nil
        })
        await browser.left.refresh()
        browser.select(Set(sources), in: .left)
        let outcome = await browser.moveToTrash()
        #expect(outcome?.completed == [sources[0]] && outcome?.failed == sources[1] && outcome?.unattempted == [sources[2]])
        #expect(prompts == 1 && !browser.isTrashing && browser.operations.canMutate)
        #expect(await attempts.sources == Array(sources.prefix(2)))
        #expect(try Data(contentsOf: sources[1]) == Data("original".utf8))
        #expect(try Data(contentsOf: sources[2]) == Data("original".utf8))
    }

    @Test func aReplacedPendingItemRejectsTheWholeRetry() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let attempts = TrashAttempts(denied: sources[1], destination: fixture.destination)
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await attempts.trash($0) }, recoverTrashAccess: { directory in
            do {
                try FileManager.default.moveItem(at: sources[2], to: fixture.root.appendingPathComponent("original-c"))
                try Data("replacement".utf8).write(to: sources[2])
            } catch { Issue.record(error) }
            return ItemTrash.FolderAccess(directory: directory)
        })
        await browser.left.refresh()
        browser.select(Set(sources), in: .left)
        let outcome = await browser.moveToTrash()
        #expect(outcome?.completed == [sources[0]] && outcome?.failed == sources[2] && outcome?.unattempted == [sources[1]])
        #expect(await attempts.sources == Array(sources.prefix(2)))
        #expect(try Data(contentsOf: sources[1]) == Data("original".utf8))
        #expect(try Data(contentsOf: sources[2]) == Data("replacement".utf8))
    }

    @Test func repeatedDenialPromptsOnceAndKeepsThePartialOutcome() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let batch = try await ItemTrash.Batch.capture(sources)
        var prompts = 0
        let outcome = await batch.trash(using: { item in
            await item.trash { url in
                if url == sources[1] { throw CocoaError(.fileWriteNoPermission) }
                try FileManager.default.moveItem(at: url, to: fixture.destination.appendingPathComponent(url.lastPathComponent))
            }
        }, recoverAccess: { directory in
            prompts += 1
            return ItemTrash.FolderAccess(directory: directory)
        })
        #expect(prompts == 1 && outcome.completed == [sources[0]])
        #expect(outcome.failed == sources[1] && outcome.unattempted == [sources[2]])
        #expect(outcome.message.components(separatedBy: "Trash stopped.").count == 2)
    }

    @Test(arguments: [false, true])
    func otherFailuresOrAlreadyRemovedSourcesDoNotRequestAccess(removed: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        let batch = try await ItemTrash.Batch.capture([source])
        var prompts = 0
        let outcome = await batch.trash(using: { item in
            await item.trash { url in
                if removed { try FileManager.default.moveItem(at: url, to: fixture.destination.appendingPathComponent(url.lastPathComponent)) }
                if removed { throw CocoaError(.fileWriteNoPermission) }
                throw POSIXError(.ENOTSUP)
            }
        }, recoverAccess: { directory in
            prompts += 1
            return ItemTrash.FolderAccess(directory: directory)
        })
        #expect(prompts == 0 && !outcome.succeeded)
        #expect(outcome.removed.count == (removed ? 1 : 0))
    }

    @Test func cancellationWhileChoosingPreventsAnyRetry() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        let batch = try await ItemTrash.Batch.capture([source])
        let attempts = TrashAttempts(denied: source, destination: fixture.destination)
        let gate = OperationGate()
        let task = Task {
            await batch.trash(using: { await attempts.trash($0) }, recoverAccess: { directory in
                try? await gate.pause()
                return ItemTrash.FolderAccess(directory: directory)
            })
        }
        try await gate.waitForRequest()
        task.cancel()
        try await gate.finish()
        let outcome = await task.value
        #expect(!outcome.succeeded && outcome.removed.isEmpty)
        #expect(await attempts.sources == [source])
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test func accessRemainsLiveUntilRetryCompletesAndThenReleases() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        let batch = try await ItemTrash.Batch.capture([source])
        let attempts = TrashAttempts(denied: source, destination: fixture.destination)
        let lifetime = AccessLifetime()
        let outcome = await batch.trash(using: { item in
            let result = await attempts.trash(item)
            #expect(!lifetime.ended)
            return result
        }, recoverAccess: { directory in
            ItemTrash.FolderAccess(directory: directory) { lifetime.finish() }
        })
        #expect(outcome.succeeded && lifetime.ended)
    }

    @Test(arguments: [POSIXError.Code.EACCES, .EPERM])
    func posixPermissionDenialsAlsoPermitFolderRecovery(code: POSIXError.Code) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        let item = try await ItemTrash.capture(source)
        let outcome = await item.trash { _ in throw POSIXError(code) }
        #expect(outcome.needsFolderAccess && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }
}

private actor TrashAttempts {
    let denied: URL
    let destination: URL
    private(set) var sources: [URL] = []
    init(denied: URL, destination: URL) { self.denied = denied; self.destination = destination }
    func trash(_ item: ItemTrash) async -> ItemTrash.Outcome {
        sources.append(item.source)
        if item.source == denied && sources.filter({ $0 == denied }).count == 1 {
            return await item.trash { _ in throw CocoaError(.fileWriteNoPermission) }
        }
        return await item.trash { try FileManager.default.moveItem(at: $0, to: self.destination.appendingPathComponent($0.lastPathComponent)) }
    }
}

private final class AccessLifetime: Sendable {
    private let released = Mutex(false)
    var ended: Bool { released.withLock { $0 } }
    func finish() { released.withLock { $0 = true } }
}
