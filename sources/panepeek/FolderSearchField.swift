import AppKit
import SwiftUI
import PanePeekCore

struct FolderSearchControl: View {
    let browser: BrowserState
    let find: BrowserFind
    @SwiftUI.State private var expanded = false
    @SwiftUI.State private var focusRequest: UUID?

    var body: some View {
        Group {
            if expanded || !browser.commandPane.searchQuery.isEmpty {
                FolderSearchField(browser: browser, focusWhenAttached: expanded, focusRequest: focusRequest, endedEditing: {
                    if browser.commandPane.searchQuery.isEmpty { expanded = false; focusRequest = nil }
                })
                .frame(minWidth: 140, idealWidth: 200, maxWidth: 260)
            } else {
                Button { expanded = true } label: {
                    Image(systemName: "magnifyingglass").frame(minWidth: 28, minHeight: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search current folder and subfolders")
                .help("Search current folder and subfolders")
            }
        }
        .onChange(of: browser.focusedPane) { _, _ in expanded = false; focusRequest = nil }
        .onChange(of: find.folderRequest) { _, request in expanded = true; focusRequest = request }
    }
}

/// Uses the native field editor for composition, cancellation and accessibility.
struct FolderSearchField: NSViewRepresentable {
    let browser: BrowserState
    var focusWhenAttached = false
    var focusRequest: UUID?
    var endedEditing: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(browser: browser, focusWhenAttached: focusWhenAttached, endedEditing: endedEditing)
    }
    func makeNSView(context: Context) -> NSSearchField { context.coordinator.field }
    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.endedEditing = endedEditing
        context.coordinator.update(browser: browser)
        if let focusRequest { context.coordinator.requestFocus(focusRequest) }
    }

    @MainActor final class Coordinator: NSObject, NSSearchFieldDelegate {
        let field = SearchInput()
        var endedEditing: () -> Void
        private var browser: BrowserState
        private var pane: PaneID
        private var lastFocusRequest: UUID?

        func requestFocus(_ request: UUID) {
            guard lastFocusRequest != request else { return }
            lastFocusRequest = request
            field.focusWhenAttached = true
            field.focusIfAttached()
        }

        init(browser: BrowserState, focusWhenAttached: Bool = false, endedEditing: @escaping () -> Void = {}) {
            self.browser = browser
            self.endedEditing = endedEditing
            pane = browser.focusedPane
            super.init()
            field.focusWhenAttached = focusWhenAttached
            field.placeholderString = "Search folder and subfolders"
            field.sendsSearchStringImmediately = true
            field.sendsWholeSearchString = false
            field.delegate = self
            field.target = self
            field.action = #selector(submit)
            field.setAccessibilityLabel("Search current folder and subfolders")
            field.setAccessibilityIdentifier("folder-search")
            field.setAccessibilityHelp("Search file and folder names beneath the active folder. Clear search to stop and restore its listing.")
            update(browser: browser)
        }

        func update(browser: BrowserState) {
            let changed = pane != browser.focusedPane
            if changed { field.abortEditing() }
            self.browser = browser
            pane = browser.focusedPane
            if !changed, (field.currentEditor() as? NSTextView)?.hasMarkedText() == true { return }
            let query = browser.pane(pane).searchQuery
            if field.stringValue != query { field.stringValue = query }
        }

        func controlTextDidChange(_ notification: Notification) { submit() }

        func controlTextDidEndEditing(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.field.window, window.attachedSheet == nil else { return }
                self.endedEditing()
            }
        }

        @objc func submit() {
            guard (field.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
            if !browser.search(field.stringValue, in: pane) {
                field.stringValue = browser.pane(pane).searchQuery
            }
        }
    }

    @MainActor final class SearchInput: NSSearchField {
        var focusWhenAttached = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            focusIfAttached()
        }

        func focusIfAttached() {
            guard let window, focusWhenAttached else { return }
            focusWhenAttached = false
            window.makeFirstResponder(self)
        }
    }
}
