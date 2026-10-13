import SwiftUI
import PanePeekCore

private typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct PanePeekApp: App {
    @NSApplicationDelegateAdaptor(BrowserLifecycle.self) private var lifecycle
    @ViewState<Favourites> private var favourites = Favourites(preferences: .standard)

    var body: some Scene {
        Window("PanePeek", id: "browser") {
            BrowserWindow(favourites: favourites, lifecycle: lifecycle)
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
    @FocusedValue(\.detailsSizing) private var detailsSizing
    @FocusedValue(\.browserState) private var browserState
    @FocusedValue(\.openInFinderAction) private var openInFinderAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open in Finder") { openInFinderAction?() }
                .disabled(openInFinderAction == nil)
            Divider()
            NewItemMenuItems(keyboardShortcuts: true) { browserState?.beginCreation($0) }
                .disabled(browserState == nil || browserState?.isDragging == true || browserState?.isCreating == true || browserState?.isRenaming == true || browserState?.isCopying == true || browserState?.isMoving == true || browserState?.isTrashing == true
                          || browserState?.creationRequest != nil || browserState?.renameRequest != nil)
            Button("Rename…") {
                guard let browserState else { return }
                Task { await browserState.beginRename() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(browserState?.canRename() != true)
            Divider()
            Button("Move to Trash…") {
                guard let browserState else { return }
                let id = browserState.focusedPane
                let items = browserState.pane(id).selectedItems
                Task { await browserState.moveToTrash(from: id, items: items) }
            }
            .disabled(browserState?.canTrash() != true)
        }
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
            Picker("Browser layout", selection: Binding(
                get: { browserState?.mode ?? .twoPanes }, set: { browserState?.setMode($0) }
            )) {
                Text("One Pane").tag(BrowserMode.onePane)
                Text("Two Panes").tag(BrowserMode.twoPanes)
            }
            .pickerStyle(.inline)
            .disabled(browserState == nil)
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

private struct BrowserStateKey: FocusedValueKey {
    typealias Value = BrowserState
}

extension FocusedValues {
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
