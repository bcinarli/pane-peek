import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite struct ItemMoveTests {
    @Test(arguments: [false, true], ["file", "folder", "package", "link", "broken-link", "directory-link"])
    func movesContentsAndListedLinks(crossVolume: Bool, kind: String) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = fixture.source.appendingPathComponent(kind == "package" ? "sample.app" : "sample")
        let target = try fixture.file("target.txt")
        if kind == "folder" || kind == "package" {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
            try Data("nested".utf8).write(to: source.appendingPathComponent("child.txt"))
        } else if kind.contains("link") {
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath:
                kind == "broken-link" ? "missing" : (kind == "directory-link" ? fixture.destination.path : "target.txt"))
        } else { try Data("contents 👀".utf8).write(to: source) }
        let inode = try fixture.identity(source)
        let link = try? FileManager.default.destinationOfSymbolicLink(atPath: source.path)
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: fixture.rename(crossVolume: crossVolume))
        #expect(outcome.succeeded && outcome.sourceRemoved)
        #expect((try? fixture.identity(source)) == nil)
        #expect((try? fixture.identity(request.destination)) != nil)
        if !crossVolume { #expect(try fixture.identity(request.destination) == inode) }
        if kind == "folder" || kind == "package" {
            #expect((try? Data(contentsOf: request.destination.appendingPathComponent("child.txt"))) == Data("nested".utf8))
        } else if let link {
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: request.destination.path)) == link)
        } else { #expect((try? Data(contentsOf: request.destination)) == Data("contents 👀".utf8)) }
        #expect(try Data(contentsOf: target) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).count == 1)
    }

    @Test func rejectsKnownAndLateCollisionsWithoutChangingEitherItem() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        try Data("winner".utf8).write(to: request.destination)
        await #expect(throws: (any Error).self) { try await ItemMove.capture(source, to: fixture.destination) }
        let outcome = await request.move()
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(try Data(contentsOf: request.destination) == Data("winner".utf8))
    }

    @Test func crossVolumePublicationCannotReplaceALateWinner() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: fixture.rename(crossVolume: true), copy: { source, staging in
            try FileManager.default.copyItem(at: source, to: staging)
            try Data("winner".utf8).write(to: request.destination)
        })
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect((try? Data(contentsOf: request.destination)) == Data("winner".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path) == ["source.txt"])
    }

    @Test func exclusiveCommitPreservesACollisionAfterPreflight() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: { source, destination in
            try Data("winner".utf8).write(to: destination)
            try ItemMove.exclusiveRename(source, destination)
        })
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(try Data(contentsOf: request.destination) == Data("winner".utf8))
    }

    @Test func readOnlySourceParentRejectsTheRealMove() async throws {
        let fixture = try MoveFixture()
        defer { chmod(fixture.source.path, 0o700); fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        #expect(chmod(fixture.source.path, 0o555) == 0)
        let outcome = await request.move()
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: request.destination.path))
    }

    @Test(arguments: [false, true])
    func failedCrossVolumeCopyPreservesSourceAndReportsCleanup(cleanupFails: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: fixture.rename(crossVolume: true), copy: { _, staging in
            try Data("partial".utf8).write(to: staging)
            throw POSIXError(.ENOSPC)
        }, remove: { url in
            if cleanupFails { throw POSIXError(.EACCES) }
            try FileManager.default.removeItem(at: url)
        })
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: request.destination.path))
        let retained = try FileManager.default.contentsOfDirectory(at: fixture.destination, includingPropertiesForKeys: nil)
        #expect(retained.count == (cleanupFails ? 1 : 0))
        #expect(outcome.message.contains(source.path) && outcome.message.contains(request.destination.path))
        if let staging = retained.first {
            let retainedPath = request.destination.deletingLastPathComponent().appendingPathComponent(staging.lastPathComponent).path
            #expect(outcome.message.contains(retainedPath) && outcome.message.contains("cleanup"))
            #expect(try Data(contentsOf: staging.appendingPathComponent("source.txt")) == Data("partial".utf8))
        }
    }

    @Test func failedSourceRemovalRetainsTheCompleteDestination() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: fixture.rename(crossVolume: true), remove: { url in
            if url == source { throw POSIXError(.EACCES) }
            try FileManager.default.removeItem(at: url)
        })
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect((try? Data(contentsOf: request.destination)) == Data("original".utf8))
        #expect(outcome.message.contains("complete destination") && outcome.message.contains(source.path))
    }

    @Test func cleanupFailureAfterSourceRemovalStillReportsRelocation() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: fixture.rename(crossVolume: true), remove: { url in
            if url != source { throw POSIXError(.EACCES) }
            try FileManager.default.removeItem(at: url)
        })
        #expect(!outcome.succeeded && outcome.sourceRemoved)
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect((try? Data(contentsOf: request.destination)) == Data("original".utf8))
        #expect(outcome.message.contains("cleanup") && outcome.message.contains("moved"))
    }

    @Test func partialFolderRemovalRetainsAllDestinationContents() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("folder/first.txt")
        let second = try fixture.file("folder/second.txt")
        let source = first.deletingLastPathComponent()
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: fixture.rename(crossVolume: true), remove: { url in
            if url == source {
                try FileManager.default.removeItem(at: first)
                throw POSIXError(.EACCES)
            }
            try FileManager.default.removeItem(at: url)
        })
        #expect(!outcome.succeeded && !outcome.sourceRemoved && outcome.message.contains("partial"))
        #expect(!FileManager.default.fileExists(atPath: first.path) && FileManager.default.fileExists(atPath: second.path))
        #expect(try Data(contentsOf: request.destination.appendingPathComponent("first.txt")) == Data("original".utf8))
        #expect(try Data(contentsOf: request.destination.appendingPathComponent("second.txt")) == Data("original".utf8))
    }

    @Test func sourceReplacementDuringCopyIsNotRemoved() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: fixture.rename(crossVolume: true), copy: { source, staging in
            try FileManager.default.copyItem(at: source, to: staging)
            try FileManager.default.moveItem(at: source, to: fixture.root.appendingPathComponent("old"))
            try Data("replacement".utf8).write(to: source)
        })
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("replacement".utf8))
        #expect(!FileManager.default.fileExists(atPath: request.destination.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func destinationReplacementAfterPublicationDoesNotRemoveTheSource() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemMove.capture(source, to: fixture.destination)
        let outcome = await request.move(using: { candidate, destination in
            if candidate == source { throw POSIXError(.EXDEV) }
            try ItemMove.exclusiveRename(candidate, destination)
            try FileManager.default.moveItem(at: destination, to: fixture.root.appendingPathComponent("copied"))
            try Data("replacement".utf8).write(to: destination)
        })
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect((try? Data(contentsOf: source)) == Data("original".utf8))
        #expect(try Data(contentsOf: request.destination) == Data("replacement".utf8))
    }
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct BrowserMoveTests {
    @Test(arguments: [PaneID.left, .right])
    func movesDirectlyInEitherDirection(from: PaneID) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        await browser.pane(from).refresh()
        await browser.pane(from == .left ? .right : .left).navigate(to: fixture.destination)
        browser.select([source], in: from)
        await browser.preview.load(browser.detailsSelection)
        let outcome = await browser.moveToOtherPane(from: from)
        #expect(outcome?.completed == [fixture.destination.appendingPathComponent("source.txt")])
        #expect(outcome?.succeeded == true && browser.moveOutcome?.relocated.count == 1)
        #expect(browser.pane(from).selectedItems.isEmpty && browser.preview.selection == nil)
        #expect(browser.pane(from == .left ? .right : .left).entries.map(\.name) == ["source.txt"])
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }

    @Test func cancelledDirtyPromptRetainsTheSourceAndDraft() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        var dirtyPrompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, confirmChanges: { _, answer in dirtyPrompts += 1; answer(.cancel) })
        try await fixture.prepare(browser, selecting: source, dirty: true)
        let document = browser.preview.documentID
        #expect(await browser.moveToOtherPane(from: .left) == nil)
        #expect(dirtyPrompts == 1 && browser.preview.documentID == document && browser.preview.isDirty)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel], [false, true])
    func dirtyChoicesAndMoveFailurePreserveTheCorrectBaseline(choice: BrowserState.UnsavedChoice, fails: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source, move: { operation in
            if fails { return await operation.move(using: { _, _ in throw POSIXError(.EACCES) }) }
            return await operation.move()
        }, confirmChanges: { _, answer in answer(choice) })
        try await fixture.prepare(browser, selecting: source, dirty: true)
        let outcome = await browser.moveToOtherPane(from: .left)
        if choice == .cancel || fails {
            #expect(outcome?.succeeded != true)
            #expect(try Data(contentsOf: source) == Data((choice == .save ? "draft" : "original").utf8))
            #expect(browser.preview.isDirty == (choice != .save))
            #expect(browser.preview.text == "draft" && browser.preview.canEdit)
            #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
        } else {
            #expect(outcome?.succeeded == true && browser.preview.selection == nil)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test(arguments: [false, true])
    func failedSaveOrPreflightAbortsBeforeMutation(preflight: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        if preflight { try Data("winner".utf8).write(to: fixture.destination.appendingPathComponent("source.txt")) }
        let preview = PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) })
        var dirtyPrompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, preview: preview,
                                   confirmChanges: { _, answer in dirtyPrompts += 1; answer(.save) })
        try await fixture.prepare(browser, selecting: source, dirty: true)
        #expect(await browser.moveToOtherPane(from: .left)?.succeeded != true)
        #expect(dirtyPrompts == (preflight ? 0 : 1))
        #expect(preview.isDirty && preview.canEdit && preview.text == "draft")
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test func capturesTargetsWhileRejectingDuplicateAndConflictingMutations() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        try await withOperationGate { gate in
            let browser = BrowserState(homeDirectory: fixture.source, move: { operation in
                do {
                    try await gate.pause()
                    return await operation.move()
                } catch {
                    return ItemMove.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
                }
            })
            try await fixture.prepare(browser, selecting: source)
            let moving = Task { await browser.moveToOtherPane(from: .left) }
            gate.track(moving)
            try await gate.waitForRequest()
            try #require(browser.isMoving)
            #expect(!browser.canMove(in: .left) && !browser.canCopy(in: .left) && !browser.canRename())
            #expect(!browser.preview.canEdit)
            browser.beginCreation(.folder)
            #expect(browser.creationRequest == nil)
            #expect(await browser.moveToOtherPane(from: .left) == nil)
            await browser.navigate(to: fixture.root, in: .right)
            let navigation = browser.right.listingRevision
            browser.setMode(.onePane)
            try await gate.finish()
            #expect(await moving.value?.succeeded == true)
            #expect(browser.right.directory == fixture.root && browser.right.listingRevision == navigation)
            #expect(browser.mode == .onePane && browser.focusedPane == .right)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data("original".utf8))
            #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("source.txt").path))
        }
    }

    @Test func rejectsSingleModeAndStaleMenuRequests() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("b.txt")
        let browser = BrowserState(homeDirectory: fixture.source)
        try await fixture.prepare(browser, selecting: first)
        #expect(browser.canMove(in: .left))
        browser.select([first, second], in: .left)
        #expect(browser.canMove(in: .left))
        #expect(await browser.moveToOtherPane(from: .left, items: [first]) == nil)
        browser.select([second], in: .left)
        #expect(await browser.moveToOtherPane(from: .left, items: [first]) == nil)
        browser.setMode(.onePane)
        #expect(!browser.canMove(in: .left))
        #expect(await browser.moveToOtherPane(from: .left) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func folderMoveFollowsAnInFlightBrowsersLocationEvenWhenRefreshFails() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let child = try fixture.file("folder/child.txt")
        let folder = child.deletingLastPathComponent()
        try await withOperationGate { gate in
            let relocated = fixture.destination.appendingPathComponent("folder", isDirectory: true)
            let browser = BrowserState(homeDirectory: fixture.source, load: { directory in
                if FileManager.default.fileExists(atPath: relocated.path) { throw POSIXError(.EACCES) }
                return try await DirectoryListing.read(directory)
            }, move: { operation in
                do {
                    try await gate.pause()
                    return await operation.move()
                } catch {
                    return ItemMove.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
                }
            })
            try await fixture.prepare(browser, selecting: folder)
            let moving = Task { await browser.moveToOtherPane(from: .left) }
            gate.track(moving)
            try await gate.waitForRequest()
            try #require(browser.isMoving)
            await browser.navigate(to: folder, in: .left)
            browser.select([child], in: .left)
            await browser.preview.load(browser.detailsSelection)
            try await gate.finish()
            let outcome = await moving.value
            #expect(outcome?.succeeded == true && outcome?.message.contains("refresh") == true)
            #expect(browser.left.directory == relocated && browser.left.primaryItemURL == relocated.appendingPathComponent("child.txt"))
            #expect(browser.preview.selection == nil && !browser.preview.canEdit)
            await browser.preview.load(browser.detailsSelection)
            browser.preview.setMode(.edit)
            await browser.preview.updateText("new path")?.value
            #expect(await browser.preview.save())
            #expect((try? Data(contentsOf: relocated.appendingPathComponent("child.txt"))) == Data("new path".utf8))
            #expect(!FileManager.default.fileExists(atPath: child.path))
        }
    }

    @Test func successfulMovePrunesTheOldCachedRowWhenRefreshFails() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let moved = fixture.destination.appendingPathComponent("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source, load: { directory in
            if FileManager.default.fileExists(atPath: moved.path) { throw POSIXError(.EACCES) }
            return try await DirectoryListing.read(directory)
        })
        try await fixture.prepare(browser, selecting: source)
        let result = await browser.moveToOtherPane(from: .left)
        #expect(result?.succeeded == true && result?.message.contains("refresh") == true)
        #expect(browser.left.entries.isEmpty && browser.left.selectedItems.isEmpty && browser.preview.selection == nil)
        #expect(browser.right.entries.map(\.url) == [moved])
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel])
    func movingAContainingFolderResolvesItsDirtyChild(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let child = try fixture.file("folder/child.txt")
        let folder = child.deletingLastPathComponent()
        let browser = BrowserState(homeDirectory: fixture.source,
                                   confirmChanges: { _, answer in answer(choice) })
        try await fixture.prepare(browser, selecting: folder)
        let entry = try #require(try await DirectoryListing.read(folder).entries.first)
        await browser.preview.load(DetailsSelection(item: entry, listingRevision: UUID()))
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        let outcome = await browser.moveToOtherPane(from: .left)
        if choice == .cancel {
            #expect(outcome == nil && browser.preview.isDirty && browser.preview.canEdit)
            #expect(try Data(contentsOf: child) == Data("original".utf8))
        } else {
            #expect(outcome?.succeeded == true && browser.preview.selection == nil)
            let moved = fixture.destination.appendingPathComponent("folder/child.txt")
            #expect((try? Data(contentsOf: moved)) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test func anUnrelatedDraftRemainsEditableAndSurvivesRefresh() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let unrelated = fixture.destination.appendingPathComponent("unrelated.txt")
        try Data("other".utf8).write(to: unrelated)
        try await withOperationGate { gate in
            let browser = BrowserState(homeDirectory: fixture.source, move: { operation in
                do {
                    try await gate.pause()
                    return await operation.move()
                } catch {
                    return ItemMove.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
                }
            })
            try await fixture.prepare(browser, selecting: source)
            browser.select([unrelated], in: .right)
            await browser.preview.load(browser.detailsSelection)
            browser.preview.setMode(.edit)
            await browser.preview.updateText("unrelated draft")?.value
            let moving = Task { await browser.moveToOtherPane(from: .left) }
            gate.track(moving)
            try await gate.waitForRequest()
            try #require(browser.isMoving)
            #expect(browser.preview.canEdit)
            try await gate.finish()
            #expect(await moving.value?.succeeded == true)
            #expect(browser.preview.isDirty && browser.preview.text == "unrelated draft" && browser.preview.canEdit)
            #expect(try Data(contentsOf: unrelated) == Data("other".utf8))
        }
    }

    @Test func pendingFolderNavigationCannotPublishItsOldLocationAfterMove() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let child = try fixture.file("folder/child.txt")
        let folder = child.deletingLastPathComponent()
        let relocated = fixture.destination.appendingPathComponent("folder")
        try await withOperationGates { readGate, gate in
            let reads = PendingMoveRead(directory: folder, gate: readGate)
            let browser = BrowserState(homeDirectory: fixture.source, load: { directory in
                if FileManager.default.fileExists(atPath: relocated.path) { throw POSIXError(.EACCES) }
                return try await reads.read(directory)
            }, move: { operation in
                do {
                    try await gate.pause()
                    return await operation.move()
                } catch {
                    return ItemMove.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
                }
            })
            try await fixture.prepare(browser, selecting: folder)
            let moving = Task { await browser.moveToOtherPane(from: .left) }
            gate.track(moving)
            try await gate.waitForRequest()
            try #require(browser.isMoving)
            let navigation = Task { await browser.navigate(to: folder, in: .left) }
            readGate.track(navigation)
            try await reads.waitForRequest()
            try await gate.finish()
            #expect(await moving.value?.relocated.count == 1)
            try await reads.finish()
            await navigation.value
            #expect(browser.left.directory == fixture.source && browser.left.entries.isEmpty)
            #expect(browser.left.errorMessage?.contains(relocated.path) == true)
        }
    }
}

