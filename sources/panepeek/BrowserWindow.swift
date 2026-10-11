import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PanePeekCore

// Select the property wrapper on SDKs that also expose a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>
private let panelHeaderHeight: CGFloat = 52
private let chromeBackground = Color(nsColor: .underPageBackgroundColor)
private let paperBackground = Color(nsColor: .textBackgroundColor)

struct BrowserWindow: View {
    let favourites: Favourites
    @ViewState<BrowserState> private var browser = BrowserState(confirmChanges: BrowserLifecycle.confirmChanges)
    @ViewState<DetailsSizing> private var detailsSizing = DetailsSizing()
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
            details: DetailsSidebar(selection: browser.detailsSelection, preview: browser.preview, sizing: detailsSizing).tint(accent),
            sizing: detailsSizing, visiblePanes: browser.visiblePanes,
            preferredWidth: detailsSizing.preferredWidth, isExpanded: detailsSizing.isExpanded
        )
        .frame(minWidth: 800, minHeight: 480)
        .tint(accent)
        .background {
            BrowserWindowGuard(browser: browser)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .focusedSceneValue(\.enclosingFolderAction, enclosingFolderAction)
        .focusedSceneValue(\.directoryPane, browser.commandPane)
        .focusedSceneValue(\.browserState, browser)
        .focusedSceneValue(\.openFavourite, { directory in browser.openFavourite(directory) })
        .focusedSceneValue(\.detailsSizing, detailsSizing)
        .toolbar {
            ToolbarItem {
                Picker("Browser layout", selection: Binding(
                    get: { browser.mode }, set: { browser.setMode($0) }
                )) {
                    Text("One Pane").tag(BrowserMode.onePane)
                    Text("Two Panes").tag(BrowserMode.twoPanes)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Browser layout")
                .help("Keep the active browser in One Pane; restore the other on the right in Two Panes")
            }
            .sharedBackgroundVisibility(.hidden)

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
                guard browser.visiblePanes.contains(navigationTarget) else { showingPathEntry = false; return }
                let pane = browser.pane(navigationTarget)
                let path = directoryPath
                showingPathEntry = false
                Task { await pane.navigate(toPath: path) }
            }
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
    @ViewState<Bool> private var selectionRejected = false
    @FocusState private var listFocused: Bool
    @ViewState<Date> private var dateRefreshStart = .now
    @Environment(\.scenePhase) private var scenePhase
    private let modifiedColumnWidth: CGFloat = 136

    private var pane: DirectoryPane { browser.pane(id) }
    private var accessibilityName: String {
        if browser.mode == .onePane { return "Directory pane" }
        return browser.presentationOrder.first == id ? "Left directory pane" : "Right directory pane"
    }

    var body: some View {
        let saved = favourites.contains(pane.directory)
        let favouriteAction = saved ? "Remove directory from favourites" : "Add directory to favourites"
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    Task { await browser.navigate(to: browser.homeDirectory, in: id) }
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
            .background(chromeBackground)
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(browser.focusedPane == id ? "Focused" : "")
    }

    private func sortHeader(_ field: DirectorySortField, title: String) -> some View {
        Button {
            guard browser.focus(id) else { return }
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
                let primary = items == Set(pane.entries.map(\.url)) ? pane.primaryItemURL : nil
                if !browser.select(items, in: id, focusedItem: primary) {
                    selectionRejected = true
                    DispatchQueue.main.async { selectionRejected = false }
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
                ItemPathContextMenu { show in
                    browser.targetContextItem(entry.url, in: id) {
                        interactedItem = entry.url
                        listFocused = true
                        show(pane.copiedPaths(), pane.copiedPaths(relative: true))
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
            guard !selectionRejected else { return }
            browser.focus(id) { listFocused = true }
        })
        .onKeyPress(keys: [.upArrow, .downArrow], phases: [.down, .repeat]) { press in
            if !press.modifiers.contains(.command) { followKeyboardFocus(press.key) }
            return .ignored
        }
        .onKeyPress(.escape) {
            browser.select([], in: id) { interactedItem = nil }
            return .handled
        }
        .onChange(of: pane.directory) { interactedItem = nil }
        .onChange(of: pane.entries) { oldEntries, entries in
            interactedItem = SelectionInteraction.reconciledItem(interactedItem, from: oldEntries, to: entries)
        }
        .onChange(of: listFocused) { _, focused in
            if focused, (selectionRejected || !browser.focus(id, then: { listFocused = true })) { listFocused = false }
        }
    }

    private func followKeyboardFocus(_ key: KeyEquivalent) {
        guard let endpoint = SelectionInteraction.keyboardEndpoint(
            in: pane.entries, interactedItem: interactedItem, primaryItem: pane.primaryItemURL, movingUp: key == .upArrow
        ) else { return }
        followInteraction(endpoint)
    }

    private func followInteraction(_ url: URL) {
        guard !selectionRejected else { return }
        let directory = pane.directory
        // Let native selection finish before following the interacted row.
        DispatchQueue.main.async {
            guard !selectionRejected, pane.directory == directory else { return }
            browser.select(pane.selectedItems, in: id, focusedItem: url) { interactedItem = url }
        }
    }

    private func open(_ entry: DirectoryEntry) {
        guard entry.isDirectory else { return }
        Task { await browser.navigate(to: entry.url, in: id) }
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
    let selection: DetailsSelection?
    let preview: PreviewState
    let sizing: DetailsSizing
    @ViewState<DetailsState> private var details = DetailsState()

    private var item: DirectoryEntry? { selection?.item }
    private var metadata: ItemMetadata? { details.selection == selection ? details.metadata : nil }

    private var previewMessage: String {
        guard item != nil else { return "No item selected" }
        guard preview.selection == selection, !preview.isLoading else { return "Loading text preview…" }
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

                    if preview.selection == selection, preview.text != nil {
                        HStack(spacing: 8) {
                            Picker("Text mode", selection: Binding(get: { [preview] in preview.mode }, set: { [preview] in preview.setMode($0) })) {
                                Text("Preview").tag(PreviewState.Mode.preview)
                                Text("Edit").tag(PreviewState.Mode.edit)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize(horizontal: true, vertical: false)
                            .disabled(!preview.canEdit)
                            .accessibilityLabel("Text mode")
                            .help(preview.canEdit ? "Preview or edit this text draft" : "Editing is unavailable for this item")
                            Spacer(minLength: 12)
                            Button(preview.isSaving ? "Saving…" : "Save") {
                                Task { await preview.save() }
                            }
                            .fixedSize()
                            .keyboardShortcut("s", modifiers: .command)
                            .disabled(!preview.isDirty || preview.isSaving)
                            .help("Save changes to this file (⌘S)")
                        }
                    }

                    Group {
                        if preview.selection == selection, let text = preview.text {
                            PreviewTextView(text: text, documentID: preview.documentID, saveRevision: preview.saveRevision,
                                            mode: preview.isSaving ? .preview : preview.mode,
                                            tokens: preview.tokens, canChange: { [preview] in preview.canEdit && preview.mode == .edit },
                                            changed: { [preview] in preview.updateText($0) })
                                .overlay(alignment: .topLeading) {
                                    if text.isEmpty, preview.mode == .preview {
                                        Text("Empty text file.")
                                            .foregroundStyle(.secondary)
                                            .padding(12)
                                            .allowsHitTesting(false)
                                    }
                                }
                        } else {
                            Text(previewMessage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(12)
                        }
                    }
                    .frame(height: 236)
                    .background(paperBackground, in: RoundedRectangle(cornerRadius: 7))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("File information")
                            .foregroundStyle(.secondary)
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
                }
                .font(.subheadline)
                .padding(14)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(chromeBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Details sidebar")
        .task(id: selection) { await details.load(selection) }
        .onChange(of: preview.saveRevision) { Task { await details.load(selection) } }
        .task(id: selection) { await preview.load(selection) }
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
