import Foundation
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1))) @MainActor
struct DirectoryHistoryTests {
    private let root = URL(fileURLWithPath: "/history", isDirectory: true)

    private func pane() -> DirectoryPane {
        DirectoryPane(directory: root, resolveBeforeLoading: false, load: { .init(directory: $0, entries: []) })
    }

    @Test func firstLoadSeedsHistoryAndTraversalDoesNotCreateVisits() async {
        let pane = pane()
        let a = root.appendingPathComponent("a", isDirectory: true)
        let b = root.appendingPathComponent("b", isDirectory: true)
        let c = root.appendingPathComponent("c", isDirectory: true)
        #expect(!pane.canGoBack && !pane.canGoForward)
        await pane.navigate(to: a)
        #expect(!pane.canGoBack && !pane.canGoForward)
        await pane.navigate(to: b)
        await pane.navigate(to: c)
        #expect(pane.canGoBack && !pane.canGoForward)
        await pane.goBack()
        #expect(pane.directory == b && pane.canGoBack && pane.canGoForward)
        await pane.goBack()
        #expect(pane.directory == a && !pane.canGoBack && pane.canGoForward)
        await pane.goBack()
        #expect(pane.directory == a)
        await pane.goForward()
        await pane.goForward()
        #expect(pane.directory == c && pane.canGoBack && !pane.canGoForward)
    }

    @Test func refreshAndRepeatedVisitsKeepForwardUntilANewDestinationPublishes() async {
        let pane = pane()
        let a = root.appendingPathComponent("a", isDirectory: true)
        let b = root.appendingPathComponent("b", isDirectory: true)
        let c = root.appendingPathComponent("c", isDirectory: true)
        await pane.navigate(to: a)
        await pane.navigate(to: b)
        await pane.goBack()
        await pane.refresh()
        await pane.navigate(toPath: a.path)
        #expect(pane.directory == a && !pane.canGoBack && pane.canGoForward)
        let published = await pane.navigate(to: c, using: { .init(directory: $0, entries: []) })
        #expect(published && pane.directory == c && !pane.canGoForward)
        await pane.goBack()
        #expect(pane.directory == a && !pane.canGoBack)
        await pane.goForward()
        #expect(pane.directory == c)
    }

