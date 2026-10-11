import Foundation
import Testing
@testable import PanePeekCore

@Suite @MainActor
struct BrowserLayoutTests {
    @Test(arguments: [PaneID.left, .right])
    func singleKeepsTheActiveIdentityAndTheOtherReturnsOnTheRight(active: PaneID) {
        let browser = BrowserState()
        #expect(browser.mode == .twoPanes && browser.visiblePanes == [.left, .right])
        browser.focus(active)
        for _ in 0..<4 {
            browser.setMode(.onePane)
            #expect(browser.visiblePanes == [active])
            #expect(browser.focusedPane == active)
            browser.setMode(.twoPanes)
            #expect(browser.visiblePanes == [active, active == .left ? .right : .left])
            #expect(browser.focusedPane == active)
        }
        let other: PaneID = active == .left ? .right : .left
        browser.focus(other)
        browser.setMode(.onePane)
        browser.setMode(.twoPanes)
        #expect(browser.visiblePanes == [other, active])
    }

    @Test func hiddenBrowserRetainsItsListingSelectionAndSettings() async {
        let root = URL(fileURLWithPath: "/layout", isDirectory: true)
        let browser = BrowserState(homeDirectory: root, load: { directory in
            DirectoryListing(directory: directory, entries: [
                DirectoryEntry(url: directory.appendingPathComponent("sample.txt"), isDirectory: false),
                DirectoryEntry(url: directory.appendingPathComponent(".hidden"), isDirectory: false, isHidden: true)
            ])
        })
        await browser.left.navigate(to: root.appendingPathComponent("preserved"))
        await browser.right.navigate(to: root.appendingPathComponent("visible"))
        browser.left.showHiddenFiles = true
        await browser.left.sort(by: .lastModified, direction: .descending)
        browser.left.setSelection(Set(browser.left.entries.map(\.url)), focusedItem: browser.left.entries.last?.url)
        let directory = browser.left.directory
        let entries = browser.left.entries
        let selected = browser.left.selectedItems
        let primary = browser.left.primaryItemURL
        let revision = browser.left.listingRevision
        browser.focus(.right)
        browser.setMode(.onePane)
        browser.setMode(.twoPanes)
        #expect(browser.visiblePanes == [.right, .left])
        #expect(browser.left.directory == directory && browser.left.entries == entries)
        #expect(browser.left.selectedItems == selected && browser.left.primaryItemURL == primary)
        #expect(browser.left.showHiddenFiles && browser.left.sortField == .lastModified)
        #expect(browser.left.sortDirection == .descending && browser.left.listingRevision == revision)
    }

    @Test func hiddenTargetsAreRejectedAndSharedNavigationUsesTheVisibleBrowser() async {
        let root = URL(fileURLWithPath: "/layout", isDirectory: true)
        let browser = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: []) })
        browser.focus(.right)
        browser.setMode(.onePane)
        var hiddenCompletion = false
        let focusAccepted = browser.focus(.left, then: { hiddenCompletion = true })
        let selectionAccepted = browser.select([], in: .left, then: { hiddenCompletion = true })
        #expect(!focusAccepted && !selectionAccepted)
        await browser.navigate(to: root.appendingPathComponent("hidden"), in: .left)
        #expect(!hiddenCompletion && browser.focusedPane == .right)
        #expect(browser.left.directory == root)
        #expect(browser.commandPane === browser.right)
        await browser.openFavourite(root.appendingPathComponent("favourite")).value
        #expect(browser.right.directory.lastPathComponent == "favourite")
        #expect(browser.left.directory == root)
        #expect(browser.transferDestination(from: .right) == nil)
        #expect(browser.transferDestination(from: .left) == nil)
        browser.setMode(.twoPanes)
        #expect(browser.transferDestination(from: .right) == .left)
        #expect(browser.transferDestination(from: .left) == .right)
    }

    @Test func layoutChangesRetainTheDirtyDocumentWithoutPrompting() async throws {
        let root = URL(fileURLWithPath: "/layout", isDirectory: true)
        let item = DirectoryEntry(url: root.appendingPathComponent("sample.txt"), isDirectory: false)
        let preview = PreviewState(read: { _ in .text("original") })
        var prompts = 0
        let browser = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: [item]) },
                                   preview: preview, confirmChanges: { _, _ in prompts += 1 })
        await browser.right.navigate(to: root)
        browser.select([item.url], in: .right)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        preview.updateText("dirty draft")
        let document = preview.documentID
        for _ in 0..<4 {
            browser.setMode(.onePane)
            #expect(browser.visiblePanes == [.right])
            browser.setMode(.twoPanes)
        }
        #expect(prompts == 0 && preview.documentID == document)
        #expect(preview.text == "dirty draft" && preview.isDirty && preview.mode == .edit)
        #expect(browser.primaryItem?.url == item.url && browser.focusedPane == .right)
    }
}
