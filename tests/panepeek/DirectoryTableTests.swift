import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct DirectoryTableTests {
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

    private func input(_ browser: BrowserState) -> DirectoryTable<Text> {
        DirectoryTable(browser: browser, id: .left, entries: browser.left.entries,
                       selection: browser.left.selectedItems, renameID: nil, row: { entry, _ in Text(entry.name) })
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
            selection: [], renameID: nil, row: { entry, focus in focusList = focus; return Text(entry.name) }
        ))
        let right = DirectoryTable<Text>.Coordinator(DirectoryTable(
            browser: browser, id: .right, entries: browser.right.entries,
            selection: [], renameID: nil, row: { entry, _ in Text(entry.name) }
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
