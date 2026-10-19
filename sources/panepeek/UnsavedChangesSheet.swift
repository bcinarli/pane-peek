import AppKit
import PanePeekCore

@MainActor final class UnsavedChangesSheet: ConfirmationSheet {
    private(set) var choice: BrowserState.UnsavedChoice = .cancel
    private var answered = false

    init(_ fileName: String) {
        let heading = NSTextField(wrappingLabelWithString: "Save changes to \(fileName)?")
        heading.font = .preferredFont(forTextStyle: .headline)
        let message = NSTextField(wrappingLabelWithString:
            "Save keeps your changes. Discard continues without saving. Cancel keeps the draft open.")
        let cancel = NSButton(title: "Cancel", target: nil, action: #selector(cancelChanges))
        let discard = NSButton(title: "Discard", target: nil, action: #selector(discardChanges))
        let save = NSButton(title: "Save", target: nil, action: #selector(saveChanges))
        super.init(title: "Unsaved changes", content: [heading, message], buttons: [cancel, discard, save], primary: save)
        buttons.forEach { $0.target = self }
        cancel.keyEquivalent = "\u{1b}"
        cancel.keyEquivalentModifierMask = []
        initialFirstResponder = save
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func cancelChanges() { finish(.cancel) }
    @objc private func discardChanges() { finish(.discard) }
    @objc private func saveChanges() { finish(.save) }

    private func finish(_ answer: BrowserState.UnsavedChoice) {
        guard !answered else { return }
        answered = true
        choice = answer
        sheetParent?.endSheet(self)
    }
}
