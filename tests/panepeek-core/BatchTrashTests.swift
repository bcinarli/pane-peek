import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite struct BatchTrashTests {
    @Test func trashesMixedCapturedSelectionWithoutTraversingLinks() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let file = try fixture.file("a.txt")
        let child = try fixture.file("folder/child.txt")
        let package = try fixture.file("sample.app/payload.txt")
        let link = fixture.source.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "a.txt")
        let sources = [file, child.deletingLastPathComponent(), package.deletingLastPathComponent(), link]
        let batch = try await ItemTrash.Batch.capture(sources)
        let result = await batch.trash { await recycleBatchItem($0, in: fixture) }
        #expect(result.succeeded && result.failed == nil && result.unattempted.isEmpty)
        #expect(result.completed == sources && result.removed.map(\.source) == sources)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.source.path).isEmpty)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("folder/child.txt"))) == Data("original".utf8))
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("sample.app/payload.txt"))) == Data("original".utf8))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: fixture.destination.appendingPathComponent("link").path)) == "a.txt")
    }

    @Test func changedLastItemRejectsBeforeAnyTrash() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let last = try fixture.file("z.txt")
        let batch = try await ItemTrash.Batch.capture([first, last])
        try FileManager.default.moveItem(at: last, to: fixture.root.appendingPathComponent("original"))
        try Data("replacement".utf8).write(to: last)
        let result = await batch.trash { await recycleBatchItem($0, in: fixture) }
        #expect(!result.succeeded && result.completed.isEmpty && result.removed.isEmpty)
        #expect(result.failed == last && result.unattempted == [first])
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(try Data(contentsOf: last) == Data("replacement".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test(arguments: [false, true])
    func firstFailureReportsCompletedFailedAndUnattempted(removedBeforeFailure: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let batch = try await ItemTrash.Batch.capture(sources)
        let result = await batch.trash { item in
            if item.source == sources[1] {
                return await item.trash {
                    if removedBeforeFailure { try FileManager.default.moveItem(at: $0, to: fixture.destination.appendingPathComponent("b.txt")) }
                    throw POSIXError(.EACCES)
                }
            }
            return await recycleBatchItem(item, in: fixture)
        }
        #expect(!result.succeeded && result.completed == [sources[0]])
        #expect(result.failed == sources[1] && result.unattempted == [sources[2]])
        #expect(result.removed.map(\.source) == Array(sources.prefix(removedBeforeFailure ? 2 : 1)))
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("a.txt"))) == Data("original".utf8))
        #expect(try Data(contentsOf: sources[2]) == Data("original".utf8))
        if !removedBeforeFailure { #expect(try Data(contentsOf: sources[1]) == Data("original".utf8)) }
        #expect(result.message.contains("Completed") && result.message.contains("Failed") && result.message.contains("Unattempted"))
    }
}

