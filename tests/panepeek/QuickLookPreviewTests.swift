import AppKit
import QuickLookUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct QuickLookPreviewTests {
    @Test func snapshotUsesDisplayedOrderAndPrimaryWithoutOpeningFiles() async {
        let browser = makeBrowser()
        await browser.left.refresh()
        let entries = browser.left.entries
        browser.select([entries[0].url, entries[2].url], in: .left, focusedItem: entries[2].url)
        let selection = QuickLookSelection(pane: browser.commandPane)
        #expect(selection.urls == [entries[0].url, entries[2].url])
        #expect(selection.primaryIndex == 1)
        await browser.left.sort(by: .name, direction: .descending)
        #expect(QuickLookSelection(pane: browser.commandPane).urls == [entries[2].url, entries[0].url])
        browser.select([], in: .left)
        #expect(QuickLookSelection(pane: browser.commandPane).urls.isEmpty)
    }

    @Test func tableRoutesBareSpaceOnceAndEscapePreservesSelection() {
        _ = NSApplication.shared
        let table = DirectoryTableView()
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let delegate = KeyPreviewDelegate()
        window.delegate = delegate
        window.contentView = table
        var publications = 0
        table.publishSelection = { publications += 1 }
        table.keyDown(with: key(49))
        table.keyDown(with: key(49, repeating: true))
        #expect(delegate.toggles == 1 && publications == 0)
        table.keyDown(with: key(53))
        #expect(delegate.closes == 1 && publications == 0)
        table.keyDown(with: key(49, modifiers: .shift))
        table.keyDown(with: key(49, modifiers: .command))
        #expect(delegate.toggles == 1)
    }

    @Test func dataSourceTracksTheLatestSelectionAndRejectsStaleIndexes() async {
        let browser = makeBrowser()
        await browser.left.refresh()
        let entries = browser.left.entries
        browser.select([entries[0].url, entries[2].url], in: .left, focusedItem: entries[2].url)
        let preview = QuickLookPreview()
        preview.update(QuickLookSelection(pane: browser.commandPane))
        #expect(preview.numberOfPreviewItems(in: nil) == 2)
        #expect(preview.previewPanel(nil, previewItemAt: 1)?.previewItemURL == entries[2].url)
        #expect(preview.previewPanel(nil, previewItemAt: -1) == nil)
        #expect(preview.previewPanel(nil, previewItemAt: 2) == nil)
        browser.select([entries[1].url], in: .left)
        preview.update(QuickLookSelection(pane: browser.commandPane))
        #expect(preview.numberOfPreviewItems(in: nil) == 1)
        #expect(preview.previewPanel(nil, previewItemAt: 0)?.previewItemURL == entries[1].url)
        browser.select([], in: .left)
        preview.update(QuickLookSelection(pane: browser.commandPane))
        #expect(preview.numberOfPreviewItems(in: nil) == 0 && preview.previewPanel(nil, previewItemAt: 0) == nil)
    }

    @Test(arguments: [false, true])
    func guardReplacementPreservesTheNewResponderAndRestoresItsPredecessor(hasPredecessor: Bool) async throws {
        _ = NSApplication.shared
        let first = makeBrowser()
        let second = makeBrowser()
        await first.left.refresh()
        await second.left.refresh()
        first.select([first.left.entries[0].url], in: .left)
        second.select([second.left.entries[2].url], in: .left)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = NSView()
        let predecessor: NSResponder? = hasPredecessor ? NSResponder() : nil
        window.nextResponder = predecessor
        let a = try PreviewWindow(first, window: window)
        defer { a.finish() }
        let oldController = try #require(window.nextResponder as? QuickLookPreview)
        #expect(oldController.nextResponder === predecessor)
        let b = try PreviewWindow(second, window: window)
        defer { b.finish() }
        let newController = try #require(window.nextResponder as? QuickLookPreview)
        #expect(newController !== oldController && newController.nextResponder === predecessor)
        #expect(newController.previewPanel(nil, previewItemAt: 0)?.previewItemURL == second.left.entries[2].url)
        a.finish()
        #expect(window.nextResponder === newController && newController.window === window)
        #expect(oldController.window == nil)
        b.finish()
        #expect(window.nextResponder === predecessor && newController.window == nil)
    }

    @Test func emptySelectionDoesNotCreateASystemPanel() {
        _ = NSApplication.shared
        let existed = QLPreviewPanel.sharedPreviewPanelExists()
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let preview = QuickLookPreview()
        preview.install(in: window)
        preview.toggle()
        #expect(!preview.close())
        #expect(QLPreviewPanel.sharedPreviewPanelExists() == existed)
        preview.stop()
    }

    private func makeBrowser() -> BrowserState {
        let root = URL(fileURLWithPath: "/quick-look-fixture", isDirectory: true)
        let entries = ["a.txt", "b.png", "c.pdf"].map {
            DirectoryEntry(url: root.appendingPathComponent($0), isDirectory: false)
        }
        return BrowserState(homeDirectory: root,
                            load: { DirectoryListing(directory: $0, entries: entries) },
                            preview: PreviewState())
    }

    private func key(_ code: UInt16, modifiers: NSEvent.ModifierFlags = [], repeating: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                         windowNumber: 0, context: nil, characters: code == 49 ? " " : "\u{1b}",
                         charactersIgnoringModifiers: code == 49 ? " " : "\u{1b}", isARepeat: repeating, keyCode: code)!
    }
}

@MainActor private final class KeyPreviewDelegate: NSObject, NSWindowDelegate, QuickLookControlling {
    var toggles = 0
    var closes = 0
    func toggleQuickLook() { toggles += 1 }
    func closeQuickLook() -> Bool { closes += 1; return true }
}

@MainActor private final class PreviewWindow {
    private let guardView = BrowserWindowGuard.GuardView()
    private let prompts = BrowserPrompts()
    private let lifecycle: BrowserLifecycle
    private let preferences: UserDefaults
    private let domain = "panepeek-quick-look-" + UUID().uuidString

    init(_ browser: BrowserState, window: NSWindow) throws {
        preferences = try #require(UserDefaults(suiteName: domain))
        lifecycle = BrowserLifecycle(preferences: preferences)
        guardView.browser = browser
        guardView.prompts = prompts
        guardView.lifecycle = lifecycle
        guardView.quickLookSelection = QuickLookSelection(pane: browser.commandPane)
        window.contentView?.addSubview(guardView)
        guardView.install()
    }

    func finish() {
        guardView.uninstall()
        guardView.removeFromSuperview()
        preferences.removePersistentDomain(forName: domain)
    }
}
