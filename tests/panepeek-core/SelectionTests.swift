import Foundation
import Testing
@testable import PanePeekCore

struct SelectionTests {
    @Test func keyboardEndpointsFollowRangeReversalAndClampAtListingEdges() {
        let entries = (1...4).map {
            DirectoryEntry(url: URL(fileURLWithPath: "/selection/file\($0).txt"), isDirectory: false)
        }
        var interacted: URL? = entries[1].url
        for (movingUp, expected) in [(false, 2), (true, 1), (true, 0), (true, 0),
                                      (false, 1), (false, 2), (false, 3), (false, 3)] {
            interacted = SelectionInteraction.keyboardEndpoint(
                in: entries, interactedItem: interacted, primaryItem: entries[0].url, movingUp: movingUp
            )
            #expect(interacted == entries[expected].url)
        }
        #expect(SelectionInteraction.keyboardEndpoint(
            in: entries, interactedItem: nil, primaryItem: entries[2].url, movingUp: true
        ) == entries[1].url)
        #expect(SelectionInteraction.keyboardEndpoint(
            in: entries, interactedItem: nil, primaryItem: nil, movingUp: false
        ) == nil)
        #expect(SelectionInteraction.keyboardEndpoint(
            in: [], interactedItem: entries[0].url, primaryItem: entries[0].url, movingUp: true
        ) == nil)
        #expect(SelectionInteraction.keyboardEndpoint(
            in: entries, interactedItem: URL(fileURLWithPath: "/selection/missing.txt"),
            primaryItem: entries[0].url, movingUp: false
        ) == nil)
    }

    @Test func removedInteractionRetainsVisiblePositionBeforeTheNextRangeStep() {
        let entries = (1...4).map {
            DirectoryEntry(url: URL(fileURLWithPath: "/selection/file\($0).txt"), isDirectory: false)
        }
        for (removed, replacement, next) in [(0, 1, 1), (1, 2, 0), (3, 2, 1)] {
            let remaining = entries.filter { $0.url != entries[removed].url }
            let interacted = SelectionInteraction.reconciledItem(entries[removed].url, from: entries, to: remaining)
            #expect(interacted == entries[replacement].url)
            #expect(SelectionInteraction.keyboardEndpoint(
                in: remaining, interactedItem: interacted, primaryItem: remaining[0].url, movingUp: true
            ) == entries[next].url)
        }
        #expect(SelectionInteraction.reconciledItem(entries[1].url, from: entries, to: entries.reversed()) == entries[1].url)
        #expect(SelectionInteraction.reconciledItem(entries[0].url, from: entries, to: []) == nil)
        #expect(SelectionInteraction.reconciledItem(nil, from: entries, to: entries) == nil)
    }

    @Test @MainActor func hidingInteractedPrimaryLetsRangeShrinkFollowTheEndpoint() async throws {
        let directory = URL(fileURLWithPath: "/selection", isDirectory: true)
        let entries = ["file1.txt", "file2.txt", "file3.txt", ".hidden.txt"].map {
            DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false,
                           isHidden: $0.hasPrefix("."))
        }
        let pane = DirectoryPane(directory: directory, load: { DirectoryListing(directory: $0, entries: entries) })
        await pane.navigate(to: directory)
        await pane.sort(by: .name, direction: .descending)
        pane.showHiddenFiles = true
        let hidden = entries[3].url
        pane.setSelection([hidden])
        pane.selectAll()
        #expect(pane.primaryItemURL == hidden)
        let previous = pane.entries

        pane.showHiddenFiles = false
        #expect(pane.primaryItemURL == entries[2].url)
        let interacted = SelectionInteraction.reconciledItem(hidden, from: previous, to: pane.entries)
        #expect(interacted == entries[0].url)
        let endpoint = try #require(SelectionInteraction.keyboardEndpoint(
            in: pane.entries, interactedItem: interacted, primaryItem: pane.primaryItemURL, movingUp: true
        ))
        // Native range shrinking can leave the selected set unchanged.
        pane.setSelection(pane.selectedItems, focusedItem: endpoint)
        #expect(pane.primaryItemURL == entries[1].url)
        #expect(pane.selectedItems == Set(entries.prefix(3).map(\.url)))
    }

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
