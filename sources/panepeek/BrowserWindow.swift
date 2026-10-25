import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PanePeekCore

// Select the property wrapper on SDKs that also expose a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>
private let panelHeaderHeight: CGFloat = 52
@MainActor private let chromeBackground = Color(nsColor: AppColours.chrome)
@MainActor private let paperBackground = Color(nsColor: AppColours.paper)

struct BrowserWindow: View {
    let title: String
    let favourites: Favourites
    let lifecycle: BrowserLifecycle
    @ViewState<BrowserPrompts> private var prompts: BrowserPrompts
    @ViewState<BrowserState> private var browser: BrowserState
    @ViewState<DetailsSizing> private var detailsSizing = DetailsSizing()
    @ViewState<Bool> private var showingPathEntry = false
    @ViewState<Bool> private var showingChooser = false
    @ViewState<Bool> private var showingFavourites = false
    @ViewState<PaneID> private var navigationTarget = .left
    @ViewState<String> private var directoryPath = ""
    @ViewState<String?> private var chooserError: String?
    @ViewState<String?> private var finderError: String?
    @Environment(\.scenePhase) private var scenePhase

    private let accent = Color("accent")

    init(title: String, favourites: Favourites, lifecycle: BrowserLifecycle) {
        self.title = title
        self.favourites = favourites
        self.lifecycle = lifecycle
        let prompts = BrowserPrompts()
        _prompts = ViewState(initialValue: prompts)
        if FolderAccess.isSandboxed() {
            let access = lifecycle.folderAccess
            _browser = ViewState(initialValue: BrowserState(
                homeDirectory: FolderAccess.accountHome ?? URL(fileURLWithPath: "/", isDirectory: true),
                requiresFolderAccess: true,
                acquireOperationAccess: { [weak prompts] directory, mode in
                    if mode == .readOnly {
                        return try await access.readAccess(for: directory) { initial in
                            try await FolderAccess.chooseFolder(initial: initial, window: prompts?.window, purpose: .reading)
                        }
                    }
                    return try await access.writeAccess(for: directory) { initial in
                        try await FolderAccess.chooseFolder(initial: initial, window: prompts?.window, purpose: .managing)
                    }
                },
                load: { url in
                    try await access.read(url) { [weak prompts] initial in
                        try await FolderAccess.chooseFolder(initial: initial, window: prompts?.window)
                    }
                }, loadHistory: { url in
                    try await access.read(url, exact: true) { [weak prompts] initial in
                        try await FolderAccess.chooseFolder(initial: initial, window: prompts?.window)
                    }
                }, operations: lifecycle.operations,
                preview: PreviewState(acquireWriteAccess: { [weak prompts] selection in
                    try await access.writeAccess(for: selection.item.url.deletingLastPathComponent()) { initial in
                        try await FolderAccess.chooseFolder(initial: initial, window: prompts?.window, purpose: .editing)
                    }
                }, write: { snapshot, text, url in
                    try await snapshot.save(text, to: url, quarantine: .systemManaged)
                }), resolveTransferCollision: prompts.resolveTransferCollision, confirmChanges: prompts.confirmChanges))
        } else {
            _browser = ViewState(initialValue: BrowserState(operations: lifecycle.operations, resolveTransferCollision: prompts.resolveTransferCollision,
                                                           confirmChanges: prompts.confirmChanges))
        }
    }

    private var enclosingFolderAction: (() -> Void)? {
        guard browser.pane(browser.focusedPane).directory.path != "/" else { return nil }
        return { openEnclosingFolder() }
    }

    private var finderAction: (() -> Void)? {
        let pane = browser.commandPane
        guard !browser.requiresFolderAccess || pane.directoryAccess != nil else { return nil }
        let items = pane.entries.filter { pane.selectedItems.contains($0.url) }
        guard !items.isEmpty else { return nil }
        let access = pane.directoryAccess
        return { openInFinder(items, access) }
    }

