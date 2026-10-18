import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor struct MoveReplacementTests {
    @Test(arguments: [false, true])
    func replacesRegularFilesAndRemovesOnlyTheApprovedDestination(crossVolume: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let previous = try fixture.identity(destination)
        let browser = BrowserState(homeDirectory: fixture.source,
            move: { await $0.move(using: fixture.rename(crossVolume: crossVolume)) },
            resolveTransferCollision: { collision, answer in
                #expect(collision.canReplace)
                #expect((try? fixture.identity(destination)) == previous)
                answer(.replace)
            })
        try await fixture.prepare(browser, selecting: source)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == true && result?.completed.map(\.path) == [destination.path])
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect((try? Data(contentsOf: destination)) == Data("original".utf8))
        #expect((try? FileManager.default.contentsOfDirectory(atPath: fixture.destination.path)) == ["report.txt"])
    }

    @Test(arguments: ["folder", "package", "source-link", "destination-link"])
    func neverOffersReplaceForFoldersPackagesOrLinks(kind: String) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let name = kind == "package" ? "Sample.app" : "sample"
        let source = fixture.source.appendingPathComponent(name)
        let destination = fixture.destination.appendingPathComponent(name)
        if kind == "folder" || kind == "package" {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        } else if kind == "source-link" {
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: "missing")
        } else { try Data("source".utf8).write(to: source) }
        if kind == "destination-link" {
            try FileManager.default.createSymbolicLink(atPath: destination.path, withDestinationPath: "missing")
        } else { try Data("previous".utf8).write(to: destination) }
        let batch = try await ItemMove.Batch.captureForResolvingCollisions([source], to: fixture.destination)
        let result = try await batch.resolvingCollisions { collision in
            #expect(!collision.canReplace)
            return .cancel
        }
        #expect(result == nil)
    }

    @Test(arguments: [false, true])
    func changedDestinationDuringChoiceRejectsTheWholeBatch(inPlace: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "z.txt"].map(fixture.file)
        let destination = fixture.destination.appendingPathComponent("z.txt")
        try Data("previous".utf8).write(to: destination)
        let browser = BrowserState(homeDirectory: fixture.source, resolveTransferCollision: { _, answer in
            if !inPlace { try? FileManager.default.moveItem(at: destination, to: fixture.destination.appendingPathComponent("preserved")) }
            try? Data("changed".utf8).write(to: destination)
            answer(.replace)
        })
        try await fixture.prepare(browser, selecting: sources[0])
        browser.select(Set(sources), in: .left)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == false && result?.completed.isEmpty == true && result?.failed?.path == sources[1].path)
        #expect((try? Data(contentsOf: destination)) == Data("changed".utf8))
        for source in sources { #expect((try? Data(contentsOf: source)) == Data("original".utf8)) }
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a.txt").path))
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel], [false, true])
    func resolvesBothSourceAndDestinationDraftsBeforeReplacement(choice: BrowserState.UnsavedChoice, saveFails: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("draft.txt")
        let destination = fixture.destination.appendingPathComponent("draft.txt")
        try Data("previous".utf8).write(to: destination)
        let operations = FileOperationCoordinator()
        var sourcePrompts = 0
        var destinationPrompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, operations: operations,
            resolveTransferCollision: { _, answer in answer(.replace) },
            confirmChanges: { _, answer in sourcePrompts += 1; answer(.discard) })
        let preview = saveFails ? PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) }) : PreviewState()
        let editor = BrowserState(homeDirectory: fixture.destination, operations: operations, preview: preview,
            confirmChanges: { _, answer in destinationPrompts += 1; answer(choice) })
        operations.register(editor)
        try await fixture.prepare(browser, selecting: source, dirty: true)
        await editor.left.refresh()
        editor.select([destination], in: .left)
        await editor.preview.load(editor.detailsSelection)
        editor.preview.setMode(.edit)
        await editor.preview.updateText("destination draft")?.value
        let result = await browser.moveToOtherPane(from: .left)
        #expect(destinationPrompts == 1)
        #expect(sourcePrompts == ((choice == .cancel || (choice == .save && saveFails)) ? 0 : 1))
        if choice == .cancel || (choice == .save && saveFails) {
            #expect(result == nil && browser.preview.isDirty && editor.preview.isDirty)
            #expect((try? Data(contentsOf: source)) == Data("original".utf8))
            #expect((try? Data(contentsOf: destination)) == Data("previous".utf8))
        } else {
            #expect(result?.succeeded == true && browser.preview.selection == nil && editor.preview.selection == nil)
            #expect((try? Data(contentsOf: destination)) == Data("original".utf8))
        }
        #expect(!operations.isBusy)
    }
    @Test(arguments: ["rename", "copy", "publish"])
    func failureBeforePublicationRestoresThePreviousDestination(failure: String) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let previous = try fixture.identity(destination)
        let batch = try await replacementBatch([source], fixture: fixture)
        let result = await batch.move { operation in
            await operation.move(using: { from, to in
                if from.path == source.path { throw POSIXError(failure == "rename" ? .EACCES : .EXDEV) }
                if failure == "publish" { throw POSIXError(.EACCES) }
                try ItemMove.exclusiveRename(from, to)
            }, copy: { from, to in
                if failure == "copy" {
                    try Data("partial".utf8).write(to: to)
                    throw POSIXError(.ENOSPC)
                }
                try FileManager.default.copyItem(at: from, to: to)
            })
        }
        #expect(!result.succeeded && result.relocated.isEmpty && result.replaced.isEmpty)
        #expect((try? Data(contentsOf: source)) == Data("original".utf8))
        #expect((try? Data(contentsOf: destination)) == Data("previous".utf8))
        #expect(try fixture.identity(destination) == previous)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path) == ["report.txt"])
    }

    @Test func lateWinnerIsPreservedAndThePreviousDestinationHasAReportedRecoveryPath() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let batch = try await replacementBatch([source], fixture: fixture)
        let result = await batch.move { operation in
            await operation.move(using: { from, to in
                try Data("late winner".utf8).write(to: to)
                try ItemMove.exclusiveRename(from, to)
            })
        }
        #expect(!result.succeeded && result.relocated.isEmpty && result.replaced.isEmpty)
        #expect((try? Data(contentsOf: destination)) == Data("late winner".utf8))
        #expect((try? Data(contentsOf: source)) == Data("original".utf8))
        let recovery = try #require(try FileManager.default.contentsOfDirectory(at: fixture.destination, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix(".panepeek-replace-") })
        let previous = recovery.appendingPathComponent("report.txt")
        #expect(try Data(contentsOf: previous) == Data("previous".utf8))
        #expect(result.message.contains(batch.items[0].destination.deletingLastPathComponent().appendingPathComponent(recovery.lastPathComponent).appendingPathComponent("report.txt").path) && result.message.contains("Recovery"))
    }

    @Test(arguments: [false, true])
    func publicationAndCleanupFailuresKeepRecoverableBytesAndTruthfulOutcomes(cleanup: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let batch = try await replacementBatch([source], fixture: fixture)
        let result = await batch.move { operation in
            await operation.move(using: fixture.rename(crossVolume: true), remove: { url in
                if cleanup ? url.lastPathComponent.hasPrefix(".panepeek-replace-") : url.path == source.path { throw POSIXError(.EACCES) }
                try FileManager.default.removeItem(at: url)
            })
        }
        #expect(!result.succeeded && result.replaced.map(\.path) == [destination.path])
        #expect(result.completed.map(\.path) == (cleanup ? [destination.path] : []))
        #expect(FileManager.default.fileExists(atPath: source.path) == !cleanup)
        #expect(try Data(contentsOf: destination) == Data("original".utf8))
        let recovery = try #require(try FileManager.default.contentsOfDirectory(at: fixture.destination, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix(".panepeek-replace-") })
        let previous = recovery.appendingPathComponent("report.txt")
        #expect(try Data(contentsOf: previous) == Data("previous".utf8))
        #expect(result.message.contains(batch.items[0].destination.deletingLastPathComponent().appendingPathComponent(recovery.lastPathComponent).appendingPathComponent("report.txt").path))
    }

    @Test func laterCancelLeavesEarlierReplaceUnstarted() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "z.txt"].map(fixture.file)
        for source in sources { try Data("previous".utf8).write(to: fixture.destination.appendingPathComponent(source.lastPathComponent)) }
        var choices = 0
        let browser = BrowserState(homeDirectory: fixture.source, resolveTransferCollision: { _, answer in
            choices += 1
            answer(choices == 1 ? .replace : .cancel)
        })
        try await fixture.prepare(browser, selecting: sources[0])
        browser.select(Set(sources), in: .left)
        #expect(await browser.moveToOtherPane(from: .left) == nil && choices == 2)
        for source in sources {
            #expect(try Data(contentsOf: source) == Data("original".utf8))
            #expect(try Data(contentsOf: fixture.destination.appendingPathComponent(source.lastPathComponent)) == Data("previous".utf8))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).count == 2)
    }

    @Test(arguments: [false, true])
    func failureRetainsSourceDraftAndClosesDestinationDraftOnlyAfterPublication(published: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("draft.txt")
        let destination = fixture.destination.appendingPathComponent("draft.txt")
        try Data("previous".utf8).write(to: destination)
        let operations = FileOperationCoordinator()
        let renaming: @Sendable (URL, URL) throws -> Void = { from, to in
            if !published { throw POSIXError(.EACCES) }
            try fixture.rename(crossVolume: true)(from, to)
        }
        let browser = BrowserState(homeDirectory: fixture.source, operations: operations,
            move: { operation in
                await operation.move(using: renaming, remove: { url in
                    if url.path == source.path { throw POSIXError(.EACCES) }
                    try FileManager.default.removeItem(at: url)
                })
            }, resolveTransferCollision: { _, answer in answer(.replace) }, confirmChanges: { _, answer in answer(.discard) })
        let editor = BrowserState(homeDirectory: fixture.destination, operations: operations, confirmChanges: { _, answer in answer(.discard) })
        operations.register(editor)
        try await fixture.prepare(browser, selecting: source, dirty: true)
        await editor.left.refresh()
        editor.select([destination], in: .left)
        await editor.preview.load(editor.detailsSelection)
        editor.preview.setMode(.edit)
        await editor.preview.updateText("destination draft")?.value
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == false && result?.completed.isEmpty == true)
        #expect(browser.preview.isDirty && browser.preview.text == "draft" && browser.preview.canEdit)
        #expect(editor.preview.isDirty == !published)
        #expect((editor.preview.selection == nil) == published)
        #expect(try Data(contentsOf: destination) == Data((published ? "original" : "previous").utf8))
    }

    @Test func pendingReplaceLocksTheDestinationAndRetainsCapturedTarget() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("report.txt")
        let destination = fixture.destination.appendingPathComponent("report.txt")
        try Data("previous".utf8).write(to: destination)
        let operations = FileOperationCoordinator()
        var answer: (@MainActor (ItemMove.CollisionChoice) -> Void)?
        let browser = BrowserState(homeDirectory: fixture.source, operations: operations,
            resolveTransferCollision: { _, completion in answer = completion })
        let editor = BrowserState(homeDirectory: fixture.destination, operations: operations)
        operations.register(editor)
        try await fixture.prepare(browser, selecting: source)
        await editor.left.refresh()
        editor.select([destination], in: .left)
        await editor.preview.load(editor.detailsSelection)
        editor.preview.setMode(.edit)
        #expect(editor.preview.canEdit)
        let moving = Task { await browser.moveToOtherPane(from: .left) }
        try await waitForMove { answer != nil }
        let completion = try #require(answer)
        defer { completion(.cancel) }
        #expect(!editor.preview.canEdit && !editor.canCreate() && !browser.canMove(in: .left))
        await browser.right.navigate(to: fixture.root)
        browser.setMode(.onePane)
        completion(.replace)
        let result = await moving.value
        #expect(result?.succeeded == true && editor.preview.selection == nil)
        #expect(browser.right.directory == fixture.root && browser.mode == .onePane && !operations.isBusy)
        #expect(try Data(contentsOf: destination) == Data("original".utf8))
    }

    @Test func explicitSourceSaveRetainsTheApprovedDestinationSnapshot() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("draft.txt")
        let destination = fixture.destination.appendingPathComponent("draft.txt")
        try Data("previous".utf8).write(to: destination)
        let browser = BrowserState(homeDirectory: fixture.source,
            resolveTransferCollision: { _, answer in answer(.replace) }, confirmChanges: { _, answer in answer(.save) })
        try await fixture.prepare(browser, selecting: source, dirty: true)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == true && browser.preview.selection == nil)
        #expect(try Data(contentsOf: destination) == Data("draft".utf8))
    }

    @Test func changedDestinationAfterDirtyDecisionRejectsBeforeAnyMove() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "z.txt"].map(fixture.file)
        let destination = fixture.destination.appendingPathComponent("z.txt")
        try Data("previous".utf8).write(to: destination)
        let browser = BrowserState(homeDirectory: fixture.source,
            resolveTransferCollision: { _, answer in answer(.replace) }, confirmChanges: { _, answer in
                try? Data("changed after choice".utf8).write(to: destination)
                answer(.discard)
            })
        try await fixture.prepare(browser, selecting: sources[1], dirty: true)
        browser.select(Set(sources), in: .left, focusedItem: sources[1])
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == false && result?.completed.isEmpty == true)
        #expect(browser.preview.isDirty && browser.preview.text == "draft" && browser.preview.canEdit)
        for source in sources { #expect(try Data(contentsOf: source) == Data("original".utf8)) }
        #expect(try Data(contentsOf: destination) == Data("changed after choice".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.appendingPathComponent("a.txt").path))
    }

    @Test func batchStopsAfterTheFirstFailureAndReportsOnlyCommittedReplacements() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try ["a.txt", "b.txt", "c.txt"].map(fixture.file)
        for source in sources { try Data("previous".utf8).write(to: fixture.destination.appendingPathComponent(source.lastPathComponent)) }
        let batch = try await replacementBatch(sources, fixture: fixture)
        let result = await batch.move { operation in
            if operation.source.path == sources[1].path { return await operation.move(using: { _, _ in throw POSIXError(.EACCES) }) }
            return await operation.move()
        }
        #expect(!result.succeeded && result.completed == [batch.items[0].destination] && result.replaced == result.completed)
        #expect(result.failed == batch.items[1].source && result.unattempted == [batch.items[2].source])
        #expect(try Data(contentsOf: batch.items[0].destination) == Data("original".utf8))
        for index in [1, 2] {
            #expect(try Data(contentsOf: sources[index]) == Data("original".utf8))
            #expect(try Data(contentsOf: batch.items[index].destination) == Data("previous".utf8))
        }
    }

    @Test(arguments: [false, true])
    func restoredDestinationDraftCanSaveWithoutAcceptingALateWinner(lateWinner: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("draft.txt")
        let destination = fixture.destination.appendingPathComponent("draft.txt")
        try Data("previous".utf8).write(to: destination)
        let operations = FileOperationCoordinator()
        let browser = BrowserState(homeDirectory: fixture.source, operations: operations,
            move: { operation in await operation.move(using: { _, target in
                if lateWinner { try Data("late winner".utf8).write(to: target) }
                throw POSIXError(.EACCES)
            }) }, resolveTransferCollision: { _, answer in answer(.replace) })
        let editor = BrowserState(homeDirectory: fixture.destination, operations: operations, confirmChanges: { _, answer in answer(.discard) })
        operations.register(editor)
        try await fixture.prepare(browser, selecting: source)
        await editor.left.refresh()
        editor.select([destination], in: .left)
        await editor.preview.load(editor.detailsSelection)
        editor.preview.setMode(.edit)
        await editor.preview.updateText("retained destination draft")?.value
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == false && editor.preview.isDirty)
        #expect(await editor.preview.save() == !lateWinner)
        #expect(try Data(contentsOf: destination) == Data((lateWinner ? "late winner" : "retained destination draft").utf8))
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    private func replacementBatch(_ sources: [URL], fixture: MoveFixture) async throws -> ItemMove.Batch {
        let captured = try await ItemMove.Batch.captureForResolvingCollisions(sources, to: fixture.destination)
        return try #require(try await captured.resolvingCollisions { _ in .replace })
    }

}
