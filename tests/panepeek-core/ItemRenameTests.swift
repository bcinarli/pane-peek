import Darwin
import Foundation
import Testing
@testable import PanePeekCore

struct ItemRenameTests {
    @Test func concurrentRenamesCannotReplaceTheWinningDestination() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let first = try await ItemRename.capture(fixture.file("first.txt"))
        let second = try await ItemRename.capture(fixture.file("second.txt"))
        let attempt: @Sendable (ItemRename) async -> Bool = { operation in
            do { _ = try await operation.rename(to: "winner.txt"); return true } catch { return false }
        }
        async let left = attempt(first)
        async let right = attempt(second)
        let results = await [left, right]
        #expect(results.filter { $0 }.count == 1)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("winner.txt")) == Data("original".utf8))
        let loser = results[0] ? second.source : first.source
        #expect(try Data(contentsOf: loser) == Data("original".utf8))
    }

    @Test func readOnlyParentPreservesTheSource() async throws {
        let fixture = try RenameFixture()
        defer { chmod(fixture.root.path, 0o700); fixture.remove() }
        let source = try fixture.file("original.txt")
        let operation = try await ItemRename.capture(source)
        #expect(chmod(fixture.root.path, 0o555) == 0)
        await #expect(throws: POSIXError(.EACCES)) { try await operation.rename(to: "renamed.txt") }
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("renamed.txt").path))
    }

    @Test(arguments: ["file", "folder", "package", "link", "broken-link"])
    func renamesListedItemsWithoutChangingTheirContents(kind: String) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = fixture.root.appendingPathComponent(kind == "package" ? "original.app" : "original")
        let target = try fixture.file("target.txt")
        switch kind {
        case "folder", "package":
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
            try Data("child".utf8).write(to: source.appendingPathComponent("child.txt"))
        case "link", "broken-link":
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath:
                kind == "link" ? "target.txt" : "missing.txt")
        default: try Data("original".utf8).write(to: source)
        }
        let before = try fixture.identity(source)
        let request = try await ItemRename.capture(source)
        let result = try await request.rename(to: "renamed 👀")
        #expect(result == fixture.root.appendingPathComponent("renamed 👀", isDirectory: kind == "folder" || kind == "package"))
        #expect(try fixture.identity(result) == before)
        #expect(!FileManager.default.fileExists(atPath: source.path))
        switch kind {
        case "folder", "package": #expect(try Data(contentsOf: result.appendingPathComponent("child.txt")) == Data("child".utf8))
        case "link", "broken-link":
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: result.path) == (kind == "link" ? "target.txt" : "missing.txt"))
        default: #expect(try Data(contentsOf: result) == Data("original".utf8))
        }
        #expect(try Data(contentsOf: target) == Data("original".utf8))
    }

    @Test(arguments: ["", ".", "..", "child/name", "bad\0name"])
    func invalidNamesPreserveTheSource(name: String) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let request = try await ItemRename.capture(source)
        await #expect(throws: ItemName.ValidationError.invalid) { try await request.rename(to: name) }
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test(arguments: ["file", "folder", "link", "broken-link", "hard-link"])
    func collisionsPreserveBothDirectoryEntries(kind: String) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let occupied = fixture.root.appendingPathComponent("occupied")
        switch kind {
        case "folder": try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: false)
        case "link", "broken-link":
            try FileManager.default.createSymbolicLink(atPath: occupied.path, withDestinationPath: kind == "link" ? "original.txt" : "missing")
        case "hard-link": try FileManager.default.linkItem(at: source, to: occupied)
        default: try Data("keep".utf8).write(to: occupied)
        }
        let occupiedIdentity = try fixture.identity(occupied)
        let request = try await ItemRename.capture(source)
        await #expect(throws: ItemName.ValidationError.collision) { try await request.rename(to: "occupied") }
        #expect(try fixture.identity(occupied) == occupiedIdentity)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test func caseOnlyRenameUsesTheActualFilesystemRules() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("case.txt")
        let identity = try fixture.identity(source)
        let request = try await ItemRename.capture(source)
        let result = try await request.rename(to: "CASE.txt")
        #expect(result.lastPathComponent == "CASE.txt")
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == ["CASE.txt"])
        #expect(try fixture.identity(result) == identity)
        #expect(try Data(contentsOf: result) == Data("original".utf8))
    }

    @Test func parentAliasKeepsTheListedLinkIdentity() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let directory = fixture.root.appendingPathComponent("directory", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: directory)
        let target = try fixture.file("target.txt")
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let request = try await ItemRename.capture(alias.appendingPathComponent("link"))
        #expect(request.source == link && !request.isDirectory)
        let result = try await request.rename(to: "new link")
        #expect(result == directory.appendingPathComponent("new link"))
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: result.path) == target.path)
        #expect(try Data(contentsOf: target) == Data("original".utf8))
    }

    @Test func replacedSourceIsRejected() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let request = try await ItemRename.capture(source)
        try FileManager.default.moveItem(at: source, to: fixture.root.appendingPathComponent("old.txt"))
        try Data("replacement".utf8).write(to: source)
        await #expect(throws: ItemRename.RenameError.changedSource) { try await request.rename(to: "renamed.txt") }
        #expect(try Data(contentsOf: source) == Data("replacement".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("renamed.txt").path))
    }

    @Test func exactSameNameIsANoopAndLiteralSpellingIsRetained() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let identity = try fixture.identity(source)
        let request = try await ItemRename.capture(source)
        #expect(try await request.rename(to: "original.txt") == source)
        let result = try await request.rename(to: " spaced\\name ")
        #expect(result.lastPathComponent == " spaced\\name ")
        #expect(try fixture.identity(result) == identity)
    }
}

