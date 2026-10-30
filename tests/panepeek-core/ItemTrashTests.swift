import Darwin
import Foundation
import Testing
@testable import PanePeekCore

@Suite struct ItemTrashTests {
    @Test(arguments: ["file", "folder", "package", "link", "broken-link", "directory-link"])
    func preservesContentsAndTrashesTheListedLink(kind: String) async throws {
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
        let request = try await ItemTrash.capture(source)
        let trashed = fixture.destination.appendingPathComponent(source.lastPathComponent)
        let outcome = await request.trash { try FileManager.default.moveItem(at: $0, to: trashed) }
        #expect(outcome.succeeded && outcome.sourceRemoved)
        #expect((try? fixture.identity(source)) == nil)
        #expect((try? fixture.identity(trashed)) == inode)
        if let link {
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: trashed.path)) == link)
        } else if kind == "folder" || kind == "package" {
            #expect((try? Data(contentsOf: trashed.appendingPathComponent("child.txt"))) == Data("nested".utf8))
        } else { #expect((try? Data(contentsOf: trashed)) == Data("contents 👀".utf8)) }
        #expect(try Data(contentsOf: target) == Data("original".utf8))
    }

    @Test func unavailableTrashPreservesSourceWithoutDeletionFallback() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemTrash.capture(source)
        let outcome = await request.trash { _ in throw POSIXError(.ENOTSUP) }
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(outcome.message.contains(source.path))
    }

    @Test(arguments: [false, true])
    func rejectsReplacedSourceOrParent(parent: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemTrash.capture(source)
        let replaced = parent ? fixture.source : source
        try FileManager.default.moveItem(at: replaced, to: fixture.root.appendingPathComponent("original"))
        if parent { try FileManager.default.createDirectory(at: fixture.source, withIntermediateDirectories: false) }
        try Data("replacement".utf8).write(to: source)
        let outcome = await request.trash { try FileManager.default.moveItem(at: $0, to: fixture.destination.appendingPathComponent("unexpected")) }
        #expect(!outcome.succeeded && !outcome.sourceRemoved)
        #expect(try Data(contentsOf: source) == Data("replacement".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func aFailureAfterRemovalStillReportsTheChangedSource() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let request = try await ItemTrash.capture(source)
        let result = await request.trash {
            try FileManager.default.moveItem(at: $0, to: fixture.destination.appendingPathComponent("source.txt"))
            throw POSIXError(.EIO)
        }
        #expect(!result.succeeded && result.sourceRemoved)
        #expect(result.message.contains("Inspect Trash"))
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data("original".utf8))
    }
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct BrowserTrashTests {
    @Test(arguments: [false, true])
    func unrelatedBatchTrashRetainsVisibleSnapshot(searching: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let sources = try [fixture.file("first.txt"), fixture.file("second.txt")]
        let unrelated = fixture.root.appendingPathComponent("unrelated", isDirectory: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: false)
        try Data("unchanged".utf8).write(to: unrelated.appendingPathComponent("match.txt"))
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycle($0, in: fixture) })
        await browser.left.refresh()
        await browser.right.navigate(to: unrelated)
        if searching {
            browser.right.setSearchQuery("match")
            await browser.right.waitForSearch()
        }
        // Retain the old buffer so an unnecessary rebuild cannot reuse its storage.
        let retained = browser.right.entries
        browser.select(Set(sources), in: .left)

        let result = await browser.moveToTrash(from: .left)

        #expect(result?.succeeded == true && result?.removed.count == 2)
        #expect(browser.left.entries.isEmpty && browser.left.selectedItems.isEmpty)
        #expect(browser.right.entries == retained)
        let reusedSnapshot = retained.withUnsafeBufferPointer { previous in
            browser.right.entries.withUnsafeBufferPointer { current in
                current.baseAddress == previous.baseAddress
            }
        }
        #expect(reusedSnapshot)
    }

    @Test(arguments: [PaneID.left, .right], [BrowserMode.onePane, .twoPanes])
    func trashesOneItemDirectlyAndRefreshesMatchingPanes(from: PaneID, mode: BrowserMode) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycle($0, in: fixture) })
        await browser.left.refresh(); await browser.right.refresh()
        browser.select([source], in: from)
        await browser.preview.load(browser.detailsSelection)
        browser.setMode(mode)
        #expect(browser.canTrash(in: from))
        let result = await browser.moveToTrash(from: from)
        #expect(result?.succeeded == true && browser.trashOutcome?.removed.count == 1)
        #expect(browser.left.entries.isEmpty && browser.right.entries.isEmpty)
        #expect(browser.pane(from).selectedItems.isEmpty && browser.preview.selection == nil)
        #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data("original".utf8))
    }

    @Test func dirtyCancelRetainsDraftAndSelection() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        var dirtyPrompts = 0
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycle($0, in: fixture) },
                                   confirmChanges: { _, answer in dirtyPrompts += 1; answer(.cancel) })
        try await fixture.prepare(browser, selecting: source, dirty: true)
        let document = browser.preview.documentID
        #expect(await browser.moveToTrash() == nil)
        #expect(dirtyPrompts == 1 && browser.preview.documentID == document && browser.preview.isDirty)
        #expect(browser.preview.canEdit && browser.left.selectedItems == [source])
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test(arguments: [BrowserState.UnsavedChoice.save, .discard, .cancel], [false, true])
    func dirtyChoicesRetainDraftOnFailure(choice: BrowserState.UnsavedChoice, fails: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { operation in
            if fails { return await operation.trash { _ in throw POSIXError(.EACCES) } }
            return await recycle(operation, in: fixture)
        }, confirmChanges: { _, answer in answer(choice) })
        try await fixture.prepare(browser, selecting: source, dirty: true)
        let document = browser.preview.documentID
        let result = await browser.moveToTrash()
        if choice == .cancel || fails {
            #expect(result?.succeeded != true)
            #expect(browser.preview.text == "draft" && browser.preview.canEdit)
            #expect(browser.preview.isDirty == (choice != .save))
            #expect(browser.preview.documentID == document)
            #expect(try Data(contentsOf: source) == Data((choice == .save ? "draft" : "original").utf8))
        } else {
            #expect(result?.succeeded == true && browser.preview.selection == nil)
            #expect((try? Data(contentsOf: fixture.destination.appendingPathComponent("source.txt"))) == Data((choice == .save ? "draft" : "original").utf8))
        }
    }

    @Test func failedSaveAbortsBeforeTrash() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let preview = PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) })
        let browser = BrowserState(homeDirectory: fixture.source, preview: preview, trash: { await recycle($0, in: fixture) }, confirmChanges: { _, answer in answer(.save) })
        try await fixture.prepare(browser, selecting: source, dirty: true)
        #expect(await browser.moveToTrash() == nil)
        #expect(preview.isDirty && preview.canEdit && preview.text == "draft")
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test(arguments: [false, true])
    func ancestorTrashClosesDescendantDraftAndRecoversBrowser(refreshFails: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let child = try fixture.file("folder/nested/child.txt")
        let folder = fixture.source.appendingPathComponent("folder")
        let browser = BrowserState(homeDirectory: fixture.source, load: { url in
            if refreshFails, url.path == fixture.source.path,
               !FileManager.default.fileExists(atPath: folder.path) { throw POSIXError(.EACCES) }
            return try await DirectoryListing.read(url)
        }, trash: { await recycle($0, in: fixture) },
                                   confirmChanges: { _, answer in answer(.discard) })
        await browser.left.refresh()
        await browser.right.refresh()
        await browser.right.navigate(to: child.deletingLastPathComponent())
        browser.select([child], in: .right)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit); await browser.preview.updateText("draft")?.value
        browser.left.setSelection([folder])
        let result = await browser.moveToTrash(from: .left)
        #expect(result?.succeeded == true && browser.preview.selection == nil)
        #expect(browser.left.entries.isEmpty)
        #expect(browser.right.directory.path == (refreshFails ? fixture.root.path : fixture.source.path))
        #expect(browser.right.selectedItems.isEmpty && !browser.right.isLoading)
        #expect(result?.message.contains("Browsing") == true)
        if refreshFails { #expect(result?.message.contains("Couldn’t refresh") == true) }
        else {
            await browser.right.goBack()
            #expect(browser.right.directory == fixture.source && !browser.right.canGoBack)
            await browser.right.goForward()
            #expect(browser.right.directory == fixture.source && !browser.right.canGoForward)
        }
    }

    @Test func capturesSourceAndRejectsDuplicatesDuringNavigation() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        try await withOperationGate { gate in
            let browser = BrowserState(homeDirectory: fixture.source, trash: { operation in
                do {
                    try await gate.pause()
                    return await recycle(operation, in: fixture)
                } catch {
                    return ItemTrash.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
                }
            })
            try await fixture.prepare(browser, selecting: source, dirty: true)
            // Resolve the draft before this independent navigation check.
            browser.preview.discardChanges()
            let request = Task { await browser.moveToTrash() }
            gate.track(request)
            try await gate.waitForRequest()
            try #require(browser.isTrashing)
            #expect(!browser.preview.canEdit)
            #expect(await browser.moveToTrash() == nil)
            browser.beginCreation(.textFile)
            await browser.beginRename()
            #expect(browser.creationRequest == nil && browser.renameRequest == nil)
            #expect(await browser.copyToOtherPane(from: .left) == nil)
            #expect(await browser.moveToOtherPane(from: .left) == nil)
            await browser.left.navigate(to: fixture.root)
            browser.setMode(.onePane)
            try await gate.finish()
            #expect(await request.value?.succeeded == true)
            #expect(browser.left.directory == fixture.root && browser.mode == .onePane)
        }
    }

    @Test func rejectsEmptyHiddenAndStaleSelectionRequests() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let first = try fixture.file("a.txt")
        let second = try fixture.file("b.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycle($0, in: fixture) })
        await browser.left.refresh(); await browser.right.refresh()
        browser.select([], in: .left)
        #expect(!browser.canTrash())
        #expect(await browser.moveToTrash() == nil)
        browser.select([second], in: .left)
        #expect(await browser.moveToTrash(items: [first]) == nil)
        browser.right.setSelection([first]); browser.setMode(.onePane)
        #expect(!browser.canTrash(in: .right))
        #expect(await browser.moveToTrash(from: .right) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test func unrelatedDraftSurvivesMatchingPaneRefresh() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        let dirty = try fixture.file("z.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycle($0, in: fixture) })
        await browser.left.refresh(); await browser.right.refresh()
        browser.select([dirty], in: .right)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit); await browser.preview.updateText("draft")?.value
        browser.left.setSelection([source])
        let document = browser.preview.documentID
        #expect(await browser.moveToTrash(from: .left)?.succeeded == true)
        #expect(browser.preview.isDirty && browser.preview.documentID == document && browser.preview.text == "draft")
        #expect(browser.right.selectedItems == [dirty] && browser.right.entries.map(\.name) == ["z.txt"])
    }

    @Test func aStaleListedFileCannotBecomeATrashFolder() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let source = try fixture.file("source.txt")
        let browser = BrowserState(homeDirectory: fixture.source, trash: { await recycle($0, in: fixture) })
        try await fixture.prepare(browser, selecting: source)
        try FileManager.default.moveItem(at: source, to: fixture.root.appendingPathComponent("old"))
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        #expect(await browser.moveToTrash()?.succeeded == false)
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.destination.path).isEmpty)
    }

    @Test(arguments: [false, true])
    func pendingAncestorReadsCannotRestoreTrashedPaths(unrelated: Bool) async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let child = try fixture.file("folder/child.txt")
        let folder = child.deletingLastPathComponent()
        try await withOperationGates { readGate, mutation in
            let pending = TrashReadGate(directory: unrelated ? fixture.root : folder, gate: readGate)
            let browser = BrowserState(homeDirectory: fixture.source, load: { try await pending.read($0) },
                                       trash: { operation in
                do {
                    try await mutation.pause()
                    return await recycle(operation, in: fixture)
                } catch {
                    return ItemTrash.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
                }
            })
            await browser.left.refresh(); await browser.right.refresh()
            browser.left.setSelection([folder])
            let request = Task { await browser.moveToTrash(from: .left) }
            mutation.track(request)
            try await mutation.waitForRequest()
            let navigation = Task { await browser.right.navigate(to: unrelated ? fixture.root : folder) }
            readGate.track(navigation)
            try await pending.waitForRequest()
            try await mutation.finish()
            #expect(await request.value?.succeeded == true)
            try await pending.finish()
            await navigation.value
            #expect(browser.right.directory.path == (unrelated ? fixture.root.path : fixture.source.path))
            #expect(!browser.right.isLoading)
            #expect(!browser.right.entries.contains { $0.url.path == folder.path })
        }
    }

    @Test func failedNewerNavigationRetainsAnAccessibleTrashFallback() async throws {
        let fixture = try MoveFixture()
        defer { fixture.remove() }
        let child = try fixture.file("folder/child.txt")
        let folder = child.deletingLastPathComponent()
        try await withOperationGates { pending, mutation in
            let browser = BrowserState(homeDirectory: fixture.source, load: { url in
                if url.path == fixture.destination.path {
                    try await pending.pause()
                    throw POSIXError(.EACCES)
                }
                if url.path == fixture.source.path, !FileManager.default.fileExists(atPath: folder.path) { throw POSIXError(.EACCES) }
                return try await DirectoryListing.read(url)
            }, trash: { operation in
                do {
                    try await mutation.pause()
                    return await recycle(operation, in: fixture)
                } catch {
                    return ItemTrash.Outcome(succeeded: false, sourceRemoved: false, message: error.localizedDescription)
                }
            })
            await browser.left.refresh(); await browser.right.navigate(to: folder)
            browser.left.setSelection([folder])
            let request = Task { await browser.moveToTrash(from: .left) }
            mutation.track(request)
            try await mutation.waitForRequest()
            let navigation = Task { await browser.right.navigate(to: fixture.destination) }
            pending.track(navigation)
            try await pending.waitForRequest()
            try await mutation.finish()
            let result = await request.value
            #expect(result?.succeeded == true && result?.message.contains("Browsing") == true)
            #expect(browser.right.isLoading)
            try await pending.finish(); await navigation.value
            #expect(browser.right.directory == fixture.root && !browser.right.isLoading)
            #expect(browser.right.entries.map(\.name) == ["destination", "source"])
            #expect(browser.right.errorMessage?.contains(fixture.destination.path) == true)
        }
    }
}

private func recycle(_ operation: ItemTrash, in fixture: MoveFixture) async -> ItemTrash.Outcome {
    await operation.trash { try FileManager.default.moveItem(at: $0, to: fixture.destination.appendingPathComponent($0.lastPathComponent)) }
}

private actor TrashReadGate {
    let directory: URL
    private let gate: OperationGate
    private var paused = false
    init(directory: URL, gate: OperationGate) {
        self.directory = directory
        self.gate = gate
    }
    func read(_ url: URL) async throws -> DirectoryListing {
        let result = try await DirectoryListing.read(url)
        if url.path == directory.path, !paused {
            paused = true
            try await gate.pause()
        }
        return result
    }
    func waitForRequest() async throws { try await gate.waitForRequest() }
    func finish() async throws { try await gate.finish() }
}
