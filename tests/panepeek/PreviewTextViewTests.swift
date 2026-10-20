import AppKit
import SwiftUI
import Testing
@testable import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct PreviewTextViewTests {
    @Test func sandboxPreviewCannotTypeOrEnterEditMode() async throws {
        let state = PreviewState(readOnly: true, read: { _ in .text("original") })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/selected/notes.txt"), isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        #expect(state.mode == .preview && !fixture.view.isEditable)
        fixture.type(" changed")
        #expect(fixture.view.string == "original" && state.text == "original" && !state.isDirty)
    }

    @Test func nativeTypingCanUndoAndRedoAfterPresentationUpdates() async throws {
        let original = "let count = 1\n"
        let state = await loadedState(original, name: "sample.swift")
        let fixture = try NativeEditorFixture(state)
        fixture.type("// café 👀\n")
        let edited = try #require(state.text)
        #expect(state.isDirty)
        let selection = fixture.view.selectedRange()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while state.tokens.isEmpty && ContinuousClock.now < deadline { await Task.yield() }
        #expect(!state.tokens.isEmpty)
        fixture.present()
        #expect(fixture.view.selectedRange() == selection)
        #expect(fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == original && state.text == original && !state.isDirty)
        #expect(fixture.redoEnabled)
        fixture.redo()
        #expect(fixture.view.string == edited && state.text == edited && state.isDirty)
    }

    @Test func undoAndRedoRespectModesAndTheLiveEditGateWithoutLosingHistory() async throws {
        let state = await loadedState("original")
        let fixture = try NativeEditorFixture(state)
        fixture.type(" edited")
        fixture.gate.isOpen = false
        #expect(!fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == "original edited" && state.text == "original edited")
        fixture.gate.isOpen = true
        fixture.undo()
        #expect(fixture.view.string == "original" && !state.isDirty)
        fixture.gate.isOpen = false
        #expect(!fixture.redoEnabled)
        fixture.redo()
        #expect(fixture.view.string == "original" && !state.isDirty)
        fixture.gate.isOpen = true
        fixture.redo()
        #expect(fixture.view.string == "original edited" && state.isDirty)
        state.setMode(.preview)
        fixture.present()
        #expect(!fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == "original edited" && state.isDirty)
        state.setMode(.edit)
        fixture.present()
        fixture.undo()
        #expect(fixture.view.string == "original" && !state.isDirty)
    }

    @Test func typingAfterSaveUndoesToTheSavedBaselineAndDiscardClearsHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-native-undo-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("sample.txt")
        try Data("original".utf8).write(to: url)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try NativeEditorFixture(state)
        fixture.type(" saved")
        #expect(await state.save())
        fixture.present()
        fixture.type(" later")
        fixture.undo()
        #expect(fixture.view.string == "original saved" && state.text == "original saved" && !state.isDirty)
        fixture.redo()
        #expect(fixture.view.string == "original saved later" && state.isDirty)
        state.discardChanges()
        fixture.present()
        #expect(fixture.view.string == "original saved" && !state.isDirty && !fixture.undoEnabled)
        fixture.undo()
        #expect(fixture.view.string == "original saved" && !state.isDirty)
        #expect(try Data(contentsOf: url) == Data("original saved".utf8))
    }

    @Test func listingRefreshKeepsTheSidebarEditorAndUndoAfterSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-sidebar-save-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("notes.txt")
        try Data("original".utf8).write(to: url)
        let item = DirectoryEntry(url: url, isDirectory: false)
        let initial = DetailsSelection(item: item, listingRevision: UUID())
        let state = PreviewState()
        let sizing = DetailsSizing()
        let host = NSHostingView(rootView: DetailsSidebar(selection: initial, preview: state, sizing: sizing))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while (state.text == nil || state.isLoading) && ContinuousClock.now < deadline { await Task.yield() }
        try #require(state.text == "original" && !state.isLoading)
        state.setMode(.edit)
        host.layoutSubtreeIfNeeded()
        let editor = try #require(descendants(of: EditorTextView.self, in: host).first)
        window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 8, length: 0))
        editor.insertText(" saved", replacementRange: editor.selectedRange())
        try #require(state.isDirty && state.text == "original saved")
        #expect(await state.save())
        let refreshed = DetailsSelection(item: item, listingRevision: UUID())
        host.rootView = DetailsSidebar(selection: refreshed, preview: state, sizing: sizing)
        host.layoutSubtreeIfNeeded()
        #expect(descendants(of: EditorTextView.self, in: host).first === editor)
        await state.load(refreshed)
        host.rootView = DetailsSidebar(selection: refreshed, preview: state, sizing: sizing)
        host.layoutSubtreeIfNeeded()
        let retained = try #require(descendants(of: EditorTextView.self, in: host).first)
        #expect(retained === editor)
        window.makeFirstResponder(retained)
        #expect(retained.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(retained.string == "original" && state.text == "original" && state.isDirty)
        #expect(try Data(contentsOf: url) == Data("original saved".utf8))
    }

    @Test func renderedMarkdownKeepsTheHiddenEditorAndItsUndoHistoryAcrossModes() async throws {
        let state = await loadedState("# Title", name: "notes.md")
        state.setMode(.preview)
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        #expect(fixture.rendered?.string == "Title" && editor.enclosingScrollView?.isHidden == true)
        state.setMode(.edit)
        fixture.present()
        #expect(fixture.rendered == nil && editor.enclosingScrollView?.isHidden == false)
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.insertText(" draft", replacementRange: editor.selectedRange())
        await state.setMode(.preview)?.value
        fixture.present()
        #expect(fixture.rendered?.string == "Title draft" && state.isDirty)
        state.setMode(.edit)
        fixture.present()
        #expect(try fixture.editor() === editor)
        #expect(editor.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(editor.string == "# Title" && state.text == "# Title" && !state.isDirty)
    }

    @Test func documentEditorLocksDuringRenameWithoutLosingItsUndoHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-document-rename-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("notes.md")
        try Data("# Title".utf8).write(to: url)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        state.setMode(.edit)
        let fixture = try DocumentFixture(state)
        let editor = try fixture.editor()
        fixture.window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.insertText(" draft", replacementRange: editor.selectedRange())
        state.setChangingLocation(try await ItemRename.capture(url))
        fixture.present()
        #expect(state.isChangingLocation && !editor.isEditable)
        #expect(state.text == "# Title draft" && state.isDirty)
        state.setChangingLocation(nil)
        fixture.present()
        #expect(try fixture.editor() === editor && editor.isEditable)
        #expect(editor.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil))
        #expect(editor.string == "# Title" && state.text == "# Title" && !state.isDirty)
    }

    private func loadedState(_ text: String, name: String = "sample.txt") async -> PreviewState {
        let state = PreviewState(read: { _ in .text(text) })
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/native-editor/\(name)"), isDirectory: false)
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        state.setMode(.edit)
        return state
    }
}

