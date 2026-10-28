import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct BrowserFindTests {
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
        fixture.window.contentView = scroll
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
        fixture.window.contentView = scroll
        fixture.window.makeFirstResponder(editor)
        fixture.find.refresh(in: fixture.window)
        #expect(fixture.find.destination == .document)
        let request = fixture.find.folderRequest
        scroll.isHidden = true
        fixture.window.makeFirstResponder(fixture.window)
        fixture.find.find(in: fixture.window)
        #expect(!fixture.find.canFind && fixture.find.folderRequest == request)
        scroll.isHidden = false
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

    @Test func detailsControlsFindTheVisibleDocumentWhileBrowserControlsSearchFolders() {
        let fixture = fixture()
        let editor = EditorTextView(usingTextLayoutManager: true)
        let scroll = PreviewTextView.scrollView(for: editor)
        let header = PermissiveControl(frame: NSRect(x: 0, y: 200, width: 300, height: 40))
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 260))
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
        #expect(fixture.window.makeFirstResponder(header))
        fixture.find.find(in: fixture.window)
        #expect(!fixture.find.canFind && fixture.find.folderRequest == request)
        let browserControl = PermissiveControl(frame: controller.left.view.bounds)
        controller.left.view.addSubview(browserControl)
        #expect(fixture.window.makeFirstResponder(browserControl))
        fixture.find.find(in: fixture.window)
        #expect(fixture.find.folderRequest != request)
    }

    @Test func existingNativeFindReceivesTheActionInsteadOfFolderSearch() {
        let fixture = fixture()
        defer { fixture.window.orderOut(nil) }
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

    private func fixture() -> (window: NSWindow, browser: BrowserState, find: BrowserFind) {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let browser = BrowserState(homeDirectory: URL(fileURLWithPath: "/find"), load: { .init(directory: $0, entries: []) })
        let find = BrowserFind()
        find.window = window
        find.browser = browser
        return (window, browser, find)
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
