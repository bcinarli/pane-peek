import SwiftUI
import PanePeekCore

struct FavouriteMenuItems: View {
    let favourites: Favourites
    let open: ((URL) -> Void)?

    nonisolated static func title(for directory: URL, among directories: [URL]) -> String {
        let name = directory.path == "/" ? "/" : directory.lastPathComponent
        let duplicates = directories.filter { $0.lastPathComponent == name && $0.path != directory.path }
        guard !duplicates.isEmpty else { return name }

        func parentContext(_ url: URL, depth: Int) -> String {
            let parent = url.deletingLastPathComponent()
            let components = parent.pathComponents
            return depth >= components.count ? parent.path : components.suffix(depth).joined(separator: "/")
        }

        let parent = directory.deletingLastPathComponent()
        for depth in 1...parent.pathComponents.count {
            let context = parentContext(directory, depth: depth)
            if duplicates.allSatisfy({ parentContext($0, depth: depth) != context }) {
                return "\(name) (\(context))"
            }
        }
        return "\(name) (\(parent.path))"
    }

    var body: some View {
        if favourites.directories.isEmpty {
            Text("No favourites yet")
        } else {
            ForEach(favourites.directories, id: \.path) { directory in
                Button(Self.title(for: directory, among: favourites.directories)) { open?(directory) }
                    .help(directory.path)
                    .accessibilityLabel("Open \(directory.path) in active pane")
                    .disabled(open == nil)
            }
            Divider()
            Menu("Remove Favourite") {
                ForEach(favourites.directories, id: \.path) { directory in
                    Button(Self.title(for: directory, among: favourites.directories)) { favourites.remove(directory) }
                        .help(directory.path)
                        .accessibilityLabel("Remove \(directory.path) from favourites")
                }
            }
        }
    }
}
