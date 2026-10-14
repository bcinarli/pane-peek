import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite struct ItemCopyTests {
    @Test(arguments: ["file", "folder", "package", "link", "broken-link", "directory-link"])
    func copiesContentsAndListedLinksWithoutChangingSources(kind: String) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = fixture.source.appendingPathComponent(kind == "package" ? "sample.app" : "sample")
        let target = try fixture.file("target.txt")
        if kind == "folder" || kind == "package" {
            try FileManager.default.createDirectory(at: source.appendingPathComponent("nested"), withIntermediateDirectories: true)
            try Data("nested contents".utf8).write(to: source.appendingPathComponent("nested/child.txt"))
            try FileManager.default.createSymbolicLink(atPath: source.appendingPathComponent("nested/link").path,
                                                     withDestinationPath: "child.txt")
        } else if kind.contains("link") {
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath:
                kind == "broken-link" ? "missing" : (kind == "directory-link" ? fixture.destination.path : "target.txt"))
        } else { try Data("contents 👀".utf8).write(to: source) }
        let identity = try fixture.identity(source)
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let result = await request.copy()
        #expect(result.succeeded)
        #expect(try fixture.identity(source) == identity)
        #expect(try Data(contentsOf: target) == Data("original".utf8))
        let copied = request.destination
        #expect((try? fixture.identity(copied)) != nil)
        if kind == "folder" || kind == "package" {
            #expect((try? Data(contentsOf: copied.appendingPathComponent("nested/child.txt"))) == Data("nested contents".utf8))
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: copied.appendingPathComponent("nested/link").path)) == "child.txt")
        } else if kind.contains("link") {
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: copied.path))
                    == (try FileManager.default.destinationOfSymbolicLink(atPath: source.path)))
        } else { #expect((try? Data(contentsOf: copied)) == Data("contents 👀".utf8)) }
    }

    @Test(arguments: ["file", "folder", "broken-link"])
    func knownCollisionsRejectWithoutMutation(kind: String) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("occupied")
        let occupied = fixture.destination.appendingPathComponent("occupied")
        if kind == "folder" { try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: false) }
        else if kind == "broken-link" { try FileManager.default.createSymbolicLink(atPath: occupied.path, withDestinationPath: "missing") }
        else { try Data("destination".utf8).write(to: occupied) }
        let before = try fixture.identity(occupied)
        await #expect(throws: ItemName.ValidationError.collision) { try await ItemCopy.capture(source, to: fixture.destination) }
        #expect(try fixture.identity(occupied) == before)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test func rejectsSameItemAndSymlinkResolvedDescendants() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("same.txt")
        await #expect(throws: ItemName.ValidationError.collision) { try await ItemCopy.capture(source, to: fixture.source) }
        let child = fixture.source.appendingPathComponent("nested/child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let directory = fixture.source.appendingPathComponent("nested", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: child.path)
        for destination in [directory, child, alias] {
            await #expect(throws: ItemCopy.CopyError.ancestry) { try await ItemCopy.capture(directory, to: destination) }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: child.path).isEmpty)
    }

    @Test(arguments: [false, true])
    func rejectsReplacedSourceOrDestination(destinationChanged: Bool) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let replaced = destinationChanged ? fixture.destination : source
        try FileManager.default.moveItem(at: replaced, to: fixture.root.appendingPathComponent("old"))
        if destinationChanged { try FileManager.default.createDirectory(at: replaced, withIntermediateDirectories: false) }
        else { try Data("replacement".utf8).write(to: replaced) }
        let outcome = await request.copy()
        #expect(!outcome.succeeded)
        #expect(!FileManager.default.fileExists(atPath: request.destination.path))
    }

    @Test func lateDirectoryCollisionNeverMergesOrOverwrites() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = fixture.source.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        try Data("source".utf8).write(to: source.appendingPathComponent("child.txt"))
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let outcome = await request.copy(using: { source, destination in
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            try Data("winner".utf8).write(to: destination.appendingPathComponent("child.txt"))
            try FileManager.default.copyItem(at: source, to: destination)
        })
        #expect(!outcome.succeeded)
        #expect((try? Data(contentsOf: request.destination.appendingPathComponent("child.txt"))) == Data("winner".utf8))
        #expect(try Data(contentsOf: source.appendingPathComponent("child.txt")) == Data("source".utf8))
    }

    @Test func reportsFailedCopyAndAnIncompleteDestination() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemCopy.capture(source, to: fixture.destination)
        let outcome = await request.copy(using: { _, destination in
            try Data("partial".utf8).write(to: destination)
            throw POSIXError(.ENOSPC)
        })
        #expect(!outcome.succeeded)
        #expect(outcome.message.contains(source.path) && outcome.message.contains(request.destination.path))
        #expect(outcome.message.contains("incomplete"))
        #expect((try? Data(contentsOf: request.destination)) == Data("partial".utf8))
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }
}

