import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PanePeekCore

// Select the property wrapper on SDKs that also expose a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>
private let panelHeaderHeight: CGFloat = 52

struct BrowserWindow: View {
    let favourites: Favourites
    @ViewState<BrowserState> private var browser = BrowserState()
    @ViewState<Bool> private var showingPathEntry = false
    @ViewState<Bool> private var showingChooser = false
    @ViewState<PaneID> private var navigationTarget = .left
    @ViewState<String> private var directoryPath = ""
    @ViewState<String?> private var chooserError: String?
    @Environment(\.scenePhase) private var scenePhase

    private let accent = Color("accent")

    private var enclosingFolderAction: (() -> Void)? {
        guard browser.pane(browser.focusedPane).directory.path != "/" else { return nil }
        return { openEnclosingFolder() }
    }

    var body: some View {
        BrowserSplitView(
            left: PaneArea(browser: browser, favourites: favourites, id: .left, accent: accent)
                .tint(accent)
                .environment(\.scenePhase, scenePhase),
            right: PaneArea(browser: browser, favourites: favourites, id: .right, accent: accent)
                .tint(accent)
                .environment(\.scenePhase, scenePhase),
            details: DetailsSidebar(item: browser.primaryItem).tint(accent)
        )
        .frame(minWidth: 800, minHeight: 480)
        .tint(accent)
        .focusedSceneValue(\.enclosingFolderAction, enclosingFolderAction)
        .focusedSceneValue(\.directoryPane, browser.pane(browser.focusedPane))
        .focusedSceneValue(\.openFavourite, { directory in browser.openFavourite(directory) })
        .toolbar {
            ToolbarItem {
                Button {
                    navigationTarget = browser.focusedPane
                    directoryPath = browser.pane(navigationTarget).directory.path
                    showingPathEntry = true
                } label: {
                    Label("Go to Folder…", image: "icon-folder-open")
                }
                .keyboardShortcut("l", modifiers: .command)
                .help("Go to Folder (⌘L)")
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem {
                Menu {
                    FavouriteMenuItems(favourites: favourites, open: { directory in
                        browser.openFavourite(directory)
                    })
                } label: {
                    Label("Favourites", image: "icon-star")
                }
                .accessibilityLabel("Favourites")
                .help("Favourites")
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem {
                Menu {
                    Button("Choose Folder…") {
                        navigationTarget = browser.focusedPane
                        showingChooser = true
                    }
                    Button("Enclosing Folder", action: openEnclosingFolder)
                    .disabled(browser.pane(browser.focusedPane).directory.path == "/")
                    Divider()
                    Toggle("Show Hidden Files", isOn: Binding(
                        get: { browser.pane(browser.focusedPane).showHiddenFiles },
                        set: { browser.pane(browser.focusedPane).showHiddenFiles = $0 }
                    ))
                    Button("Refresh") {
                        let pane = browser.pane(browser.focusedPane)
                        Task { await pane.refresh() }
                    }
                    Divider()
                    Button("Copy Directory Path") {
                        let pane = browser.pane(browser.focusedPane)
                        PathClipboard.copy(CopiedPaths.string(for: [pane.directory]))
                    }
                } label: {
                    Label("Directory actions", image: "icon-sliders-horizontal")
                }
                .accessibilityLabel("Directory actions")
                .help("Directory actions")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $showingPathEntry) {
            DirectoryPathEntry(path: $directoryPath) {
                let pane = browser.pane(navigationTarget)
                let path = directoryPath
                showingPathEntry = false
                Task { await pane.navigate(toPath: path) }
            }
        }
        .fileImporter(isPresented: $showingChooser, allowedContentTypes: [.folder]) { result in
            let pane = browser.pane(navigationTarget)
            switch result {
            case .success(let directory):
                Task { await pane.navigate(to: directory) }
            case .failure(let error):
                // Cancelling the chooser leaves navigation unchanged.
                if (error as NSError).code != NSUserCancelledError {
                    chooserError = error.localizedDescription
                }
            }
        }
        .alert("Couldn’t choose a folder", isPresented: Binding(
            get: { chooserError != nil }, set: { if !$0 { chooserError = nil } }
        )) {
            Button("OK") { chooserError = nil }
        } message: {
            Text(chooserError ?? "")
        }
        .task {
            async let left: Void = browser.left.navigate(to: browser.homeDirectory)
            async let right: Void = browser.right.navigate(to: browser.homeDirectory)
            _ = await (left, right)
        }
    }

    private func openEnclosingFolder() {
        let pane = browser.pane(browser.focusedPane)
        let parent = pane.directory.deletingLastPathComponent()
        Task { await pane.navigate(to: parent) }
    }
}

private struct PaneArea: View {
    let browser: BrowserState
    let favourites: Favourites
    let id: PaneID
    let accent: Color
    @ViewState<URL?> private var interactedItem: URL?
    @FocusState private var listFocused: Bool
    @ViewState<Date> private var dateRefreshStart = .now
    @Environment(\.scenePhase) private var scenePhase
    private let modifiedColumnWidth: CGFloat = 136

    private var pane: DirectoryPane { browser.pane(id) }
    private var accessibilityName: String { id == .left ? "Left directory pane" : "Right directory pane" }

    var body: some View {
        let saved = favourites.contains(pane.directory)
        let favouriteAction = saved ? "Remove directory from favourites" : "Add directory to favourites"
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    browser.focus(id)
                    Task { await pane.navigate(to: browser.homeDirectory) }
                } label: {
                    Image("icon-house")
                }
                .buttonStyle(.borderless)
                .help("Home")
                .accessibilityLabel("Home in \(accessibilityName.lowercased())")

                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(pane.breadcrumbDirectories, id: \.path) { directory in
                            if directory.path != "/" {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            Button {
                                browser.focus(id)
                                Task { await pane.navigate(to: directory) }
                            } label: {
                                Text(directory.path == "/" ? "/" : directory.lastPathComponent)
                                    .fixedSize()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(directory.path == pane.directory.path ? .primary : .secondary)
                            .help(directory.path)
                            .accessibilityLabel(directory.path == "/"
                                ? "Filesystem root in \(accessibilityName.lowercased())"
                                : "Go to \(directory.lastPathComponent) in \(accessibilityName.lowercased())")
                            .accessibilityValue(directory.path)
                        }
                    }
                    .font(.body)
                    // Centre the labels while leaving room below for the native scroller.
                    .padding(.vertical, 16)
                    .frame(height: panelHeaderHeight)
                }
                .defaultScrollAnchor(.trailing)
                .defaultScrollAnchor(.leading, for: .alignment)
                .id(pane.directory.path)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: panelHeaderHeight)
                .help(pane.directory.path)
                .accessibilityLabel("Directory breadcrumbs")

                Button {
                    favourites.toggle(pane.directory)
                } label: {
                    Image(saved ? "icon-star-filled" : "icon-star")
                        .foregroundStyle(saved ? accent : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(favouriteAction)
                .accessibilityLabel("\(favouriteAction) in \(accessibilityName.lowercased())")
                .accessibilityValue(saved ? "Saved" : "Not saved")

                if pane.isLoading {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Loading directory")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: panelHeaderHeight)
            .background(.bar)
            .overlay(alignment: .bottom) {
                Rectangle().fill(browser.focusedPane == id ? accent : .clear).frame(height: 2)
            }

            Divider()

            HStack(spacing: 8) {
                sortHeader(.name, title: "Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
                sortHeader(.lastModified, title: "Modified")
                    .frame(width: modifiedColumnWidth, alignment: .trailing)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .frame(height: 36)

            Divider()

            if let error = pane.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .help(error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.bar)
            }

            TimelineView(.periodic(from: dateRefreshStart, by: 60)) { _ in
                // Refresh can load dates newer than the timeline's last tick.
                directoryList(at: .now)
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                dateRefreshStart = .now
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { dateRefreshStart = .now }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(browser.focusedPane == id ? "Focused" : "")
    }

    private func sortHeader(_ field: DirectorySortField, title: String) -> some View {
        Button {
            browser.focus(id)
            Task { await pane.sort(by: field) }
        } label: {
            HStack(spacing: 4) {
                if field == .name { Text(title) }
                if pane.sortField == field {
                    Image(systemName: pane.sortDirection == .ascending ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                if field == .lastModified { Text(title) }
            }
            .frame(maxWidth: .infinity, alignment: field == .name ? .leading : .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Sort by \(title) in \(accessibilityName.lowercased())")
        .accessibilityValue(pane.sortField == field
            ? (pane.sortDirection == .ascending ? "Ascending" : "Descending") : "Not sorted")
        .help(pane.sortField == field
            ? (pane.sortDirection == .ascending ? "Sort descending" : "Sort ascending")
            : (field == .name ? "Sort by name, ascending" : "Sort by modified date, newest first"))
    }

    private func directoryList(at now: Date) -> some View {
        List(pane.entries, selection: Binding(
            get: { pane.selectedItems },
            set: { items in
                guard items != pane.selectedItems else { return }
                browser.focus(id)
                if items == Set(pane.entries.map(\.url)) {
                    pane.selectAll()
                } else {
                    pane.setSelection(items)
                }
            }
        )) { entry in
            let modifiedLabel = ModifiedDateDisplay.string(for: entry.modifiedDate, relativeTo: now)
            let exactModified = entry.modifiedDate?.formatted(date: .complete, time: .complete) ?? "Unavailable"
            HStack(spacing: 8) {
                Group {
                    if entry.isSymbolicLink {
                        Image(systemName: "link")
                    } else if entry.isPackage {
                        Image(systemName: "shippingbox")
                    } else {
                        Image(entry.isDirectory ? "icon-folder" : "icon-file-text")
                    }
                }
                .frame(width: 16)
                .accessibilityHidden(true)
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(modifiedLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: modifiedColumnWidth, alignment: .trailing)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
            .listRowSeparator(.hidden)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(entry.name)
            .accessibilityValue("\(entryType(entry)). Modified: \(modifiedLabel). Last modified: \(exactModified)")
            .contentShape(Rectangle())
            .help("\(entry.name)\n\(entryType(entry))\nLast modified: \(exactModified)")
            .tag(entry.url)
            .simultaneousGesture(TapGesture().onEnded {
                followInteraction(entry.url)
            })
            .overlay {
                ItemPathContextMenu {
                    browser.targetContextItem(entry.url, in: id)
                    interactedItem = entry.url
                    listFocused = true
                    return (pane.copiedPaths(), pane.copiedPaths(relative: true))
                }
                .accessibilityHidden(true)
            }
        }
        .listStyle(.plain)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .focused($listFocused)
        .contextMenu(forSelectionType: URL.self) { _ in
            EmptyView()
        } primaryAction: { items in
            guard items.count == 1,
                  let entry = pane.entries.first(where: { items.contains($0.url) }) else {
                return
            }
            open(entry)
        }
        .overlay {
            if pane.entries.isEmpty {
                ContentUnavailableView(
                    pane.isLoading ? "Loading…" : (pane.hasLoaded ? "No items" : "No directory loaded"),
                    systemImage: "folder"
                )
                .allowsHitTesting(false)
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            browser.focus(id)
            listFocused = true
        })
        .onKeyPress(keys: [.upArrow, .downArrow], phases: [.down, .repeat]) { press in
            if !press.modifiers.contains(.command) { followKeyboardFocus(press.key) }
            return .ignored
        }
        .onKeyPress(.escape) {
            pane.setSelection([])
            interactedItem = nil
            return .handled
        }
        .onChange(of: pane.directory) { interactedItem = nil }
        .onChange(of: pane.entries) { oldEntries, entries in
            guard let index = oldEntries.firstIndex(where: { $0.url == interactedItem }),
                  !entries.contains(where: { $0.url == interactedItem }) else { return }
            // Native keyboard focus stays at the removed row's visible position.
            interactedItem = entries.isEmpty ? nil : entries[min(index, entries.count - 1)].url
        }
        .onChange(of: listFocused) { _, focused in
            if focused { browser.focus(id) }
        }
    }

    private func followKeyboardFocus(_ key: KeyEquivalent) {
        let entries = pane.entries
        let current = interactedItem ?? pane.primaryItemURL
        guard let index = entries.firstIndex(where: { $0.url == current }) else { return }
        let next = key == .upArrow ? max(0, index - 1) : min(entries.count - 1, index + 1)
        followInteraction(entries[next].url)
    }

    private func followInteraction(_ url: URL) {
        browser.focus(id)
        interactedItem = url
        let directory = pane.directory
        // Let native selection finish before following the interacted row.
        DispatchQueue.main.async {
            guard pane.directory == directory else { return }
            pane.setSelection(pane.selectedItems, focusedItem: url)
        }
    }

    private func open(_ entry: DirectoryEntry) {
        browser.focus(id)
        guard entry.isDirectory else { return }
        Task { await pane.navigate(to: entry.url) }
    }

    private func entryType(_ entry: DirectoryEntry) -> String {
        let type = entry.isPackage ? "Package" : (entry.isDirectory ? "Folder" : "File")
        return entry.isSymbolicLink ? "\(type) link" : type
    }
}

private struct DirectoryPathEntry: View {
    @Binding var path: String
    let go: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var pathFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Go to Folder").font(.headline)
            TextField("Absolute directory path", text: $path)
                .textFieldStyle(.roundedBorder)
                .focused($pathFocused)
                .onSubmit(go)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Go", action: go).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { pathFocused = true }
    }
}

private struct DetailsSidebar: View {
    let item: DirectoryEntry?

    var body: some View {
        VStack(spacing: 0) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: panelHeaderHeight)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ContentUnavailableView(
                        item?.name ?? "No item selected",
                        systemImage: "doc.text.magnifyingglass",
                        description: item == nil ? nil : Text("Preview is not available yet.")
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 236)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))

                    Divider()

                    if let item {
                        let path = CopiedPaths.string(for: [item.url])
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Absolute path").font(.headline)
                                Spacer()
                                Button {
                                    PathClipboard.copy(path)
                                } label: {
                                    Label("Copy selected absolute path", image: "icon-copy")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .help("Copy absolute path")
                            }
                            Text(path)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("Selected absolute path")
                                .accessibilityValue(path)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("File information")
                            .font(.headline)
                        Text(item == nil ? "Select an item to see its details." : "File information is not available yet.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Details sidebar")
    }
}