    @Test func historiesFollowRetainedBrowsersThroughLayoutAndRemainWindowLocal() async {
        let browser = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: []) })
        let otherWindow = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: []) })
        for id in [PaneID.left, .right] {
            let pane = browser.pane(id)
            await pane.navigate(to: root)
            await pane.navigate(to: root.appendingPathComponent(id == .left ? "left" : "right"))
        }
        browser.focus(.right)
        browser.setMode(.onePane)
        await browser.commandPane.goBack()
        #expect(browser.right.directory == root && browser.right.canGoForward)
        #expect(browser.left.directory.lastPathComponent == "left" && browser.left.canGoBack)
        browser.setMode(.twoPanes)
        #expect(browser.presentationOrder == [.right, .left])
        await browser.left.goBack()
        await browser.right.goForward()
        #expect(browser.left.directory == root && browser.left.canGoForward)
        #expect(browser.right.directory.lastPathComponent == "right" && !browser.right.canGoForward)
        #expect(!otherWindow.left.canGoBack && !otherWindow.right.canGoForward)
    }

    @Test func failedAndCancelledTraversalKeepsLocationSelectionAndHistory() async throws {
        let a = root.appendingPathComponent("a", isDirectory: true)
        let b = root.appendingPathComponent("b", isDirectory: true)
        let item = DirectoryEntry(url: b.appendingPathComponent("kept.txt"), isDirectory: false)
        for cancelled in [false, true] {
            let pane = DirectoryPane(directory: root, resolveBeforeLoading: false, load: { _ in
                if cancelled { throw CancellationError() }
                throw CocoaError(.fileReadNoSuchFile)
            })
            await pane.navigate(to: a, using: { .init(directory: $0, entries: []) })
            await pane.navigate(to: b, using: { .init(directory: $0, entries: [item]) })
            pane.setSelection([item.url])
            let revision = pane.listingRevision
            await pane.goBack()
            #expect(pane.directory == b && pane.selectedItems == [item.url])
            #expect(pane.listingRevision == revision && !pane.isLoading)
            #expect(pane.canGoBack && !pane.canGoForward)
            #expect((pane.errorMessage == nil) == cancelled)
        }
    }

    @Test(arguments: [false, true])
    func supersededHistoryCannotReplaceANewerVisitOrPruneItsBranch(olderFails: Bool) async throws {
        try await withTestRequestGate(of: URL.self, returning: DirectoryListing.self) { gate in
            let pane = DirectoryPane(directory: root, resolveBeforeLoading: false, load: { try await gate.request($0) })
            let a = root.appendingPathComponent("a", isDirectory: true)
            let b = root.appendingPathComponent("b", isDirectory: true)
            let c = root.appendingPathComponent("c", isDirectory: true)
            for directory in [a, b] { await pane.navigate(to: directory, using: { .init(directory: $0, entries: []) }) }
            let back = Task { await pane.goBack() }
            gate.track(back)
            #expect(try await gate.waitForRequest(0) == a)
            await pane.navigate(to: c, using: { .init(directory: $0, entries: []) })
            try gate.finish(0, with: olderFails ? .failure(CocoaError(.fileReadNoPermission)) : .success(.init(directory: a, entries: [])))
            await back.value
            #expect(pane.directory == c && !pane.canGoForward && pane.errorMessage == nil)
            let next = Task { await pane.goBack() }
            gate.track(next)
            #expect(try await gate.waitForRequest(1) == b)
            try gate.finish(1, with: .success(.init(directory: b, entries: [])))
            await next.value
            #expect(pane.directory == b && pane.canGoForward)
        }
    }

    @Test func sharedHistoryCapturesTheActiveBrowserBeforeScheduling() async {
        let browser = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: []) })
        for id in [PaneID.left, .right] {
            await browser.pane(id).navigate(to: root)
            await browser.pane(id).navigate(to: root.appendingPathComponent("next", isDirectory: true))
        }
        browser.focus(.right)
        let back = browser.goBack()
        browser.focus(.left)
        await back.value
        #expect(browser.right.directory == root && browser.right.canGoForward)
        #expect(browser.left.directory.lastPathComponent == "next" && browser.focusedPane == .left)
    }

    @Test(arguments: [false, true])
    func deferredDirtyDecisionKeepsTraversalIntent(discard: Bool) async throws {
        let a = root.appendingPathComponent("a", isDirectory: true)
        let b = root.appendingPathComponent("b", isDirectory: true)
        let item = DirectoryEntry(url: b.appendingPathComponent("draft.txt"), isDirectory: false)
        let preview = PreviewState(read: { _ in .text("original") })
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: $0 == b ? [item] : []) },
                                   preview: preview, confirmChanges: { _, completion in answer = completion })
        await browser.left.navigate(to: a)
        await browser.left.navigate(to: b)
        browser.select([item.url], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        await browser.goBack().value
        #expect(browser.left.directory == b && preview.isDirty && !browser.left.canGoForward)
        let complete = try #require(answer)
        complete(discard ? .discard : .cancel)
        if discard { try await waitForState { browser.left.directory == a } }
        #expect(browser.left.directory == (discard ? a : b))
        #expect(browser.left.canGoForward == discard && preview.isDirty == !discard)
        if discard {
            await browser.goForward().value
            #expect(browser.left.directory == b && !browser.left.canGoForward)
        }
    }

    @Test(arguments: [false, true])
    func newEditsDuringHistoryLoadingRetainTheTraversalThroughItsDecision(discard: Bool) async throws {
        try await withTestRequestGate(of: URL.self, returning: DirectoryListing.self) { gate in
            let a = root.appendingPathComponent("a", isDirectory: true)
            let b = root.appendingPathComponent("b", isDirectory: true)
            let item = DirectoryEntry(url: b.appendingPathComponent("draft.txt"), isDirectory: false)
            let preview = PreviewState(read: { _ in .text("original") })
            let browser = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: []) },
                                       loadHistory: { try await gate.request($0) }, preview: preview,
                                       confirmChanges: { _, answer in answer(discard ? .discard : .cancel) })
            await browser.left.navigate(to: a, using: { .init(directory: $0, entries: []) })
            await browser.left.navigate(to: b, using: { .init(directory: $0, entries: [item]) })
            browser.select([item.url], in: .left)
            await preview.load(browser.detailsSelection)
            let pending = browser.goBack()
            gate.track(pending)
            #expect(try await gate.waitForRequest(0) == a)
            preview.setMode(.edit)
            await preview.updateText("new draft")?.value
            try gate.finish(0, with: .success(.init(directory: a, entries: [])))
            await pending.value
            if discard {
                #expect(try await gate.waitForRequest(1) == a)
                try gate.finish(1, with: .success(.init(directory: a, entries: [])))
                try await waitForState { browser.left.directory == a }
                #expect(!browser.left.canGoBack && browser.left.canGoForward && !preview.isDirty)
            } else {
                #expect(browser.left.directory == b && browser.left.selectedItems == [item.url])
                #expect(browser.left.canGoBack && !browser.left.canGoForward && !browser.left.isLoading)
                #expect(preview.isDirty && preview.text == "new draft")
            }
        }
    }

    @Test func canonicalAliasesAndRestorationSeedOnlySuccessfulLocations() async throws {
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-history-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let a = fixture.appendingPathComponent("a", isDirectory: true)
        let b = fixture.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: false)
        let alias = fixture.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: a)
        let browser = BrowserState(homeDirectory: fixture)
        await browser.start(leftDirectory: a, rightDirectory: b, mode: .twoPanes, order: [.left, .right], active: .left)
        #expect(!browser.left.canGoBack && !browser.right.canGoBack)
        await browser.left.navigate(to: alias)
        #expect(!browser.left.canGoBack)
        await browser.left.navigate(to: b)
        await browser.left.goBack()
        #expect(browser.left.directory.path == a.resolvingSymlinksInPath().path && !browser.left.canGoBack)
        let restored = BrowserState(homeDirectory: fixture)
        await restored.start(leftDirectory: b, rightDirectory: a, mode: .twoPanes, order: [.left, .right], active: .left)
        #expect(!restored.left.canGoBack && !restored.left.canGoForward)
    }


    @Test(arguments: [false, true])
    func saveMustSucceedBeforeHistoryMoves(fails: Bool) async throws {
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-history-save-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let a = fixture.appendingPathComponent("a", isDirectory: true)
        let b = fixture.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: false)
        let file = b.appendingPathComponent("draft.txt")
        try Data("original".utf8).write(to: file)
        let preview = PreviewState(write: { snapshot, text, url in
            if fails { throw CocoaError(.fileWriteNoPermission) }
            return try await snapshot.save(text, to: url)
        })
        let browser = BrowserState(homeDirectory: fixture, preview: preview, confirmChanges: { _, answer in answer(.save) })
        await browser.left.navigate(to: a)
        await browser.left.navigate(to: b)
        browser.select([file], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("saved draft")?.value
        await browser.goBack().value
        try await waitForState { browser.left.directory.path == a.resolvingSymlinksInPath().path || preview.errorMessage != nil }
        #expect(preview.isDirty == fails && browser.left.canGoForward == !fails)
        #expect(browser.left.directory.path == (fails ? b : a).resolvingSymlinksInPath().path)
        #expect(try String(contentsOf: file, encoding: .utf8) == (fails ? "original" : "saved draft"))
        if !fails {
            await browser.goForward().value
            #expect(browser.left.directory.path == b.resolvingSymlinksInPath().path && !browser.left.canGoForward)
        }
    }

}