@Suite struct BatchCopyTests {
    @Test func copiesMixedSelectionInCapturedOrderAndPreservesSources() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let file = try fixture.file("a.txt")
        let folder = fixture.source.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try Data("nested".utf8).write(to: folder.appendingPathComponent("child.txt"))
        let link = fixture.source.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "a.txt")
        let sources = [folder, link, file]
        let batch = try await ItemCopy.Batch.capture(sources, to: fixture.destination)
        let outcome = await batch.copy()
        #expect(outcome.succeeded && outcome.failed == nil && outcome.unattempted.isEmpty)
        #expect(outcome.completed == batch.items.map(\.destination))
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("folder/child.txt"))) == Data("nested".utf8))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: fixture.destination.appendingPathComponent("link").path)) == "a.txt")
        for source in sources { #expect((try? fixture.identity(source)) != nil) }
    }

    @Test(arguments: ["collision", "descendant", "duplicate-name"])
    func knownConflictRejectsEveryItemBeforeMutation(conflict: String) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("b.txt")
        var sources = [first, second]
        var destination = fixture.destination
        if conflict == "collision" { try Data("occupied".utf8).write(to: destination.appendingPathComponent("b.txt")) }
        if conflict == "descendant" { sources[1] = fixture.root; destination = fixture.destination }
        if conflict == "duplicate-name" {
            let other = fixture.root.appendingPathComponent("a.txt")
            try Data("other".utf8).write(to: other)
            sources[1] = other
        }
        do {
            _ = try await ItemCopy.Batch.capture(sources, to: destination)
            Issue.record("Expected the conflicting item to reject the copy batch")
        } catch let error as ItemCopy.PreflightError {
            #expect(error.source == sources[1])
            #expect(error.destination == destination.resolvingSymlinksInPath().appendingPathComponent(sources[1].lastPathComponent))
            let reason = conflict == "descendant"
                ? ItemCopy.CopyError.ancestry.localizedDescription
                : ItemName.ValidationError.collision.localizedDescription
            #expect(error.reason == reason)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("a.txt").path))
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        if conflict == "duplicate-name" {
            #expect(try Data(contentsOf: sources[1]) == Data("other".utf8))
        } else {
            #expect(try Data(contentsOf: second) == Data("original".utf8))
        }
        if conflict == "collision" {
            #expect(try Data(contentsOf: destination.appendingPathComponent("b.txt")) == Data("occupied".utf8))
        }
    }

    @Test func distinctUnicodeNamesFollowTheFilesystem() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let first = try fixture.file("ss.txt")
        let second: URL
        do { second = try await ItemCreation.create(.textFile, named: "ß.txt", in: fixture.source) }
        catch ItemName.ValidationError.collision {
            let alias = fixture.source.appendingPathComponent("ß.txt")
            #expect(try fixture.identity(first) == fixture.identity(alias))
            await #expect(throws: (any Error).self) { try await ItemCopy.Batch.capture([first, alias], to: fixture.destination) }
            #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
            return
        }
        try Data("distinct unicode name".utf8).write(to: second)
        let batch = try await ItemCopy.Batch.capture([first, second], to: fixture.destination)
        let outcome = await batch.copy()
        #expect(outcome.succeeded && outcome.completed.count == 2)
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("ss.txt")) == Data("original".utf8))
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("ß.txt")) == Data("distinct unicode name".utf8))
    }

    @Test func repeatsWholePreflightBeforeTheFirstWrite() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("b.txt")
        let batch = try await ItemCopy.Batch.capture([first, second], to: fixture.destination)
        try Data("late occupied".utf8).write(to: fixture.destination.appendingPathComponent("b.txt"))
        let result = await batch.copy()
        #expect(!result.succeeded && result.completed.isEmpty && result.failed == second)
        #expect(result.unattempted == [first])
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a.txt").path))
        #expect(try Data(contentsOf: fixture.destination.appendingPathComponent("b.txt")) == Data("late occupied".utf8))
    }

    @Test func realUnreadableSourceReportsPartialSuccessWithoutCopyingLaterItems() async throws {
        if geteuid() == 0 { return }
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map { try fixture.file($0) }
        let batch = try await ItemCopy.Batch.capture(sources, to: fixture.destination)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: sources[1].path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: sources[1].path) }
        let result = await batch.copy()
        #expect(!result.succeeded && result.completed == [batch.items[0].destination])
        #expect(result.failed == sources[1] && result.unattempted == [sources[2]])
        #expect((try? Data(contentsOf: batch.items[0].destination)) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: batch.items[2].destination.path))
    }

    @Test func executionStopsAtFirstFailureAndKeepsCompletedCopies() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map { try fixture.file($0) }
        let batch = try await ItemCopy.Batch.capture(sources, to: fixture.destination)
        let result = await batch.copy { operation in
            if operation.source.lastPathComponent == "b.txt" {
                return await operation.copy(using: { _, destination in
                    try Data("partial".utf8).write(to: destination)
                    throw POSIXError(.ENOSPC)
                })
            }
            return await operation.copy()
        }
        #expect(!result.succeeded && result.completed == [batch.items[0].destination])
        #expect(result.failed == sources[1] && result.unattempted == [sources[2]])
        #expect(result.message.contains("Completed") && result.message.contains("Unattempted") && result.message.contains("incomplete"))
        #expect((try? Data(contentsOf: batch.items[0].destination)) == Data("original".utf8))
        #expect((try? Data(contentsOf: batch.items[1].destination)) == Data("partial".utf8))
        #expect(!FileManager.default.fileExists(atPath: batch.items[2].destination.path))
        for source in sources { #expect(try Data(contentsOf: source) == Data("original".utf8)) }
    }
}

