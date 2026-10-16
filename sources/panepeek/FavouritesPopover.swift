import SwiftUI
import PanePeekCore

private typealias ViewState<Value> = SwiftUI.State<Value>

struct FavouritesPopover: View {
    let favourites: Favourites
    let open: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @ViewState<String> private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        let matches = favourites.directories(matching: query)
        VStack(spacing: 0) {
            HStack {
                Text("Favourites").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Close Favourites")
                .help("Close Favourites")
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search folders or paths", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search favourites by folder name or full path")
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button {
                        query = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear favourite search")
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            Divider()
            if favourites.directories.isEmpty {
                VStack(spacing: 8) {
                    Text("No favourites yet").font(.headline)
                    Text("Use a folder’s star to add it here.")
                        .foregroundStyle(.secondary)
                }
                .padding(28)
            } else if matches.isEmpty {
                VStack(spacing: 8) {
                    Text("No matching favourites").font(.headline)
                    Text("Try another folder name or path.")
                        .foregroundStyle(.secondary)
                }
                .padding(28)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(matches, id: \.path) { directory in
                            row(directory)
                            if directory != matches.last { Divider() }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: min(CGFloat(matches.count) * 84, 504))
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Saved folders")
                .id(query)
            }
        }
        .frame(width: 480)
        .onExitCommand { dismiss() }
        .onAppear { searchFocused = true }
    }

    private func row(_ directory: URL) -> some View {
        HStack(spacing: 12) {
            Image("icon-folder").accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(directory.path == "/" ? "/" : directory.lastPathComponent)
                    .font(.body.weight(.medium))
                Text(directory.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button { open(directory) } label: {
                Image("icon-folder-open").frame(width: 28, height: 28)
            }
            .accessibilityLabel("Open \(directory.path) in active pane")
            .help("Open in active pane")
            Button { favourites.remove(directory) } label: {
                Image("icon-star-off").frame(width: 28, height: 28)
            }
            .accessibilityLabel("Remove \(directory.path) from favourites")
            .help("Remove from favourites")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 12)
    }
}
