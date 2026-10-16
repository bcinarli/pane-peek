import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite struct BatchMoveTests {
    @Test func movesMixedSelectionInCapturedOrderWithoutTraversingLinks() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("a.txt")
        let child = try fixture.file("folder/child.txt")
        let packageChild = try fixture.file("sample.app/payload.txt")
        let link = fixture.source.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "missing")
        let sources = [file, child.deletingLastPathComponent(), packageChild.deletingLastPathComponent(), link]
        let batch = try await ItemMove.Batch.capture(sources, to: fixture.destination)
        let result = await batch.move()
        #expect(result.succeeded && result.failed == nil && result.unattempted.isEmpty)
        #expect(result.completed == batch.items.map(\.destination))
        #expect(result.relocated.map(\.source) == sources)
        for source in sources { #expect((try? fixture.identity(source)) == nil) }
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("folder/child.txt"))) == Data("original".utf8))
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("sample.app/payload.txt"))) == Data("original".utf8))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: fixture.destination.appendingPathComponent("link").path)) == "missing")
    }

    @Test func aConflictOnTheLastItemRejectsBeforeAnyMove() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let last = try fixture.file("z.txt")
        let batch = try await ItemMove.Batch.capture([first, last], to: fixture.destination)
        try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent("z.txt"))
        let result = await batch.move()
        #expect(!result.succeeded && result.completed.isEmpty && result.relocated.isEmpty)
        #expect(result.failed == last && result.unattempted == [first])
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(try Data(contentsOf: last) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a.txt").path))
    }

    @Test(arguments: [false, true])
    func knownOccupiedAndDuplicateNamesRejectWholeCapture(occupied: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("other/a.txt")
        let destination = fixture.destination.appendingPathComponent("a.txt")
        if occupied { try Data("occupied".utf8).write(to: destination) }
        let sources = occupied ? [second, first] : [first, second]
        do {
            _ = try await ItemMove.Batch.capture(sources, to: fixture.destination)
            Issue.record("Expected the conflicting item to reject the move batch")
        } catch let error as ItemMove.PreflightError {
            #expect(error.source == second)
            #expect(error.destination == destination)
            #expect(error.reason == ItemName.ValidationError.collision.localizedDescription)
        }
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(try Data(contentsOf: second) == Data("original".utf8))
        if occupied { #expect(try Data(contentsOf: destination) == Data("occupied".utf8)) }
        else { #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty) }
    }

    @Test func executionFailureStopsAndRetainsEarlierMoves() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let batch = try await ItemMove.Batch.capture(sources, to: fixture.destination)
        let result = await batch.move { operation in
            if operation.source == sources[1] { return await operation.move(using: { _, _ in throw POSIXError(.EACCES) }) }
            return await operation.move()
        }
        #expect(!result.succeeded && result.completed == [batch.items[0].destination])
        #expect(result.failed == sources[1] && result.unattempted == [sources[2]])
        #expect(result.relocated.map(\.source) == [sources[0]])
        #expect(!FileManager.default.fileExists(atPath: sources[0].path))
        #expect(try Data(contentsOf: sources[1]) == Data("original".utf8))
        #expect(try Data(contentsOf: sources[2]) == Data("original".utf8))
        #expect(result.message.contains("Completed") && result.message.contains("Unattempted"))
    }

    @Test func cleanupFailureStillIncludesTheItemThatWasActuallyMoved() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let batch = try await ItemMove.Batch.capture(sources, to: fixture.destination)
        let result = await batch.move { operation in
            if operation.source == sources[1] {
                return await operation.move(using: fixture.rename(crossVolume: true), remove: { url in
                    if url != sources[1] { throw POSIXError(.EACCES) }
                    try FileManager.default.removeItem(at: url)
                })
            }
            return await operation.move()
        }
        #expect(!result.succeeded && result.completed == batch.items.prefix(2).map(\.destination))
        #expect(result.failed == sources[1] && result.unattempted == [sources[2]])
        #expect(result.relocated.map(\.source) == Array(sources.prefix(2)))
        #expect(!FileManager.default.fileExists(atPath: sources[1].path))
        #expect((try? Data(contentsOf: batch.items[1].destination)) == Data("original".utf8))
        #expect(result.message.contains("cleanup"))
    }
}

