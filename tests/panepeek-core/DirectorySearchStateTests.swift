import Foundation
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1))) @MainActor
struct DirectorySearchStateTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-query-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
        for name in ["alpha.txt", "beta.txt", "nested/alpha.txt", "nested/ALPHA notes.txt", ".alpha.txt"] {
            try Data("original".utf8).write(to: root.appendingPathComponent(name))
        }
        return root
    }

    @Test func queriesFollowBrowserIdentityAndRetainSortingVisibilityAndNavigation() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let browser = BrowserState(homeDirectory: root)
        let other = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        await browser.right.refresh()
        #expect(browser.search("alpha", in: .left))
        await browser.left.waitForSearch()
        #expect(browser.left.entries.count == 3 && browser.right.entries.count == 3)
        #expect(other.left.searchQuery.isEmpty)
        #expect(browser.left.entries.contains { browser.left.relativeSearchPath(for: $0) == "nested/alpha.txt" })
        browser.left.selectAll()
        #expect(browser.left.selectedItems.count == 3)
        #expect(browser.left.copiedPaths(relative: true).contains("nested/alpha.txt"))
        await browser.left.sort(by: .name, direction: .descending)
        #expect(browser.left.entries.first?.name == "alpha.txt")
        browser.left.showHiddenFiles = true
        await browser.left.waitForSearch()
        #expect(browser.left.entries.count == 4)
        browser.focus(.right)
        browser.setMode(.onePane)
        browser.setMode(.twoPanes)
        #expect(browser.left.searchQuery == "alpha" && browser.right.searchQuery.isEmpty)
        await browser.left.navigate(to: root.appendingPathComponent("nested"))
        await browser.left.waitForSearch()
        #expect(browser.left.searchQuery == "alpha" && browser.left.entries.count == 2)
        await browser.left.goBack()
        await browser.left.waitForSearch()
        #expect(browser.left.directory.path == root.path && browser.left.entries.count == 4)
        #expect(browser.left.setSearchQuery(""))
        #expect(!browser.left.isSearching && browser.left.entries.count == 4)
        #expect(browser.left.selectedItems.isEmpty)
    }

    @Test(arguments: [false, true])
    func dirtyFilteringPublishesOnlyAfterAcceptedDecision(discard: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let preview = PreviewState(read: { _ in .text("original") })
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: root, preview: preview, confirmChanges: { _, completion in answer = completion })
        await browser.left.refresh()
        let item = root.appendingPathComponent("alpha.txt")
        browser.select([item], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        let document = preview.documentID
        #expect(!browser.search("beta", in: .left))
        #expect(browser.left.searchQuery.isEmpty && browser.left.primaryItemURL == item)
        let complete = try #require(answer)
        complete(discard ? .discard : .cancel)
        await browser.left.waitForSearch()
        #expect(browser.left.searchQuery == (discard ? "beta" : ""))
        #expect(preview.isDirty == !discard)
        if !discard { #expect(preview.documentID == document && preview.text == "draft") }
        #expect(discard ? browser.left.primaryItemURL == nil : browser.left.primaryItemURL == item)
    }

    @Test func containingFolderRevealsNestedResultAndClearDoesNotResurrectSelection() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let browser = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        browser.search("alpha", in: .left)
        await browser.left.waitForSearch()
        let result = root.appendingPathComponent("nested/alpha.txt")
        #expect(browser.select([result], in: .left))
        #expect(browser.detailsSelection?.item.url == result)
        await browser.openContainingFolder(of: result, in: .left)
        #expect(browser.left.directory == result.deletingLastPathComponent())
        #expect(browser.left.searchQuery.isEmpty && browser.left.primaryItemURL == result)
        browser.search("notes", in: .left)
        await browser.left.waitForSearch()
        browser.search("", in: .left)
        #expect(browser.left.selectedItems.isEmpty)
    }

    @Test func lateSearchCannotReplaceNewQueryOrNavigation() async throws {
        try await withTestRequestGate(of: String.self, returning: DirectorySearch.Result.self) { gate in
            let root = URL(fileURLWithPath: "/query", isDirectory: true)
            let pane = DirectoryPane(directory: root, resolveBeforeLoading: false,
                load: { .init(directory: $0, entries: []) }, search: { _, query, _ in try await gate.request(query) })
            await pane.refresh()
            pane.setSearchQuery("old")
            let first = Task { await pane.waitForSearch() }
            gate.track(first)
            #expect(try await gate.waitForRequest(0) == "old")
            pane.setSearchQuery("new")
            #expect(try await gate.waitForRequest(1) == "new")
            try gate.finish(1, with: .success(.init(entries: [DirectoryEntry(url: root.appendingPathComponent("new.txt"), isDirectory: false)])))
            await pane.waitForSearch()
            try gate.finish(0, with: .success(.init(entries: [DirectoryEntry(url: root.appendingPathComponent("old.txt"), isDirectory: false)])))
            await first.value
            #expect(pane.searchQuery == "new" && pane.entries.map(\.name) == ["new.txt"])
            await pane.navigate(to: root.appendingPathComponent("other"))
            #expect(try await gate.waitForRequest(2) == "new")
            pane.setSearchQuery("")
            try gate.finish(2, with: .success(.init(entries: [DirectoryEntry(url: root.appendingPathComponent("new.txt"), isDirectory: false)])))
            #expect(pane.searchQuery.isEmpty && pane.entries.isEmpty)
        }
    }

    @Test func deferredDirtyQueryCannotOverwriteLaterIntent() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let preview = PreviewState(read: { _ in .text("original") })
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: root, preview: preview, confirmChanges: { _, completion in answer = completion })
        await browser.left.refresh()
        browser.select([root.appendingPathComponent("alpha.txt")], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        browser.search("beta", in: .left)
        #expect(browser.search("alpha", in: .left))
        let complete = try #require(answer)
        complete(.discard)
        await browser.left.waitForSearch()
        #expect(browser.left.searchQuery == "alpha")
    }
    @Test(arguments: [false, true])
    func saveMustSucceedBeforeQueryChanges(fails: Bool) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("alpha.txt")
        let preview = PreviewState(write: { snapshot, text, url in
            if fails { throw CocoaError(.fileWriteNoPermission) }
            return try await snapshot.save(text, to: url)
        })
        let browser = BrowserState(homeDirectory: root, preview: preview, confirmChanges: { _, answer in answer(.save) })
        await browser.left.refresh()
        browser.select([file], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("saved draft")?.value
        browser.search("beta", in: .left)
        try await waitForState { browser.left.searchQuery == "beta" || preview.errorMessage != nil }
        #expect(preview.isDirty == fails)
        #expect(browser.left.searchQuery == (fails ? "" : "beta"))
        #expect(try String(contentsOf: file, encoding: .utf8) == (fails ? "original" : "saved draft"))
        await browser.left.waitForSearch()
    }

    @Test func fileMutationsRefreshNestedMatchesAndCreationRevealsItsResult() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let recycled = root.deletingLastPathComponent().appendingPathComponent("panepeek-test-trash-\(UUID())")
        try FileManager.default.createDirectory(at: recycled, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: recycled) }
        let browser = BrowserState(homeDirectory: root, trash: { item in
            await item.trash { source in
                try FileManager.default.moveItem(at: source, to: recycled.appendingPathComponent(source.lastPathComponent))
            }
        })
        await browser.left.refresh()
        browser.search("alpha", in: .left)
        await browser.left.waitForSearch()
        let file = root.appendingPathComponent("nested/alpha.txt")
        browser.select([file], in: .left)
        await browser.beginRename()
        #expect(await browser.submitRename(named: "renamed.txt") != nil)
        await browser.left.waitForSearch()
        #expect(!browser.left.entries.contains { $0.url == file })
        #expect(browser.left.searchQuery.isEmpty && browser.left.primaryItemURL?.lastPathComponent == "renamed.txt")
        #expect(browser.left.directory.path == root.appendingPathComponent("nested").path)
        await browser.left.navigate(to: root)
        browser.search("alpha", in: .left)
        await browser.left.waitForSearch()
        let remaining = root.appendingPathComponent("nested/ALPHA notes.txt")
        browser.select([remaining], in: .left)
        await browser.moveToTrash(from: .left, items: [remaining])
        await browser.left.waitForSearch()
        #expect(!browser.left.entries.contains { $0.url == remaining })
        #expect(try String(contentsOf: recycled.appendingPathComponent(remaining.lastPathComponent), encoding: .utf8) == "original")
        browser.beginCreation(.textFile)
        await browser.submitCreation(named: "created.txt")
        #expect(browser.left.searchQuery.isEmpty)
        #expect(browser.left.primaryItemURL?.lastPathComponent == "created.txt")
        #expect(browser.left.entries.contains { $0.name == "created.txt" })
    }

}
