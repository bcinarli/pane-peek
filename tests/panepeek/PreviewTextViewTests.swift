import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct PreviewTextViewTests {
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
        view = try #require(Self.textView(in: host))
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

    private static func textView(in view: NSView) -> EditorTextView? {
        if let text = view as? EditorTextView { return text }
        for child in view.subviews {
            if let text = textView(in: child) { return text }
        }
        return nil
    }
}
