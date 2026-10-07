import Foundation
import Testing
@testable import PanePeekCore

struct SelectionTests {
    @Test @MainActor func primaryFollowsInteractionAndSelectionStaysPaneLocal() async {
        let directory = URL(fileURLWithPath: "/selection", isDirectory: true)
        let entries = ["file2.txt", "file10.txt", ".hidden.txt"].map {
            DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false,
                           isHidden: $0.hasPrefix("."))
        }
        let first = entries[0].url
        let second = entries[1].url
        let browser = BrowserState(homeDirectory: directory,
                                   load: { DirectoryListing(directory: $0, entries: entries) })
        await browser.left.navigate(to: directory)
        await browser.right.navigate(to: directory)
        browser.left.setSelection([first])
        browser.right.setSelection([second])
        browser.left.setSelection([first, second], focusedItem: second)
        #expect(browser.primaryItem?.url == second)
        browser.left.setSelection([first, second], focusedItem: first)
        #expect(browser.primaryItem?.url == first)

        // A bulk selection keeps its primary and includes only visible rows.
        browser.left.setSelection([first])
        browser.left.selectAll()
        #expect(browser.left.selectedItems == [first, second])
        #expect(browser.left.primaryItemURL == first)
        browser.left.setSelection([second])
        #expect(browser.left.primaryItemURL == second)
        browser.left.setSelection([])
        #expect(browser.primaryItem == nil)
        browser.focus(.right)
        #expect(browser.primaryItem?.url == second)
        #expect(browser.right.selectedItems == [second])

        browser.left.selectAll()
        #expect(browser.left.primaryItemURL == first)
        #expect(browser.primaryItem?.url == second)
    }

    @Test @MainActor func selectionSurvivesSortAndRefreshButDropsUnavailableRows() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-selection-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("file2.txt")
        let second = root.appendingPathComponent("file10.txt")
        let hidden = root.appendingPathComponent(".hidden.txt")
        for url in [first, second, hidden] { try Data("fixture".utf8).write(to: url) }
        let pane = DirectoryPane(directory: root)
        await pane.navigate(to: root)
        pane.showHiddenFiles = true
        pane.setSelection([first, second, hidden], focusedItem: hidden)
        await pane.sort(by: .name, direction: .descending)
        #expect(pane.selectedItems == [first, second, hidden])
        #expect(pane.primaryItemURL == hidden)
        pane.showHiddenFiles = false
        #expect(pane.selectedItems == [first, second])
        #expect(pane.primaryItemURL == second)
        pane.showHiddenFiles = true
        #expect(!pane.selectedItems.contains(hidden))

        try Data("changed".utf8).write(to: first)
        await pane.refresh()
        #expect(pane.selectedItems == [first, second])
        #expect(pane.primaryItemURL == second)
        try FileManager.default.removeItem(at: second)
        await pane.refresh()
        #expect(pane.selectedItems == [first])
        #expect(pane.primaryItemURL == first)

        let empty = root.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: false)
        await pane.navigate(to: empty)
        #expect(pane.selectedItems.isEmpty)
        #expect(pane.primaryItem == nil)
    }
}
