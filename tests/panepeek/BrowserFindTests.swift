import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct BrowserFindTests {
    private let identity = FindPresentation.Identity(document: UUID(), editing: false)
    @Test(arguments: ["empty", "image.png", "movie.mov", "paper.pdf"])
    func settledDetailsWithoutTextKeepFolderFindAvailable(name: String) async {
        let fixture = fixture()
        let selection = name == "empty" ? nil : DetailsSelection(
            item: DirectoryEntry(url: URL(fileURLWithPath: "/find/" + name), isDirectory: false), listingRevision: UUID())
        let sizing = DetailsSizing()
        let details = DetailsSidebar(selection: selection, preview: fixture.browser.preview,
                                     sizing: sizing, notifications: fixture.browser.notifications)
        let controller = BrowserSplitView<Color, Color, DetailsSidebar>.Controller(
            left: .clear, right: .clear, details: details, sizing: sizing)
        fixture.window.contentViewController = controller
        fixture.window.makeKeyAndOrderFront(nil)
        controller.view.layoutSubtreeIfNeeded()
        defer { fixture.window.orderOut(nil) }
        #expect(presentations(in: controller.details.view) == [.unavailable])
        let control = PermissiveControl(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        controller.details.view.addSubview(control)
        #expect(fixture.window.makeFirstResponder(control))
        for _ in 0..<3 {
            fixture.find.refresh(in: fixture.window)
            #expect(fixture.find.canFind && fixture.find.canSearchFolder)
        }
        for _ in 0..<2 {
            let request = fixture.find.folderRequest
            fixture.find.find(in: fixture.window)
            #expect(fixture.find.folderRequest != request && fixture.find.destination == .folder)
        }
    }

    @Test func folderRequestsRetainQueriesAndStayInTheirWindow() async {
        let first = fixture(), second = fixture()
        defer { first.window.orderOut(nil); second.window.orderOut(nil) }
        await first.browser.left.refresh()
        await first.browser.right.refresh()
        first.browser.search("left query", in: .left)
        first.browser.search("right query", in: .right)
        first.browser.focus(.right)
        first.browser.setMode(.onePane)
        let table = DirectoryTableView()
        first.window.contentView = table
        first.window.makeKeyAndOrderFront(nil)
        first.window.makeFirstResponder(table)
        first.find.refresh(in: first.window)
        #expect(first.find.destination == .folder)
        let request = first.find.folderRequest, other = second.find.folderRequest
        first.find.find(in: first.window)
        #expect(first.find.folderRequest != request && second.find.folderRequest == other)
        #expect(first.browser.right.searchQuery == "right query" && first.browser.left.searchQuery == "left query")
        second.window.makeKeyAndOrderFront(nil)
        let inactive = first.find.folderRequest
        first.find.searchFolder(in: second.window)
        #expect(first.find.folderRequest == inactive)
    }

    @Test func documentFindAndItsFieldKeepOwnershipUntilExplicitFolderSearch() throws {
        let fixture = fixture()
        defer { fixture.window.orderOut(nil) }
        let editor = EditorTextView(usingTextLayoutManager: true)
        defer { editor.hideFindBar() }
        editor.usesFindBar = true
        editor.string = "current draft"
        let scroll = PreviewTextView.scrollView(for: editor)
        showDocument(scroll, in: fixture.window)
        fixture.window.makeKeyAndOrderFront(nil)
        fixture.window.makeFirstResponder(editor)
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .document)
        let request = fixture.find.folderRequest
        fixture.find.find(in: fixture.window)
        #expect(scroll.isFindBarVisible && fixture.find.folderRequest == request)
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .document)
        fixture.find.find(in: fixture.window)
        #expect(scroll.isFindBarVisible && fixture.find.folderRequest == request)
        fixture.find.searchFolder(in: fixture.window)
        #expect(fixture.find.folderRequest != request && editor.string == "current draft")
        func searchField(in view: NSView?) -> NSSearchField? {
            guard let view else { return nil }
            return (view as? NSSearchField) ?? view.subviews.lazy.compactMap { searchField(in: $0) }.first
        }
        let field = try #require(searchField(in: scroll.findBarView))
        #expect(fixture.window.makeFirstResponder(field))
        #expect(field.currentEditor() === fixture.window.firstResponder)
        let folderRequest = fixture.find.folderRequest
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.canFind && fixture.find.destination == .document)
        fixture.find.find(in: fixture.window)
        #expect(scroll.isFindBarVisible && fixture.find.folderRequest == folderRequest)
        let control = PermissiveControl()
        let content = NSView(frame: fixture.window.contentLayoutRect)
        scroll.frame = NSRect(x: 0, y: 0, width: 300, height: 260)
        control.frame = NSRect(x: 300, y: 0, width: 120, height: 260)
        content.addSubview(scroll)
        content.addSubview(control)
        fixture.window.contentView = content
        editor.hideFindBar()
        #expect(fixture.window.makeFirstResponder(control))
        #expect(fixture.window.firstResponder === control)
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .folder)
        #expect(fixture.window.makeFirstResponder(fixture.window))
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .folder)
    }

    @Test func aDocumentTransitionWaitsForItsVisibleClientWithoutOpeningFolderSearch() {
        let fixture = fixture()
        let editor = EditorTextView(usingTextLayoutManager: true)
        let scroll = PreviewTextView.scrollView(for: editor)
        defer { editor.hideFindBar(); fixture.window.orderOut(nil) }
        let presentation = showDocument(scroll, in: fixture.window)
        fixture.window.makeFirstResponder(editor)
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .document)
        let request = fixture.find.folderRequest
        scroll.isHidden = true
        presentation.presentation = .waiting(identity)
        fixture.window.makeFirstResponder(fixture.window)
        fixture.find.find(in: fixture.window)
        #expect(!fixture.find.canFind && fixture.find.folderRequest == request)
        scroll.isHidden = false
        presentation.presentation = .ready(identity)
        fixture.find.find(in: fixture.window)
        #expect(scroll.isFindBarVisible && fixture.find.folderRequest == request)
    }

    @Test func textEntryBlockedContextsAndSheetsCannotRedirectFind() {
        let fixture = fixture()
        defer { fixture.window.orderOut(nil) }
        let field = NSTextField(string: "unfinished name")
        fixture.window.contentView = field
        fixture.window.makeKeyAndOrderFront(nil)
        fixture.window.makeFirstResponder(field)
        let responder = fixture.window.firstResponder, request = fixture.find.folderRequest
        fixture.find.refresh(in: fixture.window)
        #expect(!fixture.find.canFind && !fixture.find.canSearchFolder)
        fixture.find.find(in: fixture.window)
        fixture.find.searchFolder(in: fixture.window)
        #expect(fixture.window.firstResponder === responder && fixture.find.folderRequest == request)
        fixture.window.makeFirstResponder(nil)
        fixture.find.isBlocked = true
        fixture.find.refresh(in: fixture.window)
        #expect(!fixture.find.canFind)
        fixture.find.isBlocked = false
        let sheet = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        fixture.window.beginSheet(sheet)
        fixture.find.refresh(in: fixture.window)
        #expect(!fixture.find.canFind)
        fixture.window.endSheet(sheet)
    }

    @Test func explicitFolderSearchRemainsAvailableWhileDocumentFindWaits() {
        let fixture = fixture()
        let editor = EditorTextView(usingTextLayoutManager: true)
        let scroll = PreviewTextView.scrollView(for: editor)
        let presentation = showDocument(scroll, in: fixture.window)
        defer { editor.hideFindBar(); fixture.window.orderOut(nil) }
        fixture.window.makeFirstResponder(editor)
        fixture.find.refresh(in: fixture.window)
        scroll.isHidden = true
        presentation.presentation = .waiting(identity)
        fixture.window.makeFirstResponder(fixture.window)
        fixture.find.refresh(in: fixture.window)
        #expect(!fixture.find.canFind && fixture.find.canSearchFolder)
        let request = fixture.find.folderRequest
        fixture.find.searchFolder(in: fixture.window)
        #expect(fixture.find.folderRequest != request)
    }

    @Test func closingTheDocumentReturnsWindowFocusToFolderSearch() async {
        let fixture = fixture()
        let editor = EditorTextView(usingTextLayoutManager: true)
        showDocument(PreviewTextView.scrollView(for: editor), in: fixture.window)
        defer { editor.hideFindBar(); fixture.window.orderOut(nil) }
        fixture.window.makeFirstResponder(editor)
        fixture.find.find(in: fixture.window)
        let request = fixture.find.folderRequest
        await fixture.browser.preview.load(nil)
        fixture.window.contentView = NSView()
        fixture.window.makeFirstResponder(fixture.window)
        fixture.find.find(in: fixture.window)
        #expect(fixture.find.destination == .folder && fixture.find.folderRequest != request)
    }

    @Test(arguments: ["binary", "oversized", "read-error"], [false, true])
    func completedNonTextReplacementsReturnToFolderSearch(result: String, detailsControlFocused: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-find-replacement-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("notes.txt")
        try Data("original text".utf8).write(to: file)
        let fixture = fixture()
        let state = fixture.browser.preview
        let item = DirectoryEntry(url: file, isDirectory: false)
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        let editor = EditorTextView(usingTextLayoutManager: true)
        showDocument(PreviewTextView.scrollView(for: editor), in: fixture.window)
        defer { editor.hideFindBar(); fixture.window.orderOut(nil) }
        #expect(fixture.window.makeFirstResponder(editor))
        fixture.find.find(in: fixture.window)
        let request = fixture.find.folderRequest
        switch result {
        case "binary": try Data([0, 1, 2]).write(to: file)
        case "oversized": try Data(repeating: 65, count: TextPreview.maximumBytes + 1).write(to: file)
        default: try FileManager.default.removeItem(at: file)
        }
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        #expect(state.selection != nil && state.text == nil && !state.isLoading)
        if result == "read-error" { #expect(state.errorMessage != nil) }
        else { #expect(state.preview == .unavailable(result == "binary" ? .binary : .tooLarge)) }
        let content = FindPresentationView.Marker(.unavailable)
        content.frame = fixture.window.contentLayoutRect
        content.identifier = FindResponder.documentContainerIdentifier
        let control = PermissiveControl(frame: content.bounds)
        content.addSubview(control)
        fixture.window.contentView = content
        #expect(fixture.window.makeFirstResponder(detailsControlFocused ? control : fixture.window))
        fixture.find.find(in: fixture.window)
        #expect(fixture.find.destination == .folder && fixture.find.folderRequest != request)
        let repeated = fixture.find.folderRequest
        fixture.find.find(in: fixture.window)
        #expect(fixture.find.destination == .folder && fixture.find.folderRequest != repeated)
    }

    @Test func replacementWaitsForLoadingBeforeReturningToFolderSearch() async throws {
        let (reads, requests) = AsyncStream<CheckedContinuation<TextPreview, Never>>.makeStream()
        defer { requests.finish() }
        var iterator = reads.makeAsyncIterator()
        let state = PreviewState(read: { _ in await withCheckedContinuation { requests.yield($0) } })
        let fixture = fixture(preview: state)
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/find/notes.txt"), isDirectory: false)
        let firstSelection = DetailsSelection(item: item, listingRevision: UUID())
        let initial = Task { await state.load(firstSelection) }
        let first = try #require(await iterator.next())
        first.resume(returning: .text("original"))
        await initial.value
        let sizing = DetailsSizing()
        func sidebar(_ selection: DetailsSelection) -> DetailsSidebar {
            DetailsSidebar(selection: selection, preview: state, sizing: sizing, notifications: fixture.browser.notifications)
        }
        let controller = BrowserSplitView<Color, Color, DetailsSidebar>.Controller(
            left: .clear, right: .clear, details: sidebar(firstSelection), sizing: sizing)
        fixture.window.contentViewController = controller
        fixture.window.makeKeyAndOrderFront(nil)
        controller.view.layoutSubtreeIfNeeded()
        func textView(in view: NSView) -> EditorTextView? {
            (view as? EditorTextView) ?? view.subviews.lazy.compactMap { textView(in: $0) }.first
        }
        let editor = try #require(textView(in: controller.details.view))
        defer { editor.hideFindBar(); fixture.window.orderOut(nil) }
        #expect(fixture.window.makeFirstResponder(editor))
        fixture.find.find(in: fixture.window)
        let request = fixture.find.folderRequest
        let replacement = DetailsSelection(item: item, listingRevision: UUID())
        controller.details.rootView = sidebar(replacement)
        controller.view.layoutSubtreeIfNeeded()
        let pending = try #require(await iterator.next())
        controller.details.rootView = sidebar(replacement)
        controller.view.layoutSubtreeIfNeeded()
        #expect(fixture.window.makeFirstResponder(fixture.window))
        #expect(state.isLoading && state.text == nil)
        fixture.find.find(in: fixture.window)
        #expect(!fixture.find.canFind && fixture.find.folderRequest == request)
        pending.resume(returning: .unavailable(.binary))
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while state.isLoading && ContinuousClock.now < deadline { await Task.yield() }
        #expect(!state.isLoading && state.preview == .unavailable(.binary))
        controller.details.rootView = sidebar(replacement)
        controller.view.layoutSubtreeIfNeeded()
        fixture.find.find(in: fixture.window)
        #expect(fixture.find.destination == .folder && fixture.find.folderRequest != request)
    }

    @Test func detailsControlsFindTheVisibleDocumentWhileBrowserControlsSearchFolders() {
        let fixture = fixture()
        let editor = EditorTextView(usingTextLayoutManager: true)
        let scroll = PreviewTextView.scrollView(for: editor)
        let header = PermissiveControl(frame: NSRect(x: 0, y: 200, width: 300, height: 40))
        let content = FindPresentationView.Marker(.ready(identity))
        content.frame = NSRect(x: 0, y: 0, width: 300, height: 260)
        scroll.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        content.addSubview(scroll)
        content.addSubview(header)
        let controller = BrowserSplitView<Color, Color, FindDetailsFixture>.Controller(
            left: .clear, right: .clear, details: FindDetailsFixture(content: content))
        fixture.window.contentViewController = controller
        fixture.window.makeKeyAndOrderFront(nil)
        controller.view.layoutSubtreeIfNeeded()
        defer { editor.hideFindBar(); fixture.window.orderOut(nil) }
        #expect(fixture.window.makeFirstResponder(header))
        let request = fixture.find.folderRequest
        fixture.find.find(in: fixture.window)
        #expect(scroll.isFindBarVisible && fixture.find.folderRequest == request)
        editor.hideFindBar()
        scroll.isHidden = true
        content.presentation = .waiting(identity)
        #expect(fixture.window.makeFirstResponder(header))
        fixture.find.find(in: fixture.window)
        #expect(!fixture.find.canFind && fixture.find.folderRequest == request)
        let browserControl = PermissiveControl(frame: controller.left.view.bounds)
        controller.left.view.addSubview(browserControl)
        #expect(fixture.window.makeFirstResponder(browserControl))
        fixture.find.find(in: fixture.window)
        #expect(fixture.find.folderRequest != request)
    }

    @Test func existingNativeFindReceivesTheActionInsteadOfFolderSearch() async {
        let state = PreviewState(read: { _ in .unavailable(.binary) })
        let fixture = fixture(preview: state)
        let editor = EditorTextView(usingTextLayoutManager: true)
        showDocument(PreviewTextView.scrollView(for: editor), in: fixture.window)
        defer { editor.hideFindBar(); fixture.window.orderOut(nil) }
        fixture.window.makeFirstResponder(editor)
        fixture.find.find(in: fixture.window)
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/find/notes.txt"), isDirectory: false)
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        let native = NativeFindView()
        fixture.window.contentView = native
        fixture.window.makeKeyAndOrderFront(nil)
        fixture.window.makeFirstResponder(native)
        let request = fixture.find.folderRequest
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .native)
        fixture.find.find(in: fixture.window)
        #expect(native.requests == 1 && fixture.find.folderRequest == request)
    }

    @Test func genericControlValidationDoesNotClaimNativeFind() {
        let fixture = fixture()
        defer { fixture.window.orderOut(nil) }
        let control = PermissiveControl()
        fixture.window.contentView = control
        fixture.window.makeFirstResponder(control)
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .folder)
        let request = fixture.find.folderRequest
        fixture.find.find(in: fixture.window)
        #expect(fixture.find.folderRequest != request)
    }

    private func fixture(preview: PreviewState? = nil) -> (window: NSWindow, browser: BrowserState, find: BrowserFind) {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let browser = BrowserState(homeDirectory: URL(fileURLWithPath: "/find"), load: { .init(directory: $0, entries: []) }, preview: preview)
        let find = BrowserFind()
        find.window = window
        find.browser = browser
        return (window, browser, find)
    }

    @discardableResult private func showDocument(_ view: NSView, in window: NSWindow) -> FindPresentationView.Marker {
        let content = FindPresentationView.Marker(.ready(identity))
        content.frame = window.contentLayoutRect
        content.identifier = FindResponder.documentContainerIdentifier
        view.frame = content.bounds
        view.autoresizingMask = [.width, .height]
        content.addSubview(view)
        window.contentView = content
        return content
    }

    private func presentations(in view: NSView) -> [FindPresentation] {
        if let marker = view as? FindPresentationView.Marker { return [marker.presentation] }
        return view.subviews.flatMap { presentations(in: $0) }
    }
}

private struct FindDetailsFixture: NSViewRepresentable {
    let content: NSView
    func makeNSView(context: Context) -> NSView { content }
    func updateNSView(_ view: NSView, context: Context) {}
}

@MainActor private final class NativeFindView: NSView, NSUserInterfaceValidations {
    var requests = 0
    override var acceptsFirstResponder: Bool { true }
    override func performTextFinderAction(_ sender: Any?) { requests += 1 }
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        item.action == #selector(NSResponder.performTextFinderAction(_:))
    }
}

@MainActor private final class PermissiveControl: NSView, NSUserInterfaceValidations {
    override var acceptsFirstResponder: Bool { true }
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool { true }
}
