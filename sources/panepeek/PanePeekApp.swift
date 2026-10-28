import SwiftUI
import PanePeekCore

private typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct PanePeekApp: App {
    @NSApplicationDelegateAdaptor(BrowserLifecycle.self) private var lifecycle
    @ViewState<Favourites> private var favourites = Favourites(preferences: .standard)

    var body: some Scene {
        let title = FolderAccess.isReview ? "PanePeek Sandbox Review" : "PanePeek"
        WindowGroup(title, id: "browser") {
            BrowserWindow(title: title, favourites: favourites, lifecycle: lifecycle)
        }
        .restorationBehavior(.disabled)
        .defaultSize(width: 1100, height: 650)
        .windowResizability(.contentMinSize)
        .commands { BrowserCommands(favourites: favourites, updates: lifecycle.updates, checkForUpdates: lifecycle.checkForUpdates) }
    }
}

private struct BrowserCommands: Commands {
    let favourites: Favourites
    let updates: AppUpdates
    let checkForUpdates: () -> Void
    @ViewState private var fileMenu = BrowserFileMenuState()
    @FocusedValue(\.enclosingFolderAction) private var enclosingFolderAction
    @FocusedValue(\.directoryPane) private var directoryPane
    @FocusedValue(\.openFavourite) private var openFavourite
    @FocusedValue(\.detailsSizing) private var detailsSizing
    @FocusedValue(\.browserState) private var browserState
    @FocusedValue(\.openInFinderAction) private var openInFinderAction
    @FocusedValue(\.columnWidthsAction) private var columnWidthsAction
    @FocusedValue(\.browserFind) private var browserFind

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About PanePeek") { AboutPanel.show() }
            if updates.isEnabled {
                Button("Check for Updates…", action: checkForUpdates)
                Toggle("Automatically Check for Updates", isOn: Binding(
                    get: { updates.automaticChecking }, set: { updates.setAutomaticChecking($0) }
                ))
            }
        }
        CommandGroup(after: .newItem) {
            Button("Reveal in Finder") { openInFinderAction?() }
                .disabled(openInFinderAction == nil)
            Divider()
            NewItemMenuItems(keyboardShortcuts: true) { browserState?.beginCreation($0) }
                .disabled(browserState?.canCreate() != true)
            Button("Rename…") {
                guard let browserState else { return }
                Task { await browserState.beginRename() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(browserState?.canRename() != true)
            Divider()
            Button("Move to Trash") { fileMenu.trash() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!fileMenu.canTrash)
        }
        CommandGroup(after: .pasteboard) {
            Button("Find…") { browserFind?.find() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(browserFind?.canFind != true)
            Divider()
            Button("Move Item Here") { fileMenu.move() }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(!fileMenu.canMove)
            Divider()
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
            Picker("Browser layout", selection: Binding(
                get: { browserState?.mode ?? .twoPanes }, set: { browserState?.setMode($0) }
            )) {
                Text("One Pane").tag(BrowserMode.onePane)
                Text("Two Panes").tag(BrowserMode.twoPanes)
            }
            .pickerStyle(.inline)
            .disabled(browserState == nil)
            Divider()
            Button("Column Widths…") { columnWidthsAction?() }
                .disabled(columnWidthsAction == nil)
            Divider()
            Button(detailsSizing?.isExpanded == true ? "Restore Previous Details Width" : "Expand Details") {
                detailsSizing?.toggleExpansion()
            }
            .disabled(detailsSizing == nil)
            Button("Make Details Wider") { detailsSizing?.adjust(by: 10) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
                .disabled(detailsSizing == nil)
            Button("Make Details Narrower") { detailsSizing?.adjust(by: -10) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .control])
                .disabled(detailsSizing == nil)
            Divider()
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
            Button("Search Current Folder") { browserFind?.searchFolder() }
                .disabled(browserFind?.canSearchFolder != true)
            Divider()
            Button("Back") { browserState?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(browserState?.commandPane.canGoBack != true)
            Button("Forward") { browserState?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(browserState?.commandPane.canGoForward != true)
            Divider()
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

private struct OpenInFinderActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct DirectoryPaneKey: FocusedValueKey {
    typealias Value = DirectoryPane
}

private struct OpenFavouriteKey: FocusedValueKey {
    typealias Value = (URL) -> Void
}

private struct DetailsSizingKey: FocusedValueKey {
    typealias Value = DetailsSizing
}

private struct ColumnWidthsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct BrowserStateKey: FocusedValueKey {
    typealias Value = BrowserState
}

private struct BrowserFindKey: FocusedValueKey {
    typealias Value = BrowserFind
}

extension FocusedValues {
    var browserFind: BrowserFind? {
        get { self[BrowserFindKey.self] }
        set { self[BrowserFindKey.self] = newValue }
    }
    var columnWidthsAction: (() -> Void)? {
        get { self[ColumnWidthsActionKey.self] }
        set { self[ColumnWidthsActionKey.self] = newValue }
    }

    var openInFinderAction: (() -> Void)? {
        get { self[OpenInFinderActionKey.self] }
        set { self[OpenInFinderActionKey.self] = newValue }
    }

    var browserState: BrowserState? {
        get { self[BrowserStateKey.self] }
        set { self[BrowserStateKey.self] = newValue }
    }

    var detailsSizing: DetailsSizing? {
        get { self[DetailsSizingKey.self] }
        set { self[DetailsSizingKey.self] = newValue }
    }

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
