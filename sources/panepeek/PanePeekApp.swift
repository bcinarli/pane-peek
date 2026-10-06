import SwiftUI
import PanePeekCore

@main
struct PanePeekApp: App {
    var body: some Scene {
        Window("PanePeek", id: "browser") {
            BrowserWindow()
        }
        .defaultSize(width: 1100, height: 650)
        .windowResizability(.contentMinSize)
        .commands { BrowserCommands() }
    }
}

private struct BrowserCommands: Commands {
    @FocusedValue(\.enclosingFolderAction) private var enclosingFolderAction
    @FocusedValue(\.directoryPane) private var directoryPane

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Refresh") {
                guard let pane = directoryPane else { return }
                Task { await pane.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(directoryPane == nil)
            Toggle("Show Hidden Files", isOn: Binding(
                get: { directoryPane?.showHiddenFiles ?? false },
                set: { directoryPane?.showHiddenFiles = $0 }
            ))
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .disabled(directoryPane == nil)
        }
        CommandMenu("Go") {
            Button("Enclosing Folder") { enclosingFolderAction?() }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(enclosingFolderAction == nil)
        }
    }
}

private struct EnclosingFolderActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct DirectoryPaneKey: FocusedValueKey {
    typealias Value = DirectoryPane
}

extension FocusedValues {
    var directoryPane: DirectoryPane? {
        get { self[DirectoryPaneKey.self] }
        set { self[DirectoryPaneKey.self] = newValue }
    }

    var enclosingFolderAction: (() -> Void)? {
        get { self[EnclosingFolderActionKey.self] }
        set { self[EnclosingFolderActionKey.self] = newValue }
    }
}