@MainActor private final class NativeEditGate {
    var isOpen = true
}

@MainActor private final class NativeEditorFixture {
    let state: PreviewState
    let gate: NativeEditGate
    let host: NSHostingView<PreviewTextView>
    let window: NSWindow
    let view: EditorTextView
    private let undoItem = NSMenuItem(title: "Undo", action: #selector(EditorTextView.undo(_:)), keyEquivalent: "z")
    private let redoItem = NSMenuItem(title: "Redo", action: #selector(EditorTextView.redo(_:)), keyEquivalent: "Z")

    init(_ state: PreviewState) throws {
        _ = NSApplication.shared
        self.state = state
        let gate = NativeEditGate()
        self.gate = gate
        host = NSHostingView(rootView: Self.preview(state, gate: gate))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        view = try #require(descendants(of: EditorTextView.self, in: host).first)
        window.makeFirstResponder(view)
    }

    var undoEnabled: Bool { view.validateUserInterfaceItem(undoItem) }
    var redoEnabled: Bool { view.validateUserInterfaceItem(redoItem) }

    func present() {
        host.rootView = Self.preview(state, gate: gate)
        host.layoutSubtreeIfNeeded()
    }

    func type(_ text: String) {
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        view.insertText(text, replacementRange: view.selectedRange())
    }

    func undo() { #expect(view.tryToPerform(#selector(EditorTextView.undo(_:)), with: nil)) }
    func redo() { #expect(view.tryToPerform(#selector(EditorTextView.redo(_:)), with: nil)) }

    private static func preview(_ state: PreviewState, gate: NativeEditGate) -> PreviewTextView {
        PreviewTextView(text: state.text ?? "", documentID: state.documentID, saveRevision: state.saveRevision, mode: state.mode,
                        tokens: state.tokens, canChange: { gate.isOpen && state.canEdit && state.mode == .edit },
                        changed: { state.updateText($0) })
    }
}

@MainActor private final class DocumentFixture {
    let state: PreviewState
    let host: NSHostingView<PreviewDocument>
    let window: NSWindow

    init(_ state: PreviewState) throws {
        _ = NSApplication.shared
        self.state = state
        host = NSHostingView(rootView: PreviewDocument(preview: state, text: state.text ?? ""))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
    }

    func editor() throws -> EditorTextView { try #require(descendants(of: EditorTextView.self, in: host).first) }
    var rendered: NSTextView? { descendants(of: NSTextView.self, in: host).first { !($0 is EditorTextView) } }

    func present() {
        host.rootView = PreviewDocument(preview: state, text: state.text ?? "")
        host.layoutSubtreeIfNeeded()
    }
}

@MainActor private func descendants<View: NSView>(of type: View.Type, in view: NSView) -> [View] {
    view.subviews.flatMap { child in [child as? View].compactMap { $0 } + descendants(of: type, in: child) }
}
