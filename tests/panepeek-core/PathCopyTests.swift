import Foundation
import Testing
@testable import PanePeekCore

struct PathCopyTests {
    @Test @MainActor func contextTargetPreservesSelectionAndChangesOnlyItsPane() async {
        let root = URL(fileURLWithPath: "/context", isDirectory: true)
        let browser = BrowserState(homeDirectory: root, load: { directory in
            DirectoryListing(directory: directory, entries: ["item1", "item2", "item3"].map {
                DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false)
            })
        })
        await browser.left.navigate(to: root.appendingPathComponent("left", isDirectory: true))
        await browser.right.navigate(to: root.appendingPathComponent("right", isDirectory: true))
        let left = browser.left.entries.map(\.url)
        let right = browser.right.entries.map(\.url)
        browser.left.setSelection([left[0], left[1]], focusedItem: left[0])
        browser.right.setSelection([right[0]])
        browser.focus(.right)

        browser.targetContextItem(left[1], in: .left)
        #expect(browser.focusedPane == .left)
        #expect(browser.left.selectedItems == [left[0], left[1]])
        #expect(browser.primaryItem?.url == left[1])
        browser.targetContextItem(left[2], in: .left)
        #expect(browser.left.selectedItems == [left[2]])
        #expect(browser.primaryItem?.url == left[2])
        #expect(browser.right.selectedItems == [right[0]])

        // A row from an obsolete listing cannot retarget the pane.
        browser.targetContextItem(right[0], in: .left)
        #expect(browser.left.selectedItems == [left[2]])
    }

    @Test @MainActor func copiedPathsFollowDisplayedOrderAndKeepPlainLinkIdentity() async throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("panepeek-paths-\(UUID())", isDirectory: true)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        let directory = root.appendingPathComponent("pane with spaces ü", isDirectory: true)
        let target = root.appendingPathComponent("targets", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: false)
        try files.createDirectory(at: target, withIntermediateDirectories: false)
        let first = directory.appendingPathComponent("item2 ü % #.txt")
        let second = directory.appendingPathComponent("item10 with space.txt")
        let fileLink = directory.appendingPathComponent("z link.txt")
        let folderLink = directory.appendingPathComponent("folder link", isDirectory: true)
        for url in [first, second] { try Data("fixture".utf8).write(to: url) }
        try files.createSymbolicLink(at: fileLink, withDestinationURL: first)
        try files.createSymbolicLink(at: folderLink, withDestinationURL: target)
        let pane = DirectoryPane(directory: directory)
        await pane.navigate(to: directory)
        pane.selectAll()

        #expect(pane.copiedPaths() == [folderLink, first, second, fileLink].map(\.path).joined(separator: "\n"))
        #expect(pane.copiedPaths(relative: true) == "folder link\nitem2 ü % #.txt\nitem10 with space.txt\nz link.txt")
        await pane.sort(by: .name, direction: .descending)
        #expect(pane.copiedPaths() == [folderLink, fileLink, second, first].map(\.path).joined(separator: "\n"))
        pane.setSelection([first, fileLink])
        #expect(pane.copiedPaths(relative: true) == "z link.txt\nitem2 ü % #.txt")
        #expect(CopiedPaths.string(for: [fileLink]) == fileLink.path)
    }
}
