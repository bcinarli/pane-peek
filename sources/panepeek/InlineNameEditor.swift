import AppKit
import SwiftUI

struct InlineNameEditor: NSViewRepresentable {
    let requestID: UUID
    let name: String
    let isDirectory: Bool
    let isWorking: Bool
    let changed: (String) -> Void
    let submit: (String) -> Void
    let cancel: () -> Void
    let blurred: () -> Void

    func makeNSView(context: Context) -> InlineRenameTextField { InlineRenameTextField() }

    func updateNSView(_ field: InlineRenameTextField, context: Context) {
        field.configure(requestID: requestID, name: name, isDirectory: isDirectory, isWorking: isWorking,
                        changed: changed, submit: submit, cancel: cancel, blurred: blurred)
    }

    static func dismantleNSView(_ field: InlineRenameTextField, coordinator: ()) { field.stop() }
}

final class InlineRenameTextField: NSTextField, NSTextFieldDelegate {
    private var requestID: UUID?
    private var selection: NSRange?
    private var isWorking = false
    private var finished = false
    private var focusScheduled = false
    private var changed: (String) -> Void = { _ in }
    private var submit: (String) -> Void = { _ in }
    private var cancel: () -> Void = {}
    private var blurred: () -> Void = {}

    static func initialSelection(name: String, isDirectory: Bool) -> NSRange {
        let text = name as NSString
        let dot = text.range(of: ".", options: .backwards)
        let length = !isDirectory && dot.location != NSNotFound && dot.location > 0 && NSMaxRange(dot) < text.length
            ? dot.location : text.length
        return NSRange(location: 0, length: length)
    }

    func configure(requestID: UUID, name: String, isDirectory: Bool, isWorking: Bool,
                   changed: @escaping (String) -> Void, submit: @escaping (String) -> Void,
                   cancel: @escaping () -> Void, blurred: @escaping () -> Void = {}) {
        self.changed = changed
        self.submit = submit
        self.cancel = cancel
        self.blurred = blurred
        if self.requestID != requestID {
            self.requestID = requestID
            stringValue = name
            selection = Self.initialSelection(name: name, isDirectory: isDirectory)
            finished = false
            delegate = self
            font = .preferredFont(forTextStyle: .body)
            isBordered = true
            bezelStyle = .roundedBezel
            isEditable = true
            isSelectable = true
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            setAccessibilityLabel("Rename \(name)")
            setAccessibilityHelp("Enter the filename. Return renames; Escape cancels.")
        } else if self.isWorking && !isWorking {
            finished = false
            selection = NSRange(location: 0, length: (stringValue as NSString).length)
        }
        self.isWorking = isWorking
        focusWhenReady()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusWhenReady()
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { selectInitialName() }
        return accepted
    }

    func controlTextDidBeginEditing(_ notification: Notification) { selectInitialName() }

    func controlTextDidChange(_ notification: Notification) { changed(stringValue) }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard !finished, !isWorking else { return }
        finished = true
        DispatchQueue.main.async { [weak self] in self?.blurred() }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            guard !finished, !isWorking else { return true }
            finished = true
            submit(stringValue)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            guard !finished, !isWorking else { return true }
            finished = true
            cancel()
            return true
        }
        return false
    }

    func stop() { finished = true; blurred = {} }

    private func selectInitialName() {
        guard let selection, let editor = currentEditor() as? NSTextView else { return }
        editor.setSelectedRange(selection)
        self.selection = nil
    }

    private func focusWhenReady() {
        if currentEditor() != nil, !isWorking {
            selectInitialName()
            return
        }
        guard window != nil, selection != nil, !isWorking, !focusScheduled else { return }
        focusScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.focusScheduled = false
            guard let window = self.window, self.selection != nil, !self.isWorking, !self.finished else { return }
            // Refocusing an active field editor ends editing and looks like cancellation.
            if self.currentEditor() == nil { window.makeFirstResponder(self) }
            self.selectInitialName()
        }
    }
}