@Suite @MainActor struct BrowserBatchMoveTests {
    @Test func mixedSelectionMovesAndRefreshesBothPanes() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("b.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        try await fixture.prepare(browser, selecting: first)
        browser.select([first, second], in: .left, focusedItem: second)
        #expect(browser.canMove(in: .left))
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == true)
        #expect(browser.notifications.notices.first?.kind == .success)
        #expect(browser.notifications.notices.first?.message == "2 items moved.")
        #expect(browser.left.entries.isEmpty && browser.left.selectedItems.isEmpty)
        #expect(browser.right.entries.map(\.name) == ["a.txt", "b.txt"])
        #expect(browser.preview.selection == nil)
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func aLaterDirtyItemIsResolvedBeforeTheFirstMove(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source,
                                   confirmChanges: { _, answer in prompts += 1; answer(choice) })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([first, dirty], in: .left, focusedItem: dirty)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(prompts == 1)
        if choice == .cancel {
            #expect(result == nil && browser.preview.isDirty)
            #expect(try Data(contentsOf: first) == Data("original".utf8))
            #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
        } else {
            #expect(result?.succeeded == true && browser.preview.selection == nil)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("z.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test func failedSaveAbortsTheWholeBatch() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        let preview = PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) })
        let browser = BrowserState(homeDirectory: fixture.source, preview: preview,
                                   confirmChanges: { _, answer in answer(.save) })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([first, dirty], in: .left, focusedItem: dirty)
        #expect(await browser.moveToOtherPane(from: .left) == nil)
        #expect(preview.errorMessage != nil && preview.isDirty)
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func cancelledDirtyPromptRetainsEverySourceAndDraft() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        var dirtyPrompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in
            dirtyPrompts += 1
            answer(.cancel)
        })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([dirty, first], in: .left, focusedItem: dirty)
        #expect(await browser.moveToOtherPane(from: .left) == nil)
        #expect(dirtyPrompts == 1)
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(try Data(contentsOf: dirty) == Data("original".utf8))
        #expect(browser.preview.isDirty && browser.preview.text == "draft" && browser.preview.canEdit)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func cancellingKnownCollisionDoesNotResolveTheDirtyFile() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent("z.txt"))
        var prompts = 0
        var collisions = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveMoveCollision: { _, answer in collisions += 1; answer(.cancel) }, confirmChanges: { _, answer in prompts += 1; answer(.save) })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([first, dirty], in: .left, focusedItem: dirty)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result == nil && collisions == 1)
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("z.txt")) == Data("winner".utf8))
        #expect(prompts == 0 && browser.preview.isDirty && browser.preview.text == "draft")
        #expect(try Data(contentsOf: first) == Data("original".utf8))
    }

    @Test func preflightRunsAgainAfterDirtyChoicesBeforeTheFirstMove() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let last = try fixture.file("z.txt")
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in
            try? Data("winner".utf8).write(to: fixture.destination.appendingPathComponent("z.txt"))
            answer(.discard)
        })
        try await fixture.prepare(browser, selecting: last, dirty: true)
        browser.select([first, last], in: .left, focusedItem: last)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.failed == last && result?.completed.isEmpty == true && result?.unattempted == [first])
        #expect(browser.preview.isDirty && browser.preview.text == "draft" && browser.preview.canEdit)
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("z.txt")) == Data("winner".utf8))
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a.txt").path))
    }

    @Test func dirtyDecisionRetainsCapturedBatchWhileDestinationNavigatesAway() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, completion in answer = completion })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([first, dirty], in: .left, focusedItem: dirty)
        let moving = Task { await browser.moveToOtherPane(from: .left) }
        try await waitForMove { answer != nil }
        let completion = try #require(answer)
        defer { completion(.cancel) }
        #expect(!browser.preview.canEdit && !browser.canMove(in: .left))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
        await browser.right.navigate(to: fixture.root)
        let navigation = browser.right.listingRevision
        browser.setMode(.onePane)
        completion(.discard)
        let result = await moving.value
        #expect(result?.completed == [first, dirty].map { fixture.destination.appendingPathComponent($0.lastPathComponent) })
        #expect(result?.succeeded == true && browser.preview.selection == nil)
        #expect(browser.right.directory == fixture.root && browser.right.listingRevision == navigation)
        #expect(browser.mode == .onePane && browser.left.entries.isEmpty)
    }

    @Test func capturedBatchKeepsItsTargetsAndLocksEverySourceDuringNavigation() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let gate = OperationGate()
        let browser = BrowserState(homeDirectory: fixture.source, move: { operation in
            do {
                if operation.source == sources[0] { try await gate.pause() }
                return await operation.move()
            } catch {
                return ItemMove.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
            }
        })
        try await fixture.prepare(browser, selecting: sources[0])
        browser.select(Set(sources), in: .left)
        let moving = Task { await browser.moveToOtherPane(from: .left) }
        try await waitForMove { browser.isMoving }
        try await gate.waitForRequest()
        for source in sources {
            browser.select([source], in: .left)
            await browser.preview.load(browser.detailsSelection)
            #expect(!browser.preview.canEdit)
        }
        #expect(await browser.moveToOtherPane(from: .left) == nil && !browser.canCopy(in: .left) && !browser.canRename())
        await browser.navigate(to: fixture.root, in: .right)
        let navigation = browser.right.listingRevision
        browser.setMode(.onePane)
        try await gate.finish()
        let result = await moving.value
        #expect(result?.succeeded == true && result?.completed.count == 3)
        #expect(browser.right.directory == fixture.root && browser.right.listingRevision == navigation)
        #expect(browser.mode == .onePane && browser.focusedPane == .right)
        #expect(browser.left.entries.isEmpty)
    }

    @Test(arguments: [false, true])
    func discardClosesOnlyTheDocumentWhoseMoveCompleted(dirtyFirst: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let dirty = sources[dirtyFirst ? 0 : 1]
        let browser = BrowserState(homeDirectory: fixture.source, move: { operation in
            if operation.source == sources[1] { return await operation.move(using: { _, _ in throw POSIXError(.EACCES) }) }
            return await operation.move()
        }, confirmChanges: { _, answer in answer(.discard) })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select(Set(sources), in: .left, focusedItem: dirty)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.completed == [fixture.destination.appendingPathComponent("a.txt")])
        #expect(result?.failed == sources[1] && result?.unattempted == [sources[2]])
        #expect(browser.left.entries.map(\.name) == ["b.txt", "c.txt"] && browser.right.entries.map(\.name) == ["a.txt"])
        if dirtyFirst {
            #expect(browser.preview.selection == nil && !browser.preview.isDirty)
            #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("a.txt")) == Data("original".utf8))
        } else {
            #expect(browser.preview.isDirty && browser.preview.text == "draft" && browser.preview.canEdit)
            #expect(browser.preview.selection?.item.url == dirty && browser.left.primaryItemURL == dirty)
            #expect(try Data(contentsOf: dirty) == Data("original".utf8))
        }
    }

    @Test func partialMoveAndRefreshFailureRetainPerItemOutcomesAndUsableRows() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let moved = fixture.destination.appendingPathComponent("a.txt")
        let browser = BrowserState(homeDirectory: fixture.source, load: { directory in
            if FileManager.default.fileExists(atPath: moved.path) { throw POSIXError(.EACCES) }
            return try await DirectoryListing.read(directory)
        }, move: { operation in
            if operation.source == sources[1] { return await operation.move(using: { _, _ in throw POSIXError(.ENOSPC) }) }
            return await operation.move()
        })
        try await fixture.prepare(browser, selecting: sources[0])
        browser.select(Set(sources), in: .left)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.completed == [moved] && result?.failed == sources[1] && result?.unattempted == [sources[2]])
        #expect(browser.moveOutcome?.completed == result?.completed && result?.message.contains("refresh") == true)
        #expect(browser.notifications.notices.first?.kind == .error)
        #expect(browser.notifications.notices.first?.message == result?.message)
        #expect(browser.left.entries.map(\.name) == ["b.txt", "c.txt"] && browser.right.entries.map(\.name) == ["a.txt"])
    }

    @Test func cleanupFailureReconcilesEveryRemovedSourceAndClosesItsDraft() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let browser = BrowserState(homeDirectory: fixture.source, move: { operation in
            if operation.source == sources[1] {
                return await operation.move(using: fixture.rename(crossVolume: true), remove: { url in
                    if url != sources[1] { throw POSIXError(.EACCES) }
                    try FileManager.default.removeItem(at: url)
                })
            }
            return await operation.move()
        }, confirmChanges: { _, answer in answer(.discard) })
        try await fixture.prepare(browser, selecting: sources[1], dirty: true)
        browser.select(Set(sources), in: .left, focusedItem: sources[1])
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.completed.count == 2 && result?.failed == sources[1] && result?.unattempted == [sources[2]])
        #expect(result?.message.contains("cleanup") == true && result?.relocated.count == 2)
        #expect(browser.preview.selection == nil && !browser.preview.isDirty)
        #expect(browser.left.entries.map(\.name) == ["c.txt"] && browser.right.entries.map(\.name) == ["a.txt", "b.txt"])
    }
}
