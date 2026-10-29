import AppKit
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct FolderSearchFieldTests {
    @Test func repeatedFindKeepsAnAlreadyFocusedEmptyFieldEditing() async throws {
        _ = NSApplication.shared
        let browser = BrowserState()
        var ended = 0
        let coordinator = FolderSearchField.Coordinator(browser: browser, focusWhenAttached: true,
                                                       endedEditing: { ended += 1 })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = coordinator.field
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        let editor = try #require(coordinator.field.currentEditor())
        coordinator.requestFocus(UUID())
        coordinator.requestFocus(UUID())
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(coordinator.field.currentEditor() === editor && window.firstResponder === editor)
        #expect(ended == 0 && coordinator.field.stringValue.isEmpty)
    }

    @Test func explicitRequestsRefocusAnAttachedFieldWithoutResettingItsQuery() async {
        _ = NSApplication.shared
        let browser = BrowserState(homeDirectory: URL(fileURLWithPath: "/search"), load: { .init(directory: $0, entries: []) })
        await browser.left.refresh()
        browser.search("retained query", in: .left)
        let coordinator = FolderSearchField.Coordinator(browser: browser)
        let other = NSTextField(string: "other input")
        let stack = NSStackView(views: [coordinator.field, other])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = stack
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        window.makeFirstResponder(other)
        let request = UUID()
        coordinator.requestFocus(request)
        #expect(coordinator.field.currentEditor() != nil)
        #expect(coordinator.field.stringValue == "retained query" && browser.left.searchQuery == "retained query")
        window.makeFirstResponder(other)
        let responder = window.firstResponder
        coordinator.requestFocus(request)
        #expect(window.firstResponder === responder)
        coordinator.requestFocus(UUID())
        #expect(coordinator.field.currentEditor() != nil && coordinator.field.stringValue == "retained query")
        browser.left.releaseAccess()
    }

    @Test func revealedFieldTakesNativeFocusAndReportsWhenEditingEnds() async throws {
        _ = NSApplication.shared
        let browser = BrowserState()
        var ended = false
        let coordinator = FolderSearchField.Coordinator(browser: browser, focusWhenAttached: true, endedEditing: { ended = true })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = coordinator.field
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let editor = try #require(coordinator.field.currentEditor())
        #expect(window.firstResponder === editor)
        window.makeFirstResponder(nil)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(ended)
    }

    @Test func nativeInputAndClearFollowRetainedBrowserInsteadOfDisplayedSide() async {
        _ = NSApplication.shared
        let browser = BrowserState(homeDirectory: URL(fileURLWithPath: "/search"), load: { .init(directory: $0, entries: []) })
        await browser.left.refresh()
        await browser.right.refresh()
        let coordinator = FolderSearchField.Coordinator(browser: browser)
        let field = coordinator.field
        field.stringValue = "first"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        #expect(browser.left.searchQuery == "first" && browser.right.searchQuery.isEmpty)
        browser.focus(.right)
        coordinator.update(browser: browser)
        #expect(field.stringValue.isEmpty)
        field.stringValue = "second"
        coordinator.submit()
        browser.setMode(.onePane)
        browser.setMode(.twoPanes)
        coordinator.update(browser: browser)
        #expect(field.stringValue == "second" && browser.right.searchQuery == "second")
        field.stringValue = ""
        let action = field.action!
        #expect(field.sendAction(action, to: field.target))
        #expect(browser.right.searchQuery.isEmpty && !browser.right.isSearching)
        #expect(browser.left.searchQuery == "first")
        #expect(field.accessibilityLabel() == "Search current folder and subfolders")
        browser.left.releaseAccess()
        browser.right.releaseAccess()
    }

    @Test func rejectedEditRestoresNativeFieldAndAcceptedDecisionSynchronisesIt() async throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: "/search", isDirectory: true)
        let item = DirectoryEntry(url: root.appendingPathComponent("draft.txt"), isDirectory: false)
        let preview = PreviewState(read: { _ in .text("original") })
        var answer: (@MainActor (BrowserState.UnsavedChoice) -> Void)?
        let browser = BrowserState(homeDirectory: root, load: { .init(directory: $0, entries: [item]) }, preview: preview,
                                   confirmChanges: { _, completion in answer = completion })
        await browser.left.refresh()
        browser.select([item.url], in: .left)
        await preview.load(browser.detailsSelection)
        preview.setMode(.edit)
        await preview.updateText("draft")?.value
        let coordinator = FolderSearchField.Coordinator(browser: browser)
        coordinator.field.stringValue = "unmatched"
        coordinator.submit()
        #expect(coordinator.field.stringValue.isEmpty && browser.left.searchQuery.isEmpty)
        let complete = try #require(answer)
        complete(.cancel)
        #expect(preview.isDirty && browser.left.primaryItemURL == item.url)
        coordinator.field.stringValue = "unmatched"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: coordinator.field))
        coordinator.submit()
        let discard = try #require(answer)
        discard(.discard)
        coordinator.update(browser: browser)
        #expect(coordinator.field.stringValue == "unmatched" && !preview.isDirty)
        browser.left.releaseAccess()
    }

    @Test func markedTextIsNotSubmittedUntilCompositionCommits() async throws {
        _ = NSApplication.shared
        let browser = BrowserState()
        let coordinator = FolderSearchField.Coordinator(browser: browser)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = coordinator.field
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.makeFirstResponder(coordinator.field)
        let editor = try #require(coordinator.field.currentEditor() as? NSTextView)
        editor.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(browser.left.searchQuery.isEmpty && editor.hasMarkedText())
        editor.unmarkText()
        coordinator.field.stringValue = "日本"
        coordinator.submit()
        #expect(browser.left.searchQuery == "日本")
    }
}
