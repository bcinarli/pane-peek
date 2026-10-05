import SwiftUI
import UniformTypeIdentifiers
import PanePeekCore

// Select the property wrapper on SDKs that also expose a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct BrowserWindow: View {
    @ViewState<BrowserState> private var browser = BrowserState()
    @ViewState<Bool> private var showingPathEntry = false
    @ViewState<Bool> private var showingChooser = false
    @ViewState<PaneID> private var navigationTarget = .left
    @ViewState<String> private var directoryPath = ""
    @ViewState<String?> private var chooserError: String?
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 198 / 255, green: 160 / 255, blue: 246 / 255)
            : Color(red: 130 / 255, green: 85 / 255, blue: 182 / 255)
    }

    private var enclosingFolderAction: (() -> Void)? {
        guard browser.pane(browser.focusedPane).directory.path != "/" else { return nil }
        return { openEnclosingFolder() }
    }

    var body: some View {
        HSplitView {
            PaneArea(browser: browser, id: .left, accent: accent)
            PaneArea(browser: browser, id: .right, accent: accent)
            DetailsSidebar()
        }
        .frame(minWidth: 800, minHeight: 480)
        .tint(accent)
        .focusedSceneValue(\.enclosingFolderAction, enclosingFolderAction)
        .toolbar {
            Button("Go to Folder…", systemImage: "folder") {
                navigationTarget = browser.focusedPane
                directoryPath = browser.pane(navigationTarget).directory.path
                showingPathEntry = true
            }
            .keyboardShortcut("l", modifiers: .command)
            .help("Go to Folder (⌘L)")

            Menu("Directory actions", systemImage: "slider.horizontal.3") {
                Button("Choose Folder…") {
                    navigationTarget = browser.focusedPane
                    showingChooser = true
                }
                Button("Enclosing Folder", action: openEnclosingFolder)
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(browser.pane(browser.focusedPane).directory.path == "/")
            }
            .accessibilityLabel("Directory actions")
            .help("Directory actions")
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
    let id: PaneID
    let accent: Color
    @ViewState<URL?> private var selectedItem: URL?
    @FocusState private var listFocused: Bool

    private var pane: DirectoryPane { browser.pane(id) }
    private var accessibilityName: String { id == .left ? "Left directory pane" : "Right directory pane" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    browser.focus(id)
                    Task { await pane.navigate(to: browser.homeDirectory) }
                } label: {
                    Image(systemName: "house")
                }
                .buttonStyle(.borderless)
                .help("Home")
                .accessibilityLabel("Home in \(accessibilityName.lowercased())")
                .padding(.bottom, 16)

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
                    .padding(.vertical, 4)
                    // Leave room below the labels for the native horizontal scroller.
                    .padding(.bottom, 16)
                    .frame(height: 44)
                }
                .defaultScrollAnchor(.trailing)
                .defaultScrollAnchor(.leading, for: .alignment)
                .id(pane.directory.path)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
                .help(pane.directory.path)
                .accessibilityLabel("Directory breadcrumbs")

                if pane.isLoading {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Loading directory")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.bar)
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
                    .background(.bar)
            }

            List(pane.entries, selection: $selectedItem) { entry in
                Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .tag(entry.url)
            }
            .listStyle(.inset)
            .focused($listFocused)
            .contextMenu(forSelectionType: URL.self) { _ in
                EmptyView()
            } primaryAction: { items in
                guard let entry = pane.entries.first(where: { items.contains($0.url) }) else {
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
            .onChange(of: selectedItem) { _, item in
                if item != nil { browser.focus(id) }
            }
            .onChange(of: pane.directory) { selectedItem = nil }
            .onChange(of: listFocused) { _, focused in
                if focused { browser.focus(id) }
            }
        }
        .frame(minWidth: 250, maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { browser.focus(id) })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(browser.focusedPane == id ? "Focused" : "")
    }

    private func open(_ entry: DirectoryEntry) {
        browser.focus(id)
        guard entry.isDirectory else { return }
        Task { await pane.navigate(to: entry.url) }
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
    var body: some View {
        VStack(spacing: 0) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
                .frame(height: 44)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ContentUnavailableView(
                        "No item selected",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 236)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("File information")
                            .font(.headline)
                        Text("Select an item to see its details.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }
        }
        .frame(minWidth: 280, idealWidth: 300, maxWidth: 400, maxHeight: .infinity)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Details sidebar")
    }
}
