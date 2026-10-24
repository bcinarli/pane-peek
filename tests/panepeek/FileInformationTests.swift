import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct FileInformationTests {
    @Test func collapseSharesAcrossWindowsAndPersistsThroughSelectionAndReopening() async throws {
        let files = try InformationFiles()
        defer { files.finish() }
        let first = InformationSidebar(files: files)
        defer { first.finish() }
        let second = InformationSidebar(files: files)
        defer { second.finish() }
        try await first.ready()
        try await second.ready()
        let expandedHeight = first.previewHeight
        let secondExpandedHeight = second.previewHeight
        #expect(files.preferences.object(forKey: "fileInformationExpanded") == nil)

        files.preferences.set(false, forKey: "fileInformationExpanded")
        try await waitForInformation {
            first.previewHeight > expandedHeight + 100 && second.previewHeight > secondExpandedHeight + 100
        }
        let collapsedHeight = first.previewHeight
        let reopenedPreferences = try #require(UserDefaults(suiteName: files.domain))
        let reopened = InformationSidebar(files: files, preferences: reopenedPreferences)
        defer { reopened.finish() }
        try await reopened.ready()
        #expect(abs(reopened.previewHeight - collapsedHeight) < 1)
        reopened.select(files.other)
        try await waitForInformation { reopened.preview.selection?.item.url == files.other && !reopened.preview.isLoading }
        #expect(files.preferences.object(forKey: "fileInformationExpanded") as? Bool == false)
        #expect(abs(reopened.previewHeight - collapsedHeight) < 1)
        files.preferences.set(true, forKey: "fileInformationExpanded")
        try await waitForInformation {
            abs(first.previewHeight - expandedHeight) < 1 && abs(second.previewHeight - secondExpandedHeight) < 1
        }
    }

    @Test func collapseReclaimsHeightWithoutReplacingAnEditingDocument() async throws {
        let files = try InformationFiles()
        defer { files.finish() }
        let first = InformationSidebar(files: files)
        defer { first.finish() }
        let second = InformationSidebar(files: files)
        defer { second.finish() }
        try await first.ready()
        try await second.ready()
        first.preview.setMode(.edit)
        try await waitForInformation { first.host.layoutSubtreeIfNeeded(); return first.editor?.isEditable == true }
        let editor = try #require(first.editor)
        first.window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 200, length: 0))
        editor.insertText("draft ", replacementRange: editor.selectedRange())
        try #require(first.preview.isDirty && editor.undoManager?.canUndo == true)
        let draft = first.preview.text
        let document = first.preview.documentID
        let selection = editor.selectedRange()
        let scroll = try #require(editor.enclosingScrollView)
        scroll.contentView.scroll(to: NSPoint(x: scroll.contentView.bounds.minX, y: 100))
        scroll.reflectScrolledClipView(scroll.contentView)
        let origin = scroll.contentView.bounds.origin
        let expandedHeight = scroll.contentView.bounds.height

        files.preferences.set(false, forKey: "fileInformationExpanded")
        try await waitForInformation { first.previewHeight > expandedHeight + 100 && second.previewHeight > expandedHeight + 100 }
        #expect(first.editor === editor)
        #expect(first.preview.documentID == document && first.preview.text == draft && first.preview.isDirty)
        #expect(editor.selectedRange() == selection && scroll.contentView.bounds.origin == origin)
        #expect(first.window.firstResponder === editor)
        files.preferences.set(true, forKey: "fileInformationExpanded")
        try await waitForInformation { abs(first.previewHeight - expandedHeight) < 1 }
        #expect(first.editor === editor && editor.selectedRange() == selection)
        #expect(scroll.contentView.bounds.origin == origin)
        #expect(editor.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(first.preview.text == files.original && !first.preview.isDirty)
        #expect(try String(contentsOf: files.text, encoding: .utf8) == files.original)
    }
}

@MainActor private final class InformationFiles {
    let domain = "panepeek-file-information-" + UUID().uuidString
    let preferences: UserDefaults
    let root: URL
    let text: URL
    let other: URL
    let original = (0..<150).map { "Line \($0): keep this draft and its native editing state.\n" }.joined()

    init() throws {
        preferences = try #require(UserDefaults(suiteName: domain))
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-information-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        text = root.appendingPathComponent("notes.txt")
        other = root.appendingPathComponent("other.txt")
        try Data(original.utf8).write(to: text)
        try Data("Other selection".utf8).write(to: other)
    }

    func finish() {
        preferences.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor private final class InformationSidebar {
    let preview = PreviewState()
    let sizing = DetailsSizing()
    let preferences: UserDefaults
    let host: NSHostingView<AnyView>
    let window: NSWindow

    init(files: InformationFiles, preferences: UserDefaults? = nil) {
        _ = NSApplication.shared
        self.preferences = preferences ?? files.preferences
        let selection = DetailsSelection(item: DirectoryEntry(url: files.text, isDirectory: false), listingRevision: UUID())
        host = NSHostingView(rootView: AnyView(DetailsSidebar(selection: selection, preview: preview, sizing: sizing)
            .defaultAppStorage(self.preferences)))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 1100),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
    }

    var editor: EditorTextView? { editor(in: host) }
    var previewHeight: CGFloat { host.layoutSubtreeIfNeeded(); return editor?.enclosingScrollView?.contentView.bounds.height ?? 0 }

    func ready() async throws {
        try await waitForInformation { self.host.layoutSubtreeIfNeeded(); return self.preview.text != nil && !self.preview.isLoading && self.editor != nil }
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
    }

    func select(_ url: URL?) {
        let selection = url.map { DetailsSelection(item: DirectoryEntry(url: $0, isDirectory: false), listingRevision: UUID()) }
        host.rootView = AnyView(DetailsSidebar(selection: selection, preview: preview, sizing: sizing).defaultAppStorage(preferences))
        host.layoutSubtreeIfNeeded()
    }

    func finish() { window.orderOut(nil); window.contentView = nil; window.close() }

    private func editor(in view: NSView) -> EditorTextView? {
        if let editor = view as? EditorTextView { return editor }
        return view.subviews.lazy.compactMap { self.editor(in: $0) }.first
    }
}

@MainActor private func waitForInformation(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    try #require(condition())
}
