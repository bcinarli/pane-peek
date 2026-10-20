import Foundation
import Synchronization
import Testing
@testable import PanePeekCore

struct DirectoryAccessTests {
    @Test @MainActor func listingRetainsItsAccessUntilThePaneCloses() async {
        let released = Mutex(0)
        let directory = URL(fileURLWithPath: "/selected-folder")
        var pane: DirectoryPane? = DirectoryPane(directory: directory, load: { url in
            DirectoryListing(directory: url, entries: [], access: DirectoryAccess(root: url) {
                released.withLock { $0 += 1 }
            })
        })
        await pane?.refresh()
        #expect(released.withLock { $0 } == 0)
        pane = nil
        #expect(released.withLock { $0 } == 1)
    }

    @Test @MainActor func failedNavigationKeepsThePreviousScope() async {
        let released = Mutex(0)
        let directory = URL(fileURLWithPath: "/selected-folder")
        var pane: DirectoryPane? = DirectoryPane(directory: directory, load: { url in
            guard url == directory else { throw CocoaError(.fileReadNoPermission) }
            return DirectoryListing(directory: url, entries: [], access: DirectoryAccess(root: url) {
                released.withLock { $0 += 1 }
            })
        })
        await pane?.refresh()
        await pane?.navigate(to: URL(fileURLWithPath: "/denied"))
        #expect(pane?.directory == directory)
        #expect(pane?.errorMessage != nil)
        #expect(released.withLock { $0 } == 0)
        pane = nil
        #expect(released.withLock { $0 } == 1)
    }
    @Test @MainActor func reviewStartupDoesNotReadAndRejectsUnintegratedActions() async {
        let reads = Mutex(0)
        let root = URL(fileURLWithPath: "/review")
        let item = DirectoryEntry(url: root.appendingPathComponent("draft.txt"), isDirectory: false)
        let browser = BrowserState(homeDirectory: root, requiresFolderAccess: true, load: { url in
            reads.withLock { $0 += 1 }
            return DirectoryListing(directory: url, entries: [item])
        })
        await browser.start(leftDirectory: root, rightDirectory: root, mode: .twoPanes, order: [.left, .right], active: .left)
        #expect(reads.withLock { $0 } == 0)
        #expect(browser.startupState == .ready)
        await browser.left.refresh()
        browser.select([item.url], in: .left)
        #expect(browser.detailsSelection == nil)
        #expect(!browser.canCreate() && !browser.canRename() && !browser.canTrash())
        #expect(!browser.canCopy(in: .left) && !browser.canMove(in: .left))
        #expect(browser.beginDrag(in: .left, items: [item.url]) == nil)
        #expect(browser.submitDrop([item.url], into: .right, operation: .copy) == nil)
        browser.beginCreation(.textFile)
        await browser.beginRename()
        #expect(browser.creationRequest == nil && browser.renameRequest == nil)
    }

    @Test @MainActor func reviewSelectionRetainsAccessAfterThePaneCloses() async throws {
        let released = Mutex(0)
        let root = URL(fileURLWithPath: "/selected-folder")
        let item = DirectoryEntry(url: root.appendingPathComponent("notes.txt"), isDirectory: false)
        let browser = BrowserState(homeDirectory: root, requiresFolderAccess: true, load: { url in
            DirectoryListing(directory: url, entries: [item], access: DirectoryAccess(root: url) {
                released.withLock { $0 += 1 }
            })
        })
        await browser.left.refresh()
        browser.select([item.url], in: .left)
        var selection = try #require(browser.detailsSelection)
        browser.left.releaseAccess()
        #expect(released.withLock { $0 } == 0)
        selection = DetailsSelection(item: selection.item, listingRevision: UUID())
        #expect(released.withLock { $0 } == 1)
        _ = selection
    }

    @Test @MainActor func cancelledPermissionKeepsTheListingWithoutAnError() async {
        let root = URL(fileURLWithPath: "/review")
        let pane = DirectoryPane(directory: root, load: { url in
            if url != root { throw CancellationError() }
            return DirectoryListing(directory: url, entries: [])
        })
        await pane.refresh()
        await pane.navigate(to: URL(fileURLWithPath: "/cancelled"))
        #expect(pane.directory == root && pane.errorMessage == nil && !pane.isLoading)
    }

}