@MainActor func waitForMove(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
}

private actor PendingMoveRead {
    let directory: URL
    private var paused = false
    private let gate: OperationGate
    init(directory: URL, gate: OperationGate) {
        self.directory = directory
        self.gate = gate
    }
    func read(_ url: URL) async throws -> DirectoryListing {
        let listing = try await DirectoryListing.read(url)
        if url.path == directory.path, !paused {
            paused = true
            try await gate.pause()
        }
        return listing
    }
    func waitForRequest() async throws { try await gate.waitForRequest() }
    func finish() async throws { try await gate.finish() }
}

struct MoveFixture: Sendable {
    let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
    var source: URL { root.appendingPathComponent("source", isDirectory: true) }
    var destination: URL { root.appendingPathComponent("destination", isDirectory: true) }
    init() throws {
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
    }
    func file(_ name: String) throws -> URL {
        let url = source.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("original".utf8).write(to: url)
        return url
    }
    func identity(_ url: URL) throws -> ino_t {
        var attributes = stat()
        guard lstat(url.path, &attributes) == 0 else { throw POSIXError(.ENOENT) }
        return attributes.st_ino
    }
    func rename(crossVolume: Bool) -> @Sendable (URL, URL) throws -> Void {
        { source, destination in
            if crossVolume, source.deletingLastPathComponent() == self.source { throw POSIXError(.EXDEV) }
            try ItemMove.exclusiveRename(source, destination)
        }
    }
    @MainActor func prepare(_ browser: BrowserState, selecting source: URL, dirty: Bool = false) async throws {
        await browser.left.refresh()
        await browser.right.navigate(to: destination)
        browser.select([source], in: .left)
        await browser.preview.load(browser.detailsSelection)
        if dirty {
            browser.preview.setMode(.edit)
            await browser.preview.updateText("draft")?.value
        }
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
