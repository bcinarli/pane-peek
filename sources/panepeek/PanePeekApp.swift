import SwiftUI

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

    var body: some Commands {
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

extension FocusedValues {
    var enclosingFolderAction: (() -> Void)? {
        get { self[EnclosingFolderActionKey.self] }
        set { self[EnclosingFolderActionKey.self] = newValue }
    }
}
