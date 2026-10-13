import SwiftUI
import PanePeekCore

struct FavouriteMenuItems: View {
    let favourites: Favourites
    let open: ((URL) -> Void)?

    var body: some View {
        if favourites.directories.isEmpty {
            Text("No favourites yet")
        } else {
            ForEach(favourites.directories, id: \.path) { directory in
                Button(directory.path) { open?(directory) }
                    .disabled(open == nil)
            }
            Divider()
            Menu("Remove Favourite") {
                ForEach(favourites.directories, id: \.path) { directory in
                    Button(directory.path) { favourites.remove(directory) }
                        .accessibilityLabel("Remove \(directory.path) from favourites")
                }
            }
        }
    }
}