    private var browserContent: some View {
        BrowserSplitView(
            left: PaneArea(browser: browser, favourites: favourites, id: .left, accent: accent, openInFinder: openInFinder, toggleFavourite: toggleFavourite, chooseFolder: { chooseFolder(in: .left) })
                .tint(accent)
                .environment(\.scenePhase, scenePhase),
            right: PaneArea(browser: browser, favourites: favourites, id: .right, accent: accent, openInFinder: openInFinder, toggleFavourite: toggleFavourite, chooseFolder: { chooseFolder(in: .right) })
                .tint(accent)
                .environment(\.scenePhase, scenePhase),
            details: DetailsSidebar(selection: browser.detailsSelection, preview: browser.preview, sizing: detailsSizing).tint(accent),
            sizing: detailsSizing, visiblePanes: browser.visiblePanes,
            preferredWidth: detailsSizing.preferredWidth, isExpanded: detailsSizing.isExpanded,
            browserProportion: detailsSizing.browserProportion
        )
        .frame(minWidth: WindowGeometry.minimumContentSize.width, minHeight: WindowGeometry.minimumContentSize.height)
        .tint(accent)
        .toolbar(removing: .title)
        .background {
            BrowserWindowGuard(browser: browser, sizing: detailsSizing, prompts: prompts, lifecycle: lifecycle,
                               quickLookSelection: QuickLookSelection(pane: browser.commandPane, requiringAccess: browser.requiresFolderAccess))
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            OperationToasts(notifications: browser.notifications, prompts: prompts).padding(16)
        }
        .onChange(of: browser.left.recoveryMessage) { _, message in announceRecovery(message) }
        .onChange(of: browser.right.recoveryMessage) { _, message in announceRecovery(message) }
        .focusedSceneValue(\.enclosingFolderAction, enclosingFolderAction)
        .focusedSceneValue(\.openInFinderAction, finderAction)
        .focusedSceneValue(\.directoryPane, browser.commandPane)
        .focusedSceneValue(\.browserState, browser)
        .focusedSceneValue(\.openFavourite, openFavourite)
        .focusedSceneValue(\.detailsSizing, detailsSizing)
        .focusedSceneValue(\.columnWidthsAction, { ColumnWidthsPanel.show(in: prompts.window, browser: browser) })
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(title)
                    .font(.headline)
                    .fixedSize()
                    .allowsHitTesting(false)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    Button { browser.goBack() } label: {
                        Label("Back", systemImage: "chevron.left").frame(minWidth: 28, minHeight: 28)
                    }
                        .disabled(!browser.commandPane.canGoBack)
                        .help("Back (⌘[)")
                    Button { browser.goForward() } label: {
                        Label("Forward", systemImage: "chevron.right").frame(minWidth: 28, minHeight: 28)
                    }
                        .disabled(!browser.commandPane.canGoForward)
                        .help("Forward (⌘])")
                }
                .buttonStyle(.plain)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .navigation) {
                FolderSearchControl(browser: browser)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarSpacer(.flexible)

            ToolbarItem {
                BrowserLayoutToggle(mode: Binding(
                    get: { browser.mode }, set: { browser.setMode($0) }
                ))
                .fixedSize()
            }
            .sharedBackgroundVisibility(.visible)

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
                Button { showingFavourites.toggle() } label: {
                    Label("Favourites", image: "icon-star")
                }
                .accessibilityLabel("Favourites")
                .help("Favourites")
                .popover(isPresented: $showingFavourites, arrowEdge: .bottom) {
                    FavouritesPopover(favourites: favourites) { directory in
                        openFavourite(directory)
                        showingFavourites = false
                    }
                }
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem {
                Menu {
                    Button("Choose Folder…") {
                        chooseFolder(in: browser.focusedPane)
                    }
                    Button("Enclosing Folder", action: openEnclosingFolder)
                    .disabled(browser.pane(browser.focusedPane).directory.path == "/")
                    Divider()
                    NewItemMenuItems { browser.beginCreation($0) }
                        .disabled(!browser.canCreate())
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
                    HStack {
                        Label("Directory actions", image: "icon-sliders-horizontal")
                        if browser.isCreating || browser.isRenaming || browser.isCopying || browser.isMoving || browser.isTrashing {
                            ProgressView().controlSize(.small)
                                .accessibilityLabel(browser.isTrashing ? "Moving selected items to Trash" : (browser.isMoving ? "Moving item" : (browser.isCopying ? "Copying item" : (browser.isRenaming ? "Renaming item" : "Creating item"))))
                        }
                    }
                }
                .accessibilityLabel("Directory actions")
                .help("Directory actions")
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    var body: some View {
        browserContent
        .sheet(isPresented: $showingPathEntry) {
            DirectoryPathEntry(path: $directoryPath) {
                guard browser.visiblePanes.contains(navigationTarget) else { showingPathEntry = false; return }
                let pane = browser.pane(navigationTarget)
                let path = directoryPath
                showingPathEntry = false
                Task { await pane.navigate(toPath: path) }
            }
        }
        .sheet(item: Binding(get: { browser.creationRequest }, set: {
            if $0 == nil, browser.creationRequest != nil { browser.cancelCreation() }
        })) { request in
            ItemNameEntry(request: request, error: browser.creationError, cancel: browser.cancelCreation) { name in
                Task { await browser.submitCreation(named: name) }
            }
        }
        .alert("Item rename", isPresented: Binding(
            get: { browser.renameRequest == nil && browser.renameError != nil },
            set: { if !$0 { browser.dismissRenameError() } }
        )) {
            Button("OK", action: browser.dismissRenameError)
        } message: {
            Text(browser.renameError ?? "")
        }
        .alert("Item creation", isPresented: Binding(
            get: { browser.creationRequest == nil && browser.creationError != nil },
            set: { if !$0 { browser.dismissCreationError() } }
        )) {
            Button("OK", action: browser.dismissCreationError)
        } message: {
            Text(browser.creationError ?? "")
        }
        .fileImporter(isPresented: $showingChooser, allowedContentTypes: [.folder]) { result in
            guard browser.visiblePanes.contains(navigationTarget) else { return }
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
        .alert("Couldn’t open in Finder", isPresented: Binding(
            get: { finderError != nil }, set: { if !$0 { finderError = nil } }
        )) {
            Button("OK") { finderError = nil }
        } message: {
            Text(finderError ?? "")
        }
        .task {
            await lifecycle.start(browser, sizing: detailsSizing)
        }
    }

    private func toggleFavourite(_ directory: URL) {
        if browser.requiresFolderAccess { lifecycle.folderAccess.toggleFavourite(directory, favourites: favourites) }
        else { favourites.toggle(directory) }
    }

    private func openFavourite(_ directory: URL) {
        guard browser.requiresFolderAccess else { browser.openFavourite(directory); return }
        let target = browser.commandPane
        Task {
            await lifecycle.folderAccess.openFavourite(directory, in: target, favourites: favourites) { [weak prompts] initial in
                try await FolderAccess.chooseFolder(initial: initial, window: prompts?.window)
            }
        }
    }

    private func chooseFolder(in id: PaneID) {
        guard browser.requiresFolderAccess else {
            navigationTarget = id
            showingChooser = true
            return
        }
        let pane = browser.pane(id)
        let revision = pane.navigationRevision
        Task {
            do {
                let grant = try await lifecycle.folderAccess.select(initial: pane.directory) { initial in
                    try await FolderAccess.chooseFolder(initial: initial, window: prompts.window)
                }
                guard let grant, pane.navigationRevision == revision else { return }
                await browser.navigate(to: grant.root, in: id)
            } catch is CancellationError {
                return
            } catch { chooserError = error.localizedDescription }
        }
    }

    private func openEnclosingFolder() {
        let pane = browser.pane(browser.focusedPane)
        let parent = pane.directory.deletingLastPathComponent()
        Task { await pane.navigate(to: parent) }
    }

    private func announceRecovery(_ message: String?) {
        guard let message, let window = prompts.window else { return }
        NSAccessibility.post(element: window, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    private func openInFinder(_ items: [DirectoryEntry], _ access: DirectoryAccess?) {
        guard !browser.requiresFolderAccess || access != nil else { return }
        Task {
            do { try await FinderOpening().open(items.map(\.url), access: access, followingLinks: !browser.requiresFolderAccess) }
            catch { finderError = error.localizedDescription }
        }
    }
}

struct PaneArea: View {
    let browser: BrowserState
    let favourites: Favourites
    let id: PaneID
    let accent: Color
    let openInFinder: ([DirectoryEntry], DirectoryAccess?) -> Void
    let toggleFavourite: (URL) -> Void
    var chooseFolder: () -> Void = {}
    @ViewState<Date> private var dateRefreshStart = .now
    @Environment(\.scenePhase) private var scenePhase
    private let iconColumnWidth: CGFloat = 28

    private var pane: DirectoryPane { browser.pane(id) }
    private var renameRequest: BrowserState.RenameRequest? {
        browser.renameRequest?.pane == id ? browser.renameRequest : nil
    }
    private var accessibilityName: String {
        if browser.mode == .onePane { return "Directory pane" }
        return browser.presentationOrder.first == id ? "Left directory pane" : "Right directory pane"
    }

    var body: some View {
        content
    }

    private var content: some View {
        let saved = favourites.contains(pane.directory)
        let favouriteAction = saved ? "Remove directory from favourites" : "Add directory to favourites"
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    Task { await browser.navigate(to: browser.homeDirectory, in: id) }
                } label: {
                    Image("icon-house")
                }
                .buttonStyle(.borderless)
                .help("Home")
                .disabled(browser.requiresFolderAccess && FolderAccess.accountHome == nil)
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
                                Task { await browser.navigate(to: directory, in: id) }
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
                    toggleFavourite(pane.directory)
                } label: {
                    Image(saved ? "icon-star-filled" : "icon-star")
                        .foregroundStyle(saved ? accent : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(favouriteAction)
                .disabled(browser.requiresFolderAccess && !saved && !pane.hasLoaded)
                .accessibilityLabel("\(favouriteAction) in \(accessibilityName.lowercased())")
                .accessibilityValue(saved ? "Saved" : "Not saved")

                if pane.isLoading {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Loading directory")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: panelHeaderHeight)
            .background(chromeBackground)
            .overlay(alignment: .bottom) {
                Rectangle().fill(browser.focusedPane == id ? accent : .clear).frame(height: 2)
            }

            Divider()

            if let error = pane.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .help(error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(chromeBackground)
            }

            if let message = pane.recoveryMessage {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .help(message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(chromeBackground)
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
        .background(paperBackground)
        .contentShape(Rectangle())
        .contextMenu {
            NewItemMenuItems { browser.beginCreation($0, in: id) }
                .disabled(!browser.canCreate(in: id))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(browser.focusedPane == id ? "Focused" : "")
    }

    private var emptyListingTitle: String {
        if pane.isLoading { return "Loading…" }
        if pane.isSearching { return "Searching…" }
        if !pane.searchQuery.isEmpty { return pane.searchMessage == nil ? "No matches" : "Search incomplete" }
        return pane.hasLoaded ? "No items" : "No directory loaded"
    }

    private func directoryList(at now: Date) -> some View {
        VStack(spacing: 0) {
            if !pane.searchQuery.isEmpty {
                HStack(spacing: 8) {
                    if pane.isSearching { ProgressView().controlSize(.small).accessibilityLabel("Searching subfolders") }
                    Text(pane.isSearching ? "Searching subfolders…" : "\(pane.entries.count) matches")
                    Spacer(minLength: 0)
                }
                .font(.callout).foregroundStyle(.secondary).padding(8)
                .accessibilityElement(children: .combine)
                .onChange(of: pane.isSearching) { _, searching in
                    if !searching {
                        NSAccessibility.post(element: NSApp, notification: .announcementRequested, userInfo: [
                            .announcement: "\(pane.entries.count) search matches. \(pane.searchMessage ?? "")",
                            .priority: NSAccessibilityPriorityLevel.medium.rawValue
                        ])
                    }
                }
                if let message = pane.searchMessage {
                    Text(message).font(.callout).fixedSize(horizontal: false, vertical: true).padding(8)
                }
            }
            DirectoryTable(browser: browser, id: id, entries: pane.entries,
                           selection: pane.selectedItems, renameID: renameRequest?.id) { entry, column, focusList in
                directoryCell(entry, column: column, at: now, focusList: focusList)
            }
            .overlay {
                if pane.entries.isEmpty {
                    if browser.requiresFolderAccess && !pane.hasLoaded && !pane.isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus").font(.largeTitle).accessibilityHidden(true)
                            Text(pane.errorMessage == nil ? "Choose Folder Access" : "Reconnect Folder").font(.headline)
                            Text(pane.errorMessage == nil
                                 ? "Allow your Home folder or choose a smaller folder to browse."
                                 : "The saved folder is unavailable. Reconnect it or choose another folder.")
                                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                            Button("Allow Home Folder") {
                                Task {
                                    await browser.navigate(to: browser.homeDirectory, in: id)
                                    let other: PaneID = id == .left ? .right : .left
                                    if pane.hasLoaded, pane.directory.path == browser.homeDirectory.path,
                                       !browser.pane(other).hasLoaded, !browser.pane(other).isLoading {
                                        await browser.pane(other).navigate(to: browser.homeDirectory)
                                    }
                                }
                            }
                            .disabled(FolderAccess.accountHome == nil)
                            Button(pane.errorMessage == nil ? "Open Folder…" : "Reconnect…", action: chooseFolder)
                        }
                        .padding(20)
                    } else {
                        ContentUnavailableView(
                            emptyListingTitle,
                            systemImage: "folder"
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private func directoryCell(_ entry: DirectoryEntry, column: DirectorySortField, at now: Date, focusList: @escaping () -> Void) -> some View {
        let modifiedLabel = ModifiedDateDisplay.string(for: entry.modifiedDate, relativeTo: now)
        let exactModified = entry.modifiedDate?.formatted(date: .complete, time: .complete) ?? "Unavailable"
        let sizeLabel = FileSizeDisplay.string(for: entry.size)
        let exactSize = entry.size.map { "\($0.formatted()) \($0 == 1 ? "byte" : "bytes")" }
            ?? (entry.isDirectory || entry.isPackage ? "Not calculated" : "Unavailable")
        return HStack(spacing: 8) {
            if column == .name {
                HStack(spacing: 2) {
                    DirectoryEntryIcon(entry).image
                        .frame(width: 16)
                    if entry.isHidden {
                        Image("icon-eye-off")
                            .resizable()
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: iconColumnWidth, alignment: .leading)
                .accessibilityHidden(true)
                if let request = renameRequest, request.item.url == entry.url {
                    VStack(alignment: .leading, spacing: 3) {
                        InlineNameEditor(requestID: request.id, name: browser.renameName,
                                         isDirectory: entry.isDirectory, isWorking: browser.isRenaming,
                                         changed: browser.updateRenameName,
                                         submit: { name in Task { await browser.submitRename(named: name) } },
                                         cancel: browser.cancelRename, blurred: browser.endRenameEditing)
                            .id(request.id)
                            .frame(height: 24)
                        if let error = browser.renameError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(4)
                                .background(paperBackground, in: RoundedRectangle(cornerRadius: 4))
                                .help(error)
                                .accessibilityLabel("Rename error: \(error)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name).lineLimit(1).truncationMode(.middle)
                        if !pane.searchQuery.isEmpty {
                            let relative = pane.relativeSearchPath(for: entry)
                            let parent = (relative as NSString).deletingLastPathComponent
                            Text(parent.isEmpty ? "Current folder" : parent)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if column == .size {
                Text(sizeLabel)
                    .font(.callout)
                    .foregroundStyle(pane.selectedItems.contains(entry.url) ? Color.primary : Color.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .help(exactSize)
            } else {
                Text(modifiedLabel)
                    .font(.callout)
                    .foregroundStyle(pane.selectedItems.contains(entry.url) ? Color.primary : Color.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.body)
        .foregroundStyle(.primary)
        .tint(accent)
        .accessibilityElement(children: renameRequest?.item.url == entry.url ? .contain : .combine)
        .accessibilityLabel(column == .name ? (pane.searchQuery.isEmpty ? entry.name : pane.relativeSearchPath(for: entry)) : column.rawValue)
        .accessibilityValue(column == .name ? entryType(entry) : (column == .size ? exactSize : "\(modifiedLabel). Last modified: \(exactModified)"))
        .accessibilityActions {
            if !pane.searchQuery.isEmpty {
                Button("Open Containing Folder") { Task { await browser.openContainingFolder(of: entry.url, in: id) } }
            }
            if browser.canDuplicate(in: id), pane.selectedItems.contains(entry.url) {
                Button("Duplicate") {
                    let items = pane.selectedItems
                    guard items.contains(entry.url) else { return }
                    Task { await browser.duplicate(from: id, items: items) }
                }
            }
            if browser.canTrash(in: id), pane.selectedItems.contains(entry.url) {
                Button("Move to Trash") {
                    let items = pane.selectedItems
                    guard items.contains(entry.url) else { return }
                    Task { await browser.moveToTrash(from: id, items: items) }
                }
            }
            if browser.canMove(in: id), pane.selectedItems.contains(entry.url) {
                Button("Move to Other Pane") {
                    let items = pane.selectedItems
                    guard items.contains(entry.url) else { return }
                    Task { await browser.moveToOtherPane(from: id, items: items) }
                }
            }
            if browser.canCopy(in: id), pane.selectedItems.contains(entry.url) {
                Button("Copy to Other Pane") {
                    let items = pane.selectedItems
                    guard items.contains(entry.url) else { return }
                    Task { await browser.copyToOtherPane(from: id, items: items) }
                }
            }
        }
        .contentShape(Rectangle())
        .help("\(pane.searchQuery.isEmpty ? entry.name : pane.relativeSearchPath(for: entry))\n\(entryType(entry))\nSize: \(exactSize)\nLast modified: \(exactModified)")
        .overlay {
            if renameRequest?.item.url != entry.url {
                ItemPathContextMenu(duplicate: {
                    guard browser.canDuplicate(in: id) else { return nil }
                    let items = pane.selectedItems
                    return { Task { await browser.duplicate(from: id, items: items) } }
                }, copyToOtherPane: {
                    guard browser.canCopy(in: id) else { return nil }
                    let items = pane.selectedItems
                    return { Task { await browser.copyToOtherPane(from: id, items: items) } }
                }, moveToOtherPane: {
                    guard browser.canMove(in: id) else { return nil }
                    let items = pane.selectedItems
                    return { Task { await browser.moveToOtherPane(from: id, items: items) } }
                }, moveToTrash: {
                    guard browser.canTrash(in: id) else { return nil }
                    let items = pane.selectedItems
                    return { Task { await browser.moveToTrash(from: id, items: items) } }
                }, openInFinder: {
                    let items = pane.entries.filter { pane.selectedItems.contains($0.url) }
                    guard !items.isEmpty, !browser.requiresFolderAccess || pane.directoryAccess != nil else { return nil }
                    let access = pane.directoryAccess
                    return { openInFinder(items, access) }
                }, rename: {
                    guard browser.canRename(in: id), let item = pane.primaryItemURL else { return nil }
                    return {
                        guard pane.selectedItems == [item] else { return }
                        Task { await browser.beginRename(in: id) }
                    }
                }, openContainingFolder: {
                    guard !pane.searchQuery.isEmpty, pane.selectedItems == [entry.url] else { return nil }
                    return { Task { await browser.openContainingFolder(of: entry.url, in: id) } }
                }) { show in
                    browser.targetContextItem(entry.url, in: id) {
                    focusList()
                        show(pane.copiedPaths(), pane.copiedPaths(relative: true))
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }
    private func entryType(_ entry: DirectoryEntry) -> String {
        if browser.requiresFolderAccess && entry.isSymbolicLink { return "Symbolic link" }
        let type = entry.isPackage ? "Package" : (entry.isDirectory ? "Folder" : "File")
        let description = entry.isSymbolicLink ? "\(type) link" : type
        return entry.isHidden ? "Hidden \(description.lowercased())" : description
    }
}


struct NewItemMenuItems: View {
    var keyboardShortcuts = false
    let create: (ItemCreation.Kind) -> Void

    var body: some View {
        Button("New Text File…") { create(.textFile) }
            .keyboardShortcut(keyboardShortcuts ? KeyboardShortcut("n", modifiers: [.command, .option]) : nil)
        Button("New Folder…") { create(.folder) }
            .keyboardShortcut(keyboardShortcuts ? KeyboardShortcut("n", modifiers: [.command, .shift]) : nil)
    }
}

private struct ItemNameEntry: View {
    let request: BrowserState.CreationRequest
    let error: String?
    let cancel: () -> Void
    let create: (String) -> Void
    @ViewState<String> private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(request.kind == .textFile ? "New Text File" : "New Folder").font(.headline)
            Text(request.directory.path)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .lineLimit(3)
                .help(request.directory.path)
                .accessibilityLabel("Create in \(request.directory.path)")
            TextField("Name", text: $name, prompt: Text(request.kind == .textFile ? "Untitled.txt" : "New Folder"))
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit { create(name) }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .accessibilityLabel("Creation error. \(error)")
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                AccentButton(title: "Create") { create(name) }
                    .fixedSize()
                    .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(nsColor: AppColours.floating))
        .onAppear { nameFocused = true }
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
                AccentButton(title: "Go", action: go).fixedSize()
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(nsColor: AppColours.floating))
        .onAppear { pathFocused = true }
    }
}

struct DetailsSidebar: View {
    let selection: DetailsSelection?
    let preview: PreviewState
    let sizing: DetailsSizing
    @AppStorage("fileInformationExpanded") private var fileInformationExpanded = true
    @ViewState<DetailsState> private var details = DetailsState()
    @ViewState<ImagePreviewState> private var imagePreview = ImagePreviewState()
    @ViewState<VideoPreviewState> private var videoPreview = VideoPreviewState()
    @ViewState<PDFPreviewState> private var pdfPreview = PDFPreviewState()

    private var item: DirectoryEntry? { selection?.item }
    private var isReadOnlyPreview: Bool { ImagePreview.supports(item) || VideoPreview.supports(item) || PDFPreview.supports(item) }
    private var metadata: ItemMetadata? { details.selection == selection ? details.metadata : nil }
    private var hasTextSelection: Bool {
        guard let selection else { return false }
        // Listing revisions must not remove a retained editor before its baseline check finishes.
        return preview.selection == selection || (preview.mode == .edit && preview.selection?.item.url == selection.item.url)
    }

    private var previewMessage: String {
        guard item != nil else { return "No item selected" }
        if ImagePreview.supports(item) {
            guard imagePreview.selection == selection, !imagePreview.isLoading else { return "Loading image preview…" }
            return imagePreview.errorMessage ?? "No image preview available."
        }
        if VideoPreview.supports(item) {
            guard videoPreview.selection == selection, !videoPreview.isLoading else { return "Loading video preview…" }
            return videoPreview.errorMessage ?? "No video preview available."
        }
        if PDFPreview.supports(item) {
            guard pdfPreview.selection == selection, !pdfPreview.isLoading else { return "Loading PDF preview…" }
            return pdfPreview.errorMessage ?? "No PDF preview available."
        }
        guard hasTextSelection, !preview.isLoading else { return "Loading text preview…" }
        if let error = preview.errorMessage { return error }
        if case .unavailable(let reason) = preview.preview { return reason.message }
        return "Empty text file."
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Details")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    sizing.toggleExpansion()
                } label: {
                    Label(sizing.isExpanded ? "Restore Previous Width" : "Expand Details",
                          image: sizing.isExpanded ? "icon-minimize-2" : "icon-maximize-2")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 24, minHeight: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(sizing.isExpanded ? "Restore previous Details width" : "Expand Details to the available maximum")
                .accessibilityValue(sizing.isExpanded ? "Expanded" : "Preferred width")
            }
            .padding(.horizontal, 14)
            .frame(height: panelHeaderHeight)

            Divider()

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let item {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.name)
                                    .font(.body.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Unsaved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                                    .opacity(preview.isDirty ? 1 : 0)
                                    .accessibilityLabel("Unsaved changes")
                                    .accessibilityHidden(!preview.isDirty)
                            }
                        }

                        if !preview.isReadOnly, !isReadOnlyPreview, hasTextSelection, preview.text != nil {
                            HStack(spacing: 8) {
                                TextModeToggle(mode: Binding(get: { [preview] in preview.mode }, set: { [preview] in preview.setMode($0) }),
                                               isEnabled: preview.canBeginEditing)
                                .fixedSize(horizontal: true, vertical: false)
                                .accessibilityLabel("Text mode")
                                .help(preview.canBeginEditing ? (preview.canEdit ? "Preview or edit this text draft" : "Allow folder access to edit this text") : "Editing is unavailable for this item")
                                Spacer(minLength: 12)
                                Button(preview.isSaving ? "Saving…" : "Save") {
                                    Task { await preview.save() }
                                }
                                .fixedSize()
                                .keyboardShortcut("s", modifiers: .command)
                                .disabled(!preview.isDirty || !preview.canSave)
                                .help("Save changes to this file (⌘S)")
                            }
                        }

                        Group {
                            if ImagePreview.supports(item), imagePreview.selection == selection, let image = imagePreview.image {
                                ImagePreviewView(image: image, name: item?.name ?? "selected image")
                            } else if VideoPreview.supports(item), videoPreview.selection == selection, let player = videoPreview.player {
                                VideoPreviewView(player: player, name: item?.name ?? "selected video", stopped: { [videoPreview] player in
                                    if videoPreview.player === player { videoPreview.stop() }
                                })
                            } else if PDFPreview.supports(item), pdfPreview.selection == selection, let document = pdfPreview.document {
                                PDFPreviewView(document: document, name: item?.name ?? "selected PDF")
                            } else if !isReadOnlyPreview, hasTextSelection, let text = preview.text {
                                PreviewDocument(preview: preview, text: text)
                            } else {
                                Text(previewMessage)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(12)
                            }
                        }
                        .frame(minHeight: 236, maxHeight: .infinity)
                        .background(paperBackground, in: RoundedRectangle(cornerRadius: 7))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color(nsColor: AppColours.divider), lineWidth: 1)
                        }

                        if let error = preview.errorMessage, preview.text != nil {
                            Text(error).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }

                        if let item {
                            let path = CopiedPaths.string(for: [item.url])
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("Absolute path").foregroundStyle(.secondary)
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
                                    .font(.subheadline.monospaced())
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityLabel("Selected absolute path")
                                    .accessibilityValue(path)
                            }
                        }

                        Divider()

                        DisclosureGroup(isExpanded: $fileInformationExpanded) {
                            VStack(alignment: .leading, spacing: 8) {
                                if item == nil {
                                    Text("Select an item to see its details.")
                                        .foregroundStyle(.secondary)
                                } else if details.selection != selection || details.isLoading {
                                    Text("Loading file information…")
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Loading file information")
                                } else {
                                    if let error = details.errorMessage {
                                        Text(error)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                                        metadataField("Type", value: metadata?.type)
                                        metadataField("Size", value: metadata?.size.map { "\($0.formatted()) \($0 == 1 ? "byte" : "bytes")" })
                                        metadataField("Modified", value: dateString(metadata?.modifiedDate))
                                        metadataField("Created", value: dateString(metadata?.createdDate))
                                        metadataField("Permissions", value: metadata?.permissionsDescription, monospaced: true)
                                        metadataField("Owner", value: metadata?.owner)
                                        metadataField("Group", value: metadata?.group)
                                    }
                                    if item?.isSymbolicLink == true || metadata?.targetPath != nil {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Link target").foregroundStyle(.secondary)
                                            Text(metadata?.targetPath ?? "Unavailable")
                                                .font(.subheadline.monospaced())
                                                .textSelection(.enabled)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .accessibilityElement(children: .combine)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text("File information")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                                .onTapGesture { fileInformationExpanded.toggle() }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.subheadline)
                    .padding(14)
                    .frame(minHeight: geometry.size.height, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(chromeBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Details sidebar")
        .task(id: selection) { await details.load(selection) }
        .onChange(of: preview.saveRevision) { Task { await details.load(selection) } }
        .task(id: selection) { await preview.load(isReadOnlyPreview ? nil : selection) }
        .task(id: selection) { await imagePreview.load(selection, followingLinks: preview.followsLinks) }
        .task(id: selection) { await videoPreview.load(selection, followingLinks: preview.followsLinks) }
        .task(id: selection) { await pdfPreview.load(selection, followingLinks: preview.followsLinks) }
        .onDisappear { videoPreview.stop(); pdfPreview.stop() }
    }

    private func metadataField(_ label: String, value: String?, monospaced: Bool = false) -> some View {
        GridRow(alignment: .top) {
            Text(label).foregroundStyle(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(value ?? "Unavailable")
                    .font(monospaced ? .subheadline.monospaced() : .subheadline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "Unavailable")
        }
    }

    private func dateString(_ date: Date?) -> String? {
        date?.formatted(.dateTime.day().month().year().hour().minute().second().timeZone())
    }
}