struct BrowserRenameTests {
    @Test(arguments: [false, true]) @MainActor
    func dotfileRenameRecomputesVisibilityWhenRefreshFails(filesystemHidden: Bool) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        var source = try fixture.file(".original.txt")
        if filesystemHidden {
            var values = URLResourceValues()
            values.isHidden = true
            try source.setResourceValues(values)
        }
        let result = fixture.root.appendingPathComponent("visible.txt")
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if FileManager.default.fileExists(atPath: result.path) { throw POSIXError(.EACCES) }
            return try await DirectoryListing.read(directory)
        })
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.showHiddenFiles = true
        browser.left.setSelection([source])
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        #expect(await browser.submitRename(named: "visible.txt") == result)
        #expect(browser.left.errorMessage != nil && browser.right.errorMessage != nil)
        #expect(browser.left.entries.first?.isHidden == filesystemHidden)
        #expect(browser.right.entries.map(\.url) == (filesystemHidden ? [] : [result]))
        browser.left.showHiddenFiles = false
        #expect(browser.left.entries.map(\.url) == (filesystemHidden ? [] : [result]))
        #expect(browser.left.primaryItemURL == (filesystemHidden ? nil : result))
        #expect(try result.resourceValues(forKeys: [.isHiddenKey]).isHidden == filesystemHidden)
        #expect(try Data(contentsOf: result) == Data("original".utf8))
    }

    @Test(arguments: [DirectorySortField.name, .lastModified], [DirectorySortDirection.ascending, .descending]) @MainActor
    func renamedFallbackRetainsTheSelectedSortWhenRefreshFails(field: DirectorySortField,
                                                             direction: DirectorySortDirection) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        let other = try fixture.file("m.txt")
        let folder = fixture.root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        for url in [source, other, folder] {
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: url.path)
        }
        let result = fixture.root.appendingPathComponent("z.txt")
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if FileManager.default.fileExists(atPath: result.path) { throw POSIXError(.EACCES) }
            return try await DirectoryListing.read(directory)
        })
        await browser.left.refresh()
        await browser.right.refresh()
        await browser.left.sort(by: field, direction: direction)
        await browser.right.sort(by: .name, direction: direction == .ascending ? .descending : .ascending)
        browser.left.setSelection([source])
        browser.right.setSelection([source, other], focusedItem: other)
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        #expect(await browser.submitRename(named: "z.txt") == result)
        #expect(browser.left.errorMessage != nil && browser.right.errorMessage != nil)
        let expectedLeft = field == .name && direction == .descending ? ["folder", "z.txt", "m.txt"] : ["folder", "m.txt", "z.txt"]
        let expectedRight = direction == .ascending ? ["folder", "z.txt", "m.txt"] : ["folder", "m.txt", "z.txt"]
        #expect(browser.left.entries.map(\.name) == expectedLeft)
        #expect(browser.right.entries.map(\.name) == expectedRight)
        #expect(browser.left.sortField == field && browser.left.sortDirection == direction)
        #expect(browser.left.primaryItemURL == result)
        #expect(browser.right.selectedItems == [result, other] && browser.right.primaryItemURL == other)
    }

    @Test @MainActor func renamedFallbackIsSortedWhileLaterNavigationRemainsPending() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("a.txt")
        _ = try fixture.file("m.txt")
        let elsewhere = fixture.root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: false)
        let mutationGate = RenameGate()
        let listingGate = RenameGate()
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if directory == elsewhere {
                try await listingGate.pause()
                throw POSIXError(.EACCES)
            }
            return try await DirectoryListing.read(directory)
        }, rename: { operation, name in
            try await mutationGate.pause()
            return try await operation.rename(to: name)
        })
        await browser.left.refresh()
        await browser.right.refresh()
        await browser.right.sort(by: .name, direction: .descending)
        browser.left.setSelection([source])
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        let mutation = Task { await browser.submitRename(named: "z.txt") }
        try await mutationGate.waitForRequest()
        let navigation = Task { await browser.right.navigate(to: elsewhere) }
        try await listingGate.waitForRequest()
        await mutationGate.finish()
        await mutation.value
        #expect(browser.right.isLoading && browser.right.directory == fixture.root)
        #expect(browser.right.entries.map(\.name) == ["elsewhere", "z.txt", "m.txt"])
        await listingGate.finish()
        await navigation.value
        #expect(browser.right.errorMessage != nil && !browser.right.isLoading)
        #expect(browser.right.directory == fixture.root)
        #expect(browser.right.entries.map(\.name) == ["elsewhere", "z.txt", "m.txt"])
        #expect(browser.renameError == nil)
    }

    @Test @MainActor func navigatingIntoTheRenamedFolderFollowsItsNewPath() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let folder = fixture.root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.refresh()
        browser.left.setSelection([folder])
        await browser.beginRename()
        browser.updateRenameName("renamed")
        await browser.navigate(to: folder, in: .left)
        let destination = fixture.root.appendingPathComponent("renamed", isDirectory: true)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while browser.left.directory != destination, ContinuousClock.now < deadline { await Task.yield() }
        #expect(browser.left.directory == destination)
        #expect(browser.left.errorMessage == nil && browser.renameError == nil)
    }

    @Test @MainActor func collisionBlocksSelectionAndUnrelatedBlurCancelsOnlyTheNameEntry() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let other = try fixture.file("occupied.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.root, confirmChanges: { _, answer in prompts += 1; answer(.cancel) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.beginRename()
        browser.endRenameEditing()
        #expect(browser.renameRequest == nil && browser.preview.isDirty && browser.preview.text == "draft")
        await browser.beginRename()
        browser.updateRenameName("occupied.txt")
        var completed = false
        let selected = browser.select([other], in: .left, then: { completed = true })
        #expect(!selected)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while browser.renameError == nil || browser.isRenaming, ContinuousClock.now < deadline { await Task.yield() }
        #expect(browser.renameRequest != nil && browser.renameName == "occupied.txt")
        #expect(browser.left.primaryItemURL == source && !completed && prompts == 0)
        #expect(browser.preview.isDirty && browser.preview.text == "draft")
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test(arguments: [false, true]) @MainActor
    func inlineNameFinishesBeforeSelectionAndDirtyCancelAbortsTheTransition(cancel: Bool) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let other = try fixture.file("other.txt")
        let browser = BrowserState(homeDirectory: fixture.root, confirmChanges: { _, answer in answer(cancel ? .cancel : .discard) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.beginRename()
        _ = try #require(browser.renameRequest != nil)
        browser.updateRenameName("renamed.txt")
        var completed = false
        let selected = browser.select([other], in: .left, then: { completed = true })
        #expect(!selected)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while (cancel ? browser.renameRequest != nil || browser.isRenaming : !completed), ContinuousClock.now < deadline { await Task.yield() }
        #expect(browser.renameRequest == nil)
        if cancel {
            #expect(!completed && browser.left.primaryItemURL == source)
            #expect(browser.preview.isDirty && browser.preview.text == "draft")
            #expect(try Data(contentsOf: source) == Data("original".utf8))
        } else {
            #expect(completed && browser.left.primaryItemURL == other)
            #expect(try Data(contentsOf: fixture.root.appendingPathComponent("renamed.txt")) == Data("original".utf8))
        }
    }

    @Test @MainActor func pendingDirectoryAliasCannotPublishAnObsoleteLocationAfterRename() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let folder = fixture.root.appendingPathComponent("folder", isDirectory: true)
        let alias = fixture.root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: folder)
        let gate = RenameGate()
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            let listing = try await DirectoryListing.read(directory)
            if directory == alias { try await gate.pause() }
            return listing
        })
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.setSelection([folder])
        let pending = Task { await browser.right.navigate(to: alias) }
        try await gate.waitForRequest()
        await browser.beginRename()
        _ = try #require(browser.renameRequest != nil)
        await browser.submitRename(named: "renamed-folder")
        await gate.finish()
        await pending.value
        #expect(browser.renameError == nil)
        #expect(browser.right.directory == fixture.root.appendingPathComponent("renamed-folder", isDirectory: true))
        #expect(!browser.right.isLoading && browser.right.errorMessage == nil)
    }

    @Test @MainActor func replacementAfterSaveCannotBecomeTheRenameSource() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let preview = PreviewState(write: { snapshot, text, url in
            let saved = try await snapshot.save(text, to: url)
            try FileManager.default.moveItem(at: url, to: fixture.root.appendingPathComponent("saved.txt"))
            try Data("external replacement".utf8).write(to: url)
            return saved
        })
        let browser = BrowserState(homeDirectory: fixture.root, preview: preview, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("saved draft")?.value
        await browser.beginRename()
        _ = try #require(browser.renameRequest != nil)
        await browser.submitRename(named: "renamed.txt")
        #expect(browser.renameError != nil)
        #expect(try Data(contentsOf: source) == Data("external replacement".utf8))
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("saved.txt")) == Data("saved draft".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("renamed.txt").path))
    }

    @Test @MainActor func inFlightRenameBlocksAffectedEditsAndDuplicateMutations() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let gate = RenameGate()
        let browser = BrowserState(homeDirectory: fixture.root, rename: { operation, name in
            try await gate.pause()
            return try await operation.rename(to: name)
        }, confirmChanges: { _, answer in answer(.discard) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.beginRename()
        _ = try #require(browser.renameRequest != nil)
        let mutation = Task { await browser.submitRename(named: "renamed.txt") }
        try await gate.waitForRequest()
        #expect(browser.isRenaming && !browser.preview.canEdit)
        await browser.preview.updateText("late edit")?.value
        #expect(!(await browser.preview.save()))
        #expect(browser.preview.text == "draft" && browser.preview.isDirty)
        browser.beginCreation(.textFile)
        await browser.beginRename()
        await browser.submitRename(named: "duplicate.txt")
        #expect(browser.creationRequest == nil && browser.renameRequest == nil)
        await gate.finish()
        await mutation.value
        #expect(browser.renameError == nil && !browser.isRenaming)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("renamed.txt")) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("duplicate.txt").path))
    }

    @Test(arguments: [false, true]) @MainActor
    func folderRenameRebasesTheFallbackWithoutOverwritingLaterNavigation(navigationFails: Bool) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let folder = fixture.root.appendingPathComponent("folder", isDirectory: true)
        let elsewhere = fixture.root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: false)
        let child = folder.appendingPathComponent("child.txt")
        try Data("child".utf8).write(to: child)
        let mutationGate = RenameGate()
        let listingGate = RenameGate()
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if directory == elsewhere {
                try await listingGate.pause()
                if navigationFails { throw POSIXError(.EACCES) }
            }
            return try await DirectoryListing.read(directory)
        }, rename: { operation, name in
            try await mutationGate.pause()
            return try await operation.rename(to: name)
        })
        await browser.left.refresh()
        await browser.right.navigate(to: folder)
        browser.left.setSelection([folder])
        browser.right.setSelection([child])
        browser.setMode(.onePane)
        await browser.beginRename()
        _ = try #require(browser.renameRequest != nil)
        let mutation = Task { await browser.submitRename(named: "renamed-folder") }
        try await mutationGate.waitForRequest()
        let navigation = Task { await browser.right.navigate(to: elsewhere) }
        try await listingGate.waitForRequest()
        await mutationGate.finish()
        await mutation.value
        let result = fixture.root.appendingPathComponent("renamed-folder", isDirectory: true)
        #expect(browser.right.directory == result && browser.right.isLoading)
        #expect(browser.right.primaryItemURL == result.appendingPathComponent("child.txt"))
        await listingGate.finish()
        await navigation.value
        #expect(browser.right.directory == (navigationFails ? result : elsewhere))
        #expect(browser.focusedPane == .left && browser.mode == .onePane)
        #expect(browser.renameError == nil && !browser.isRenaming)
    }

    @Test @MainActor func successfulRenameWithFailedRefreshRetainsNewPathsAndClosesOldPreview() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let result = fixture.root.appendingPathComponent("renamed.txt")
        let browser = BrowserState(homeDirectory: fixture.root, load: { directory in
            if FileManager.default.fileExists(atPath: result.path) { throw POSIXError(.EACCES) }
            return try await DirectoryListing.read(directory)
        }, confirmChanges: { _, answer in answer(.discard) })
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.setSelection([source])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.beginRename()
        _ = try #require(browser.renameRequest != nil)
        await browser.submitRename(named: "renamed.txt")
        #expect(browser.renameError?.contains("Renamed to \(result.path)") == true)
        #expect(browser.left.primaryItemURL == result && browser.preview.selection == nil)
        #expect(!browser.preview.canEdit && !browser.preview.isDirty)
        #expect(browser.left.errorMessage != nil && browser.right.errorMessage != nil)
        #expect(try Data(contentsOf: result) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }

    @Test @MainActor func directoryLinkRenameLeavesTheCanonicalTargetBrowserAlone() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let folder = fixture.root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let link = fixture.root.appendingPathComponent("folder-link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.refresh()
        await browser.right.navigate(to: link)
        browser.left.setSelection([link])
        await browser.beginRename()
        _ = try #require(browser.renameRequest != nil)
        await browser.submitRename(named: "new-link")
        #expect(browser.renameError == nil && browser.right.directory == folder)
        #expect(browser.left.primaryItemURL?.lastPathComponent == "new-link")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.root.appendingPathComponent("new-link").path) == folder.path)
    }

    @Test(arguments: [false, true]) @MainActor
    func renamedSelectionAndMatchingPaneSettingsFollowTheResult(folder: Bool) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = folder ? fixture.root.appendingPathComponent("folder", isDirectory: true) : try fixture.file("original.txt")
        if folder { try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false) }
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.setSelection([source])
        browser.right.setSelection([source])
        browser.right.showHiddenFiles = true
        await browser.right.sort(by: .lastModified)
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        await browser.submitRename(named: "renamed")
        let result = fixture.root.appendingPathComponent("renamed", isDirectory: folder)
        #expect(browser.renameError == nil && browser.left.primaryItemURL == result)
        #expect(browser.right.primaryItemURL == result && browser.right.showHiddenFiles)
        #expect(browser.right.sortField == .lastModified && browser.focusedPane == .left)
    }

    @Test(arguments: [BrowserState.UnsavedChoice.cancel, .discard, .save]) @MainActor
    func dirtyChoicesResolveBeforeMutationAndNewPathCanBeSaved(choice: BrowserState.UnsavedChoice) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.root, confirmChanges: { _, answer in prompts += 1; answer(choice) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.beginRename()
        #expect(prompts == 0 && browser.preview.isDirty)
        _ = try #require(browser.renameRequest)
        await browser.submitRename(named: "renamed.txt")
        #expect(prompts == 1)
        if choice == .cancel {
            #expect(browser.preview.isDirty && browser.preview.text == "draft")
            #expect(browser.left.primaryItemURL == source && browser.renameRequest == nil)
            #expect(try Data(contentsOf: source) == Data("original".utf8))
        } else {
            let result = fixture.root.appendingPathComponent("renamed.txt")
            #expect(browser.renameError == nil && browser.left.primaryItemURL == result)
            #expect(try Data(contentsOf: result) == Data((choice == .save ? "draft" : "original").utf8))
            await browser.preview.load(browser.detailsSelection)
            browser.preview.setMode(.edit)
            await browser.preview.updateText("after rename")?.value
            #expect(await browser.preview.save())
            #expect(try Data(contentsOf: result) == Data("after rename".utf8))
            #expect(!FileManager.default.fileExists(atPath: source.path))
        }
    }

    @Test @MainActor func failedMutationAfterDiscardRetainsTheDraftAndDocument() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let browser = BrowserState(homeDirectory: fixture.root, rename: { _, _ in throw POSIXError(.EACCES) },
                                   confirmChanges: { _, answer in answer(.discard) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("retained draft")?.value
        let document = browser.preview.documentID
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        await browser.submitRename(named: "renamed.txt")
        #expect(browser.renameError != nil && browser.preview.isDirty && browser.preview.text == "retained draft")
        #expect(browser.preview.documentID == document && browser.preview.canEdit)
        #expect(browser.left.primaryItemURL == source && !browser.isRenaming)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test @MainActor func failedSaveAbortsRename() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        let preview = PreviewState(write: { _, _, _ in throw POSIXError(.EACCES) })
        let browser = BrowserState(homeDirectory: fixture.root, preview: preview, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        await browser.submitRename(named: "renamed.txt")
        #expect(preview.isDirty && preview.text == "draft" && preview.errorMessage != nil)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("renamed.txt").path))
    }

    @Test(arguments: ["bad/name", "occupied.txt"]) @MainActor
    func preflightRejectionPreservesDirtyBufferWithoutPrompt(name: String) async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = try fixture.file("original.txt")
        _ = try fixture.file("occupied.txt")
        var prompts = 0
        let browser = BrowserState(homeDirectory: fixture.root, confirmChanges: { _, answer in prompts += 1; answer(.discard) })
        await browser.left.refresh()
        browser.left.setSelection([source])
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("draft")?.value
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        await browser.submitRename(named: name)
        #expect(prompts == 0 && browser.preview.isDirty && browser.preview.text == "draft")
        #expect(browser.renameError != nil && browser.renameRequest != nil)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test @MainActor func folderRenameFollowsTheOtherBrowserAndGuardsItsChildDraft() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let source = fixture.root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        let child = source.appendingPathComponent("child.txt")
        try Data("child".utf8).write(to: child)
        let browser = BrowserState(homeDirectory: fixture.root, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        await browser.right.navigate(to: source)
        browser.left.setSelection([source])
        browser.right.setSelection([child])
        browser.focus(.right)
        await browser.preview.load(browser.detailsSelection)
        browser.preview.setMode(.edit)
        await browser.preview.updateText("saved child")?.value
        await browser.beginRename(in: .left)
        _ = try #require(browser.renameRequest)
        await browser.submitRename(named: "renamed-folder")
        let result = fixture.root.appendingPathComponent("renamed-folder", isDirectory: true)
        #expect(browser.renameError == nil && browser.right.directory == result)
        #expect(browser.left.primaryItemURL == result && browser.right.primaryItemURL == result.appendingPathComponent("child.txt"))
        #expect(browser.focusedPane == .right && !browser.preview.isDirty)
        await browser.preview.load(browser.detailsSelection)
        #expect(browser.preview.text == "saved child")
    }

    @Test @MainActor func onlyOneVisibleSelectedItemCanStartAndStalePromptCannotSubmit() async throws {
        let fixture = try RenameFixture()
        defer { fixture.remove() }
        let first = try fixture.file("first.txt")
        let second = try fixture.file("second.txt")
        let browser = BrowserState(homeDirectory: fixture.root)
        await browser.left.refresh()
        await browser.right.refresh()
        browser.left.setSelection([first, second])
        await browser.beginRename()
        #expect(browser.renameRequest == nil)
        browser.setMode(.onePane)
        browser.right.setSelection([first])
        await browser.beginRename(in: .right)
        #expect(browser.renameRequest == nil)
        browser.left.setSelection([first])
        #expect(browser.canRename())
        await browser.beginRename()
        _ = try #require(browser.renameRequest)
        browser.left.setSelection([second])
        await browser.submitRename(named: "stale.txt")
        #expect(browser.renameError != nil && browser.renameRequest == nil)
        #expect(try Data(contentsOf: first) == Data("original".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("stale.txt").path))
    }
}

private actor RenameGate {
    private var continuation: CheckedContinuation<Void, any Error>?
    private var timeout: Task<Void, Never>?

    func pause() async throws {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitForRequest() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while continuation == nil, ContinuousClock.now < deadline { await Task.yield() }
        guard continuation != nil else { throw POSIXError(.ETIMEDOUT) }
        timeout = Task {
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            continuation?.resume(throwing: POSIXError(.ETIMEDOUT))
            continuation = nil
        }
    }

    func finish() {
        timeout?.cancel()
        continuation?.resume()
        continuation = nil
    }
}

private struct RenameFixture: Sendable {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-rename-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    func file(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("original".utf8).write(to: url)
        return url
    }

    func identity(_ url: URL) throws -> UInt64 {
        var attributes = stat()
        guard lstat(url.path, &attributes) == 0 else { throw POSIXError(.ENOENT) }
        return attributes.st_ino
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
