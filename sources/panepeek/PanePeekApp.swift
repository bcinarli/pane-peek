import SwiftUI
import PanePeekCore

private typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct PanePeekApp: App {
    @NSApplicationDelegateAdaptor(BrowserLifecycle.self) private var lifecycle
    @ViewState<Favourites> private var favourites = Favourites(preferences: .standard)

    var body: some Scene {
        Window("PanePeek", id: "browser") {
            BrowserWindow(favourites: favourites)
        }
        .defaultSize(width: 1100, height: 650)
        .windowResizability(.contentMinSize)
        .commands { BrowserCommands(favourites: favourites) }
    }
}

private struct BrowserCommands: Commands {
    let favourites: Favourites
    @FocusedValue(\.enclosingFolderAction) private var enclosingFolderAction
    @FocusedValue(\.directoryPane) private var directoryPane
    @FocusedValue(\.openFavourite) private var openFavourite

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Copy Absolute Path") {
                guard let pane = directoryPane else { return }
                PathClipboard.copy(pane.copiedPaths())
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(directoryPane?.selectedItems.isEmpty != false)
            Button("Copy Relative Path") {
                guard let pane = directoryPane else { return }
                PathClipboard.copy(pane.copiedPaths(relative: true))
            }
            .keyboardShortcut("c", modifiers: [.command, .option, .shift])
            .disabled(directoryPane?.selectedItems.isEmpty != false)
        }
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
            Divider()
            Button("Copy Directory Path") {
                guard let pane = directoryPane else { return }
                PathClipboard.copy(CopiedPaths.string(for: [pane.directory]))
            }
            .disabled(directoryPane == nil)
        }
        CommandMenu("Favourites") {
            FavouriteMenuItems(favourites: favourites, open: openFavourite)
        }
    }
}

private struct EnclosingFolderActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct DirectoryPaneKey: FocusedValueKey {
    typealias Value = DirectoryPane
}

private struct OpenFavouriteKey: FocusedValueKey {
    typealias Value = (URL) -> Void
}

extension FocusedValues {
    var openFavourite: ((URL) -> Void)? {
        get { self[OpenFavouriteKey.self] }
        set { self[OpenFavouriteKey.self] = newValue }
    }

    var directoryPane: DirectoryPane? {
        get { self[DirectoryPaneKey.self] }
        set { self[DirectoryPaneKey.self] = newValue }
    }

    var enclosingFolderAction: (() -> Void)? {
        get { self[EnclosingFolderActionKey.self] }
        set { self[EnclosingFolderActionKey.self] = newValue }
    }
}
