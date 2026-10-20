import AppKit
import Darwin
import QuickLookUI
import Synchronization
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct QuickLookPreviewTests {
    @Test func scopedPreviewItemRetainsAccessAfterItsPaneAndControllerStop() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let released = Mutex(0)
        let browser = scopedBrowser(root) { released.withLock { $0 += 1 } }
        await browser.left.refresh()
        browser.select([root.appendingPathComponent("sample.txt")], in: .left)
        let preview = QuickLookPreview()
        preview.update(QuickLookSelection(pane: browser.commandPane))
        var item = preview.previewPanel(nil, previewItemAt: 0)
        #expect(item?.previewItemURL != nil)
        browser.left.releaseAccess()
        #expect(released.withLock { $0 } == 0)
        withExtendedLifetime(item) {
            preview.stop()
            #expect(released.withLock { $0 } == 0)
        }
        item = nil
        #expect(released.withLock { $0 } == 1)
    }

    @Test func anUnopenedSnapshotCannotExtendOrBypassReleasedAccess() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let released = Mutex(0)
        let browser = scopedBrowser(root) { released.withLock { $0 += 1 } }
        await browser.left.refresh()
        browser.select([root.appendingPathComponent("sample.txt")], in: .left)
        let snapshot = QuickLookSelection(pane: browser.commandPane)
        browser.left.releaseAccess()
        let preview = QuickLookPreview()
        preview.update(snapshot)
        #expect(released.withLock { $0 } == 1)
        #expect(preview.previewPanel(nil, previewItemAt: 0)?.previewItemURL == nil)
        preview.stop()
        withExtendedLifetime(snapshot) {}
    }

    @Test func scopedQuickLookRejectsListedAndReplacedFileLinks() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("sample.txt")
        let target = root.appendingPathComponent("target.txt")
        try FileManager.default.moveItem(at: url, to: target)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
        for listedAsLink in [false, true] {
            let entry = DirectoryEntry(url: url, isDirectory: false, isSymbolicLink: listedAsLink)
            let browser = BrowserState(homeDirectory: root, requiresFolderAccess: true, load: { url in
                DirectoryListing(directory: url, entries: [entry], access: DirectoryAccess(root: url) {})
            })
            await browser.left.refresh()
            browser.select([url], in: .left)
            let preview = QuickLookPreview()
            preview.update(QuickLookSelection(pane: browser.commandPane))
            #expect(preview.previewPanel(nil, previewItemAt: 0)?.previewItemURL == nil)
            preview.stop()
        }
    }

    @Test func scopedQuickLookKeepsTheOpenedFileWhenItsPathIsReplaced() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let browser = scopedBrowser(root) {}
        await browser.left.refresh()
        let url = root.appendingPathComponent("sample.txt")
        browser.select([url], in: .left)
        let preview = QuickLookPreview()
        defer { preview.stop() }
        preview.update(QuickLookSelection(pane: browser.commandPane))
        let item = try #require(preview.previewPanel(nil, previewItemAt: 0))
        try FileManager.default.moveItem(at: url, to: root.appendingPathComponent("original.txt"))
        try Data("replacement".utf8).write(to: url)
        let source = try #require(item.previewItemURL)
        #expect(try Data(contentsOf: source) == Data("original".utf8))
    }

    @Test func scopedSnapshotsRequireLiveAccessAndInvalidateOnRefresh() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let browser = scopedBrowser(root) {}
        await browser.left.refresh()
        let url = root.appendingPathComponent("sample.txt")
        browser.select([url], in: .left)
        let previous = QuickLookSelection(pane: browser.commandPane, requiringAccess: true)
        await browser.left.refresh()
        #expect(previous != QuickLookSelection(pane: browser.commandPane, requiringAccess: true))
        browser.left.releaseAccess()
        #expect(QuickLookSelection(pane: browser.commandPane, requiringAccess: true).urls.isEmpty)
    }

    @Test func scopedQuickLookRejectsUnavailableAndSpecialItemsWithoutBlocking() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let pipe = root.appendingPathComponent("pipe")
        #expect(mkfifo(pipe.path, 0o600) == 0)
        let urls = [pipe, root.appendingPathComponent("missing.txt"), URL(string: "https://example.invalid/sample.txt")!]
        let browser = BrowserState(homeDirectory: root, requiresFolderAccess: true, load: { url in
            DirectoryListing(directory: url, entries: urls.map { DirectoryEntry(url: $0, isDirectory: false) },
                             access: DirectoryAccess(root: url) {})
        })
        await browser.left.refresh()
        for url in urls {
            browser.select([url], in: .left)
            let preview = QuickLookPreview()
            preview.update(QuickLookSelection(pane: browser.commandPane))
            #expect(preview.previewPanel(nil, previewItemAt: 0) == nil)
            preview.stop()
        }
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-quick-look-" + UUID().uuidString, isDirectory: true).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try Data("original".utf8).write(to: root.appendingPathComponent("sample.txt"))
        return root
    }

    private func scopedBrowser(_ root: URL, release: @escaping @Sendable () -> Void) -> BrowserState {
        BrowserState(homeDirectory: root, requiresFolderAccess: true, load: { url in
            let listing = try await DirectoryListing.read(url, followingLinks: false)
            return DirectoryListing(directory: listing.directory, entries: listing.entries, access: DirectoryAccess(root: url, release: release))
        })
    }

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

    @Test func changingTheNativeDelegateReleasesAnyReplacedPreviewController() throws {
        _ = NSApplication.shared
        let browser = makeBrowser()
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = NSView()
        let predecessor = window.nextResponder
        let owner = try PreviewWindow(browser, window: window)
        defer { owner.finish() }
        let previous = try #require(window.nextResponder as? QuickLookPreview)
        let replacement = KeyPreviewDelegate()
        window.delegate = replacement
        owner.install()
        let current = try #require(window.nextResponder as? QuickLookPreview)
        #expect(current.window === window)
        #expect(current === previous || previous.window == nil)
        owner.finish()
        #expect(window.delegate === replacement && window.nextResponder === predecessor)
        #expect(current.window == nil)
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

    func install() { guardView.install() }
}
