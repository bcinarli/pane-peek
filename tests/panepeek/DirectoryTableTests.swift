import AppKit
import SwiftUI
import Testing
@testable import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct DirectoryTableTests {
    @Test func independentColumnWidthsScrollWithTheirHeadersInANarrowPane() throws {
        let coordinator = makeTable(BrowserState())
        let table = coordinator.table
        try #require(table.tableColumns.count == 3)
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        let columns = table.tableColumns
        for (column, minimum) in zip(columns, [160.0, 72.0, 120.0]) {
            column.width = 1
            #expect(column.width >= minimum)
        }
        columns[0].width = 260
        let neighbours = columns.dropFirst().map(\.width)
        columns[0].width = 300
        #expect(columns.dropFirst().map(\.width) == neighbours)
        let widths = columns.map(\.width)
        window.setContentSize(NSSize(width: 250, height: 250))
        window.contentView?.layoutSubtreeIfNeeded()
        #expect(columns.map(\.width) == widths)
        #expect(coordinator.scroll.hasHorizontalScroller)
        #expect(table.bounds.width > coordinator.scroll.contentSize.width)
        table.scrollColumnToVisible(2)
        window.contentView?.layoutSubtreeIfNeeded()
        let header = try #require(table.headerView)
        #expect(coordinator.scroll.contentView.bounds.minX > 0)
        for index in columns.indices {
            let heading = header.convert(header.headerRect(ofColumn: index), to: window.contentView)
            let body = table.convert(table.rect(ofColumn: index), to: window.contentView)
            #expect(abs(heading.minX - body.minX) < 1)
            #expect(abs(heading.width - body.width) < 1)
        }
    }

    @Test func navigationAndUpdatesRetainOnlyTheirOwnTablesWidths() async throws {
        let directory = URL(fileURLWithPath: "/column-fixture")
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: []) })
        let left = makeTable(browser)
        let right = DirectoryTable<Text>.Coordinator(DirectoryTable(
            browser: browser, id: .right, entries: [], selection: [], renameID: nil,
            row: { entry, _, _ in Text(entry.name) }
        ))
        try #require(left.table.tableColumns.count == 3 && right.table.tableColumns.count == 3)
        let rightWidths = right.table.tableColumns.map(\.width)
        for (column, width) in zip(left.table.tableColumns, [310.0, 95.0, 180.0]) { column.width = width }
        let widths = left.table.tableColumns.map(\.width)
        await browser.left.navigate(to: directory.appendingPathComponent("child"))
        left.update(input(browser))
        left.update(input(browser))
        #expect(left.table.tableColumns.map(\.width) == widths)
        #expect(right.table.tableColumns.map(\.width) == rightWidths)
    }

    @Test func nativeHeaderClicksReuseSortPolicyAndPreserveSelection() async throws {
        let directory = URL(fileURLWithPath: "/column-fixture")
        let entries = ["a.txt", "b.txt"].map { DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false) }
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: entries) })
        await browser.left.refresh()
        browser.select([entries[0].url], in: .left)
        let coordinator = makeTable(browser)
        try #require(coordinator.table.tableColumns.count == 3)
        for (index, field, direction) in [(1, DirectorySortField.size, DirectorySortDirection.descending),
                                          (1, .size, .ascending), (2, .lastModified, .descending), (0, .name, .ascending)] {
            coordinator.table.delegate?.tableView?(coordinator.table, didClick: coordinator.table.tableColumns[index])
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while (browser.left.sortField != field || browser.left.sortDirection != direction), ContinuousClock.now < deadline {
                await Task.yield()
            }
            #expect(browser.left.sortField == field && browser.left.sortDirection == direction)
            #expect(browser.left.selectedItems == [entries[0].url])
            #expect(browser.right.sortField == .name && browser.right.sortDirection == .ascending)
        }
    }

    @Test(arguments: [0, 2])
    func scrolledLargeDirectoryCanNavigateRepeatedlyToASmallerDirectory(count: Int) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-table-\(UUID())")
        let large = root.appendingPathComponent("large")
        let small = root.appendingPathComponent("small")
        try FileManager.default.createDirectory(at: large, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: small, withIntermediateDirectories: true)
        for index in 0..<200 { try Data().write(to: large.appendingPathComponent("file-\(index).txt")) }
        for index in 0..<count { try Data().write(to: small.appendingPathComponent("small-\(index).txt")) }
        let browser = BrowserState(homeDirectory: large)
        await browser.left.refresh()
        let coordinator = makeTable(browser)
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        window.makeFirstResponder(coordinator.table)

        for _ in 0..<3 {
            coordinator.table.scrollRowToVisible(180)
            try #require(coordinator.scroll.contentView.bounds.minY > 0)
            await browser.left.navigate(to: small)
            coordinator.update(input(browser))
            window.contentView?.layoutSubtreeIfNeeded()
            #expect(coordinator.table.numberOfRows == count)
            #expect(coordinator.scroll.contentView.bounds.minX == 0)
            #expect(coordinator.scroll.documentVisibleRect.minY <= 0)
            #expect(coordinator.table.selectedRowIndexes.isEmpty)
            #expect(window.firstResponder === coordinator.table)
            if count > 0 {
                let row = try #require(coordinator.table.rowView(atRow: 0, makeIfNecessary: true))
                #expect(row.accessibilityLabel() == browser.left.entries[0].name)
                #expect(coordinator.tableView(coordinator.table, typeSelectStringFor: nil, row: 0) == browser.left.entries[0].name)
            }
            await browser.left.navigate(to: large)
            coordinator.update(input(browser))
            window.contentView?.layoutSubtreeIfNeeded()
            #expect(coordinator.table.numberOfRows == 200)
        }
    }

    @Test func staleAndNegativeRowCallbacksReturnEmptyViewsAndDefaultHeight() async {
        let directory = URL(fileURLWithPath: "/table-fixture")
        let entry = DirectoryEntry(url: directory.appendingPathComponent("a.txt"), isDirectory: false)
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: [entry]) })
        await browser.left.refresh()
        let coordinator = makeTable(browser)
        for row in [-1, 1, 200] {
            #expect(coordinator.tableView(coordinator.table, rowViewForRow: row) == nil)
            #expect(coordinator.tableView(coordinator.table, viewFor: nil, row: row) == nil)
            #expect(coordinator.tableView(coordinator.table, heightOfRow: row) == coordinator.table.rowHeight)
            #expect(coordinator.tableView(coordinator.table, typeSelectStringFor: nil, row: row) == nil)
        }
    }

    @Test func nativeKeyboardRangeAndReorderingRetainURLSelectionAndPrimary() async throws {
        let directory = URL(fileURLWithPath: "/table-fixture")
        let entries = ["a.txt", "b.txt", "c.txt"].map {
            DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false)
        }
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: entries) })
        await browser.left.navigate(to: directory)
        browser.select([entries[0].url], in: .left)
        let coordinator = makeTable(browser)
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        window.makeFirstResponder(coordinator.table)
        coordinator.table.keyDown(with: key(125, modifiers: .shift))
        #expect(browser.left.selectedItems == [entries[0].url, entries[1].url])
        #expect(browser.left.primaryItemURL == entries[1].url)
        await browser.left.sort(by: .name, direction: .descending)
        coordinator.update(input(browser))
        #expect(coordinator.table.selectedRowIndexes == IndexSet([1, 2]))
        #expect(browser.left.primaryItemURL == entries[1].url)
        #expect(coordinator.table.accessibilitySelectedRows()?.count == 2)
    }

    @Test func rejectedNativeSelectionRetainsTheDirtyDocumentAndRow() async throws {
        let directory = URL(fileURLWithPath: "/table-fixture")
        let entries = ["a.txt", "b.txt", "c.txt"].map {
            DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false)
        }
        let preview = PreviewState(read: { _ in .text("original") })
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: entries) }, preview: preview)
        await browser.left.navigate(to: directory)
        browser.select([entries[0].url], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        preview.updateText("unsaved")
        let document = preview.documentID
        let coordinator = makeTable(browser)
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        window.makeFirstResponder(coordinator.table)
        coordinator.table.keyDown(with: key(125))
        #expect(browser.left.selectedItems == [entries[0].url])
        #expect(coordinator.table.selectedRowIndexes == IndexSet(integer: 0))
        #expect(preview.documentID == document && preview.text == "unsaved" && preview.isDirty)
        coordinator.table.keyDown(with: key(125))
        coordinator.table.keyDown(with: key(125, modifiers: .shift))
        #expect(browser.left.selectedItems == [entries[0].url])
        #expect(coordinator.table.selectedRowIndexes == IndexSet(integer: 0))
    }

    @Test func keyboardContextMenuDoesNotChangeSelectionOrStartRename() {
        let table = DirectoryTableView()
        var menus = 0
        var renames = 0
        table.showItemMenu = { menus += 1 }
        table.rename = { renames += 1 }
        table.keyDown(with: key(109, modifiers: .shift))
        #expect(menus == 1 && renames == 0)
    }

    private func input(_ browser: BrowserState) -> DirectoryTable<Text> {
        DirectoryTable(browser: browser, id: .left, entries: browser.left.entries,
                       selection: browser.left.selectedItems, renameID: nil, row: { entry, _, _ in Text(entry.name) })
    }

    @Test func acceptedContextTargetMovesKeyboardFocusToItsNativeTable() async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "/table-fixture")
        let entry = DirectoryEntry(url: directory.appendingPathComponent("a.txt"), isDirectory: false)
        let browser = BrowserState(homeDirectory: directory, load: { DirectoryListing(directory: $0, entries: [entry]) })
        await browser.left.navigate(to: directory)
        await browser.right.navigate(to: directory)
        var focusList: (() -> Void)?
        let left = DirectoryTable<Text>.Coordinator(DirectoryTable(
            browser: browser, id: .left, entries: browser.left.entries,
            selection: [], renameID: nil, row: { entry, _, focus in focusList = focus; return Text(entry.name) }
        ))
        let right = DirectoryTable<Text>.Coordinator(DirectoryTable(
            browser: browser, id: .right, entries: browser.right.entries,
            selection: [], renameID: nil, row: { entry, _, _ in Text(entry.name) }
        ))
        let split = NSSplitView()
        split.isVertical = true
        split.addArrangedSubview(left.scroll)
        split.addArrangedSubview(right.scroll)
        let window = show(split)
        defer { window.orderOut(nil) }
        window.makeFirstResponder(right.table)
        _ = left.table.view(atColumn: 0, row: 0, makeIfNecessary: true)
        #expect(focusList != nil)
        browser.targetContextItem(entry.url, in: .left) { focusList?() }
        #expect(browser.focusedPane == .left)
        #expect(window.firstResponder === left.table)
    }

    @Test func recursiveResultsRetainNativeSelectionPathsAndClipboardActions() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-results-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("nested/report.txt")
        try Data("sample".utf8).write(to: file)
        let browser = BrowserState(homeDirectory: root)
        await browser.left.refresh()
        browser.search("report", in: .left)
        await browser.left.waitForSearch()
        let coordinator = makeTable(browser)
        let window = show(coordinator.scroll)
        defer { window.orderOut(nil) }
        #expect(coordinator.table.numberOfRows == 1)
        let row = try #require(coordinator.table.rowView(atRow: 0, makeIfNecessary: true))
        #expect(row.accessibilityLabel() == "nested/report.txt")
        window.makeFirstResponder(coordinator.table)
        coordinator.table.selectAll(nil)
        #expect(browser.left.selectedItems == [file] && browser.left.primaryItemURL == file)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        coordinator.table.filePasteboard = pasteboard
        coordinator.table.copy(nil)
        #expect(FileClipboard.sources(from: pasteboard)?.map(\.path) == [file.path])
        browser.search("", in: .left)
        coordinator.update(input(browser))
        #expect(browser.left.selectedItems.isEmpty && coordinator.table.selectedRowIndexes.isEmpty)
        #expect(window.firstResponder === coordinator.table)
    }

    private func makeTable(_ browser: BrowserState) -> DirectoryTable<Text>.Coordinator {
        _ = NSApplication.shared
        return DirectoryTable<Text>.Coordinator(input(browser))
    }

    private func show(_ view: NSView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 250),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }

    private func key(_ code: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        let characters = code == 125 ? "\u{F701}" : "\u{F700}"
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                               windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters,
                               isARepeat: false, keyCode: code)!
    }
}