@Suite @MainActor struct BrowserBatchTrashTests {
    @Test func selectionTrashesDirectlyInDisplayedOrderAndBothPanesRefresh() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("z.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycleBatchItem($0, in: fixture) })
        await browser.left.refresh(); await browser.right.refresh()
        browser.select([first, second], in: .left, focusedItem: second)
        await browser.preview.load(browser.detailsSelection)
        browser.setMode(.onePane)
        #expect(browser.canTrash())
        let result = await browser.moveToTrash()
        #expect(result?.succeeded == true && result?.completed == [first, second])
        #expect(browser.notifications.notices.first?.kind == .success)
        #expect(browser.notifications.notices.first?.message == "2 items moved to Trash.")
        #expect(browser.left.entries.isEmpty && browser.right.entries.isEmpty)
        #expect(browser.preview.selection == nil)
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel], [false, true])
    func laterDirtyItemIsResolvedBeforeAnyTrash(choice: BrowserState.UnsavedChoice, failedSave: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        let preview = PreviewState(write: { snapshot, text, url in
            if failedSave { throw POSIXError(.EACCES) }
            return try await snapshot.save(text, to: url)
        })
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, preview: preview, trash: { await recycleBatchItem($0, in: fixture) }, confirmChanges: { _, answer in
            prompts += 1
            #expect(FileManager.default.fileExists(atPath: first.path))
            answer(choice)
        })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([dirty, first], in: .left, focusedItem: dirty)
        let result = await browser.moveToTrash()
        #expect(prompts == 1)
        if choice == .cancel || (choice == .save && failedSave) {
            #expect(result == nil && preview.isDirty && preview.text == "draft" && preview.canEdit)
            #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
        } else {
            #expect(result?.succeeded == true && preview.selection == nil)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("z.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test func aKnownMissingItemRejectsBeforeDiscard() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycleBatchItem($0, in: fixture) },
                                   confirmChanges: { _, answer in prompts += 1; answer(.discard) })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([first, dirty], in: .left, focusedItem: dirty)
        try FileManager.default.moveItem(at: dirty, to: fixture.root.appendingPathComponent("missing"))
        #expect(await browser.moveToTrash()?.succeeded == false)
        #expect(prompts == 0 && browser.preview.isDirty)
        #expect(try Data(contentsOf: first) == Data("original".utf8))
    }

    @Test(arguments: [0, 1, 2])
    func discardOnlyClosesTheDraftWhoseSourceWasTrashed(dirtyIndex: Int) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let browser = BrowserState(homeDirectory: fixture.source, trash: { item in
            if item.source == sources[1] { return await item.trash { _ in throw POSIXError(.EACCES) } }
            return await recycleBatchItem(item, in: fixture)
        }, confirmChanges: { _, answer in answer(.discard) })
        try await fixture.prepare(browser, selecting: sources[dirtyIndex], dirty: true)
        browser.select(Set(sources), in: .left, focusedItem: sources[dirtyIndex])
        let document = browser.preview.documentID
        let result = await browser.moveToTrash()
        #expect(result?.succeeded == false)
        #expect(browser.left.entries.map(\.url) == Array(sources.dropFirst()))
        if dirtyIndex == 0 { #expect(browser.preview.selection == nil) }
        else { #expect(browser.preview.isDirty && browser.preview.text == "draft" && browser.preview.documentID == document && browser.preview.canEdit) }
    }

    @Test func dirtyCancelRetainsEveryItemAndTheDraft() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycleBatchItem($0, in: fixture) },
                                   confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        try await fixture.prepare(browser, selecting: dirty, dirty: true)
        browser.select([first, dirty], in: .left, focusedItem: dirty)
        let document = browser.preview.documentID
        #expect(await browser.moveToTrash() == nil)
        #expect(browser.notifications.notices.isEmpty)
        #expect(prompts == 1)
        #expect(browser.preview.isDirty && browser.preview.documentID == document && browser.preview.canEdit)
        #expect(browser.left.selectedItems == [first, dirty])
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func inFlightSelectionKeepsCapturedItemsAndUnionEditLocks() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let gate = OperationGate()
        let browser = BrowserState(homeDirectory: fixture.source, trash: { item in
            do {
                if item.source == sources[0] { try await gate.pause() }
                return await recycleBatchItem(item, in: fixture)
            } catch {
                return ItemTrash.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
            }
        })
        try await fixture.prepare(browser, selecting: sources[0])
        browser.select([sources[0], sources[2]], in: .left, focusedItem: sources[0])
        let request = Task { await browser.moveToTrash() }
        try await gate.waitForRequest()
        browser.select([sources[2]], in: .left)
        await browser.preview.load(browser.detailsSelection)
        #expect(!browser.preview.canEdit)
        browser.select([sources[1]], in: .left)
        await browser.preview.load(browser.detailsSelection)
        #expect(browser.preview.canEdit)
        #expect(await browser.moveToTrash() == nil)
        await browser.left.navigate(to: fixture.root)
        browser.setMode(.onePane)
        try await gate.finish()
        let result = await request.value
        #expect(result?.completed == [sources[0], sources[2]])
        #expect(browser.left.directory == fixture.root && browser.mode == .onePane)
        #expect(try Data(contentsOf: sources[1]) == Data("original".utf8))
    }

    @Test func failedRefreshKeepsPartialOutcomeAndUnattemptedDraft() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        let browser = BrowserState(homeDirectory: fixture.source, load: { url in
            if url.path == fixture.source.path, !FileManager.default.fileExists(atPath: sources[0].path) { throw POSIXError(.EACCES) }
            return try await DirectoryListing.read(url)
        }, trash: { item in
            if item.source == sources[1] { return await item.trash { _ in throw POSIXError(.ENOTSUP) } }
            return await recycleBatchItem(item, in: fixture)
        }, confirmChanges: { _, answer in answer(.discard) })
        try await fixture.prepare(browser, selecting: sources[2], dirty: true)
        browser.select(Set(sources), in: .left, focusedItem: sources[2])
        let document = browser.preview.documentID
        let result = await browser.moveToTrash()
        #expect(result?.completed == [sources[0]] && result?.failed == sources[1] && result?.unattempted == [sources[2]])
        #expect(result?.message.contains("Couldn’t refresh") == true)
        #expect(browser.notifications.notices.first?.kind == .error)
        #expect(browser.notifications.notices.first?.message == result?.message)
        #expect(browser.trashOutcome?.completed == [sources[0]])
        #expect(browser.left.entries.map(\.url) == Array(sources.dropFirst()))
        #expect(browser.preview.isDirty && browser.preview.documentID == document && browser.preview.text == "draft" && browser.preview.canEdit)
    }

    @Test func changedSourceAfterDirtyDecisionRejectsWholeBatchBeforeMutation() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let last = try fixture.file("z.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycleBatchItem($0, in: fixture) },
                                   confirmChanges: { _, answer in
            do {
                try FileManager.default.moveItem(at: last, to: fixture.root.appendingPathComponent("old"))
                try Data("replacement".utf8).write(to: last)
            } catch { Issue.record(error) }
            answer(.discard)
        })
        try await fixture.prepare(browser, selecting: last, dirty: true)
        browser.select([first, last], in: .left, focusedItem: last)
        let result = await browser.moveToTrash()
        #expect(result?.completed.isEmpty == true && result?.failed == last && result?.unattempted == [first])
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(try Data(contentsOf: last) == Data("replacement".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func selectedFolderGuardsItsDirtyDescendantBeforeTheBatch(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let child = try fixture.file("folder/child.txt")
        let folder = child.deletingLastPathComponent()
        let other = try fixture.file("other.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycleBatchItem($0, in: fixture) }, confirmChanges: { _, answer in answer(choice) })
        await browser.left.refresh(); await browser.right.navigate(to: folder)
        browser.select([child], in: .right)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit); await browser.preview.updateText("draft")?.value
        browser.left.setSelection([folder, other])
        let result = await browser.moveToTrash(from: .left)
        if choice == .cancel {
            #expect(result == nil && browser.preview.isDirty && browser.preview.canEdit)
            #expect(try Data(contentsOf: other) == Data("original".utf8))
            #expect(try Data(contentsOf: child) == Data("original".utf8))
        } else {
            #expect(result?.succeeded == true && result?.completed == [folder, other])
            #expect(browser.preview.selection == nil && browser.right.directory.path == fixture.source.path)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("folder/child.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }
}

private func recycleBatchItem(_ item: ItemTrash, in fixture: MoveFixture) async -> ItemTrash.Outcome {
    await item.trash { try FileManager.default.moveItem(at: $0, to: fixture.destination.appendingPathComponent($0.lastPathComponent)) }
}
