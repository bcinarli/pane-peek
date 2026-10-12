import AppKit
import Testing
@testable import PanePeek

@Suite(.serialized) @MainActor
struct InlineNameEditorTests {
    @Test func basenameSelectionPreservesExtensionsAndWholeDirectoryNames() {
        for (name, folder, selected) in [
            ("sample.txt", false, "sample"), ("café 👀.swift", false, "café 👀"),
            ("archive.tar.gz", false, "archive.tar"), (".env", false, ".env"),
            (".env.local", false, ".env"), ("plain", false, "plain"),
            ("trailing.", false, "trailing."), ("folder.with.dots", true, "folder.with.dots"),
            ("Example.app", false, "Example")
        ] {
            let range = InlineRenameTextField.initialSelection(name: name, isDirectory: folder)
            #expect((name as NSString).substring(with: range) == selected)
        }
    }

    @Test func returnAndEscapeAreConsumedOnceAndBusyInputCannotSubmit() {
        _ = NSApplication.shared
        let field = InlineRenameTextField()
        let request = UUID()
        var submitted: [String] = []
        var cancelled = 0
        field.configure(requestID: request, name: "sample.txt", isDirectory: false, isWorking: false,
                        changed: { _ in }, submit: { submitted.append($0) }, cancel: { cancelled += 1 })
        field.stringValue = "renamed.txt"
        let editor = NSTextView()
        #expect(field.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(submitted == ["renamed.txt"])
        _ = field.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:)))
        #expect(submitted.count == 1)

        let other = InlineRenameTextField()
        other.configure(requestID: UUID(), name: "second.txt", isDirectory: false, isWorking: false,
                        changed: { _ in }, submit: { submitted.append($0) }, cancel: { cancelled += 1 })
        #expect(other.control(other, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(cancelled == 1 && submitted.count == 1)
        field.configure(requestID: request, name: "renamed.txt", isDirectory: false, isWorking: true,
                        changed: { _ in }, submit: { submitted.append($0) }, cancel: {})
        _ = field.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:)))
        #expect(submitted.count == 1)
    }

    @Test func nativeFieldSelectsTheBasenameAndRetainsTypedTextAndCaretThroughUpdates() async throws {
        _ = NSApplication.shared
        let field = InlineRenameTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        let request = UUID()
        var changes: [String] = []
        var blurs = 0
        field.configure(requestID: request, name: "café 👀.swift", isDirectory: false, isWorking: false,
                        changed: { changes.append($0) }, submit: { _ in }, cancel: {})
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 280, height: 24), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = field
        window.makeFirstResponder(field)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while field.currentEditor() == nil, ContinuousClock.now < deadline { await Task.yield() }
        await Task.yield()
        let editor = try #require(field.currentEditor() as? NSTextView)
        #expect((editor.string as NSString).substring(with: editor.selectedRange()) == "café 👀")
        editor.insertText("new", replacementRange: editor.selectedRange())
        let caret = editor.selectedRange()
        #expect(editor.string == "new.swift" && changes.last == "new.swift")
        field.configure(requestID: request, name: "new.swift", isDirectory: false, isWorking: false,
                        changed: { changes.append($0) }, submit: { _ in }, cancel: {})
        #expect(editor.string == "new.swift" && editor.selectedRange() == caret)
        _ = field.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:)))
        field.configure(requestID: request, name: "new.swift", isDirectory: false, isWorking: true,
                        changed: { changes.append($0) }, submit: { _ in }, cancel: {}, blurred: { blurs += 1 })
        field.configure(requestID: request, name: "new.swift", isDirectory: false, isWorking: false,
                        changed: { changes.append($0) }, submit: { _ in }, cancel: {}, blurred: { blurs += 1 })
        try await Task.sleep(for: .milliseconds(30))
        #expect(blurs == 0 && field.currentEditor() === editor)
        #expect(editor.selectedRange() == NSRange(location: 0, length: (editor.string as NSString).length))
    }
}