@Suite @MainActor struct BrowserCopyTests {
    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func selectedDirtyItemIsResolvedBeforeAnyBatchCopy(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let dirty = try fixture.file("z-dirty.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in prompts += 1; answer(choice) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([first, dirty], in: .left, focusedItem: dirty)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        let result = await browser.copyToOtherPane(from: .left)
        #expect(prompts == 1)
        if choice == .cancel {
            #expect(result == nil && browser.preview.isDirty)
            #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
        } else {
            #expect(result?.succeeded == true && result?.completed.count == 2)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("z-dirty.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test(arguments: [PaneID.left, .right])
    func copiesInEitherDirectionAndRefreshesWithoutChangingSelection(from: PaneID) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        let destinationID: PaneID = from == .left ? .right : .left
        await browser.pane(from).refresh()
        await browser.pane(destinationID).navigate(to: fixture.destination)
        browser.select([source], in: from)
        let sourceRevision = browser.pane(from).listingRevision
        let targetRevision = browser.pane(destinationID).listingRevision
        let outcome = await browser.copyToOtherPane(from: from)
        #expect(outcome?.succeeded == true)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data("original".utf8))
        #expect(browser.pane(from).selectedItems == [source] && browser.focusedPane == from)
        #expect(browser.pane(from).listingRevision != sourceRevision && browser.pane(destinationID).listingRevision != targetRevision)
    }

    @Test(arguments: [false, true])
    func capturedTargetsSurviveNavigationAndLayoutWhileDuplicateMutationsAreRejected(saveDraft: Bool) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let gate = OperationGate()
        let browser = BrowserState(homeDirectory: fixture.source, copy: { operation in
            do {
                try await gate.pause()
                return await operation.copy()
            } catch {
                return ItemCopy.Outcome(succeeded: false, message: error.localizedDescription)
            }
        }, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        if saveDraft { await browser.preview.updateText("saved draft")?.value }
        let copying = Task { await browser.copyToOtherPane(from: .left) }
        try await waitForCopy { browser.isCopying }
        try await gate.waitForRequest()
        #expect(browser.isCopying && !browser.canCopy(in: .left) && !browser.canRename())
        #expect(!browser.preview.canEdit)
        browser.beginCreation(.folder)
        #expect(browser.creationRequest == nil)
        #expect(await browser.copyToOtherPane(from: .left) == nil)
        await browser.navigate(to: fixture.root, in: .right)
        let revision = browser.right.listingRevision
        browser.setMode(.onePane)
        #expect(await browser.copyToOtherPane(from: .right) == nil)
        try await gate.finish()
        let outcome = await copying.value
        #expect(outcome?.succeeded == true && !browser.isCopying)
        #expect(browser.right.directory == fixture.root && browser.right.listingRevision == revision)
        #expect(browser.mode == .onePane && browser.focusedPane == .right)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data((saveDraft ? "saved draft" : "original").utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("source.txt").path))
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func dirtyChoicesResolveBeforeCopy(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in prompts += 1; answer(choice) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        let outcome = await browser.copyToOtherPane(from: .left)
        #expect(prompts == 1)
        if choice == .cancel {
            #expect(outcome == nil && browser.preview.isDirty && browser.preview.text == "draft")
            #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("source.txt").path))
        } else {
            #expect(outcome?.succeeded == true && !browser.preview.isDirty)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
        #expect(try Data(contentsOf: source) == Data((choice == .save ? "draft" : "original").utf8))
    }

    @Test(arguments: [false, true])
    func failedSaveOrPreflightRetainsTheDraft(preflight: Bool) async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let first = try fixture.file("a.txt")
        if preflight { try Data("occupied".utf8).write(to: fixture.destination.appendingPathComponent("source.txt")) }
        let preview = PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) })
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, preview: preview,
                                   confirmChanges: { _, answer in prompts += 1; answer(.save) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([first, source], in: .left, focusedItem: source)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        let outcome = await browser.copyToOtherPane(from: .left)
        #expect(outcome?.succeeded != true)
        #expect(prompts == (preflight ? 0 : 1))
        #expect(preview.isDirty && preview.text == "draft" && preview.canEdit)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a.txt").path))
        if !preflight { #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("source.txt").path)) }
    }

    @Test func batchUsesCapturedSelectionAndDestinationAndLocksEverySource() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("b.txt")
        let other = try fixture.file("other.txt")
        let gate = OperationGate()
        let browser = BrowserState(homeDirectory: fixture.source, copy: { operation in
            do {
                if operation.source == first { try await gate.pause() }
                return await operation.copy()
            } catch {
                return ItemCopy.Outcome(succeeded: false, message: error.localizedDescription)
            }
        })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([first, second], in: .left, focusedItem: second)
        await browser.preview.load(browser.detailsSelection)
        let copying = Task { await browser.copyToOtherPane(from: .left) }
        try await waitForCopy { browser.isCopying }
        try await gate.waitForRequest()
        #expect(!browser.preview.canEdit)
        browser.select([first], in: .left)
        await browser.preview.load(browser.detailsSelection)
        #expect(!browser.preview.canEdit)
        browser.select([other], in: .left)
        await browser.preview.load(browser.detailsSelection)
        #expect(browser.preview.canEdit)
        await browser.navigate(to: fixture.root, in: .right)
        browser.setMode(.onePane)
        try await gate.finish()
        let outcome = await copying.value
        #expect(outcome?.succeeded == true && outcome?.completed.count == 2)
        #expect(browser.right.directory == fixture.root && browser.mode == .onePane)
        #expect(browser.left.selectedItems == [other])
        for name in ["a.txt", "b.txt"] {
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent(name))) == Data("original".utf8))
            #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent(name).path))
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("other.txt").path))
    }

    @Test func batchPartialOutcomeSurvivesRefreshAndShowsFailedAndUnattemptedPaths() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map { try fixture.file($0) }
        let browser = BrowserState(homeDirectory: fixture.source, copy: { operation in
            if operation.source.lastPathComponent == "b.txt" { return await operation.copy(using: { _, _ in throw POSIXError(.EACCES) }) }
            return await operation.copy()
        })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select(Set(sources), in: .left)
        let result = await browser.copyToOtherPane(from: .left)
        #expect(result?.succeeded == false && result?.completed == [fixture.destination.appendingPathComponent("a.txt")])
        #expect(result?.failed == sources[1] && result?.unattempted == [sources[2]])
        #expect(browser.copyOutcome?.completed == result?.completed && browser.copyOutcome?.failed == result?.failed)
        #expect(browser.right.entries.map(\.name) == ["a.txt"])
        #expect(browser.left.selectedItems == Set(sources))
    }

    @Test func staleMenuAndSinglePaneCannotCopy() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let first = try fixture.file("first.txt")
        let second = try fixture.file("second.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([first], in: .left)
        #expect(browser.canCopy(in: .left))
        browser.select([second], in: .left)
        #expect(await browser.copyToOtherPane(from: .left, items: [first]) == nil)
        browser.select([first, second], in: .left)
        #expect(browser.canCopy(in: .left))
        #expect(await browser.copyToOtherPane(from: .left, items: [first]) == nil)
        browser.select([first], in: .left)
        browser.setMode(.onePane)
        #expect(!browser.canCopy(in: .left) && !browser.canCopy(in: .right))
        #expect(await browser.copyToOtherPane(from: .left) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func completionRefreshRetainsAnUnrelatedDraftWithoutPrompting() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let other = try fixture.file("other.txt")
        let gate = OperationGate()
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, copy: { operation in
            do {
                try await gate.pause()
                return await operation.copy()
            } catch {
                return ItemCopy.Outcome(succeeded: false, message: error.localizedDescription)
            }
        }, confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        let copying = Task { await browser.copyToOtherPane(from: .left) }
        try await waitForCopy { browser.isCopying }
        try await gate.waitForRequest()
        browser.select([other], in: .left)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("unrelated draft")?.value
        let document = browser.preview.documentID
        let revision = browser.left.listingRevision
        try await gate.finish()
        let result = await copying.value
        #expect(result?.succeeded == true && prompts == 0)
        #expect(browser.preview.documentID == document && browser.preview.isDirty && browser.preview.text == "unrelated draft")
        #expect(browser.left.listingRevision != revision && browser.left.primaryItemURL == other)
    }

    @Test func successfulCopyWithFailedRefreshReportsActualDiskSuccess() async throws {
        let fixture = try CopyFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let reads = CopyReadGate()
        let browser = BrowserState(homeDirectory: fixture.source, load: { try await reads.read($0) }, copy: { operation in
            let result = await operation.copy()
            await reads.fail()
            return result
        })
        await browser.left.refresh()
        await browser.right.navigate(to: fixture.destination)
        browser.select([source], in: .left)
        let outcome = await browser.copyToOtherPane(from: .left)
        #expect(outcome?.succeeded == true)
        #expect(outcome?.message.contains("refresh") == true)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data("original".utf8))
        #expect(browser.left.selectedItems == [source] && browser.right.directory == fixture.destination)
    }
}

@MainActor private func waitForCopy(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
}

private actor CopyReadGate {
    private var failed = false
    func fail() { failed = true }
    func read(_ directory: URL) async throws -> DirectoryListing {
        if failed { throw POSIXError(.EACCES) }
        return try await DirectoryListing.read(directory)
    }
}

private struct CopyFixture: Sendable {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    var source: URL { root.appendingPathComponent("source", isDirectory: true) }
    var destination: URL { root.appendingPathComponent("destination", isDirectory: true) }
    init() throws {
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
    }
    func file(_ name: String) throws -> URL {
        let url = source.appendingPathComponent(name)
        try Data("original".utf8).write(to: url)
        return url
    }
    func identity(_ url: URL) throws -> ino_t {
        var attributes = stat()
        guard lstat(url.path, &attributes) == 0 else { throw POSIXError(.ENOENT) }
        return attributes.st_ino
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
