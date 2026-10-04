import SwiftUI

struct BrowserWindow: View {
    var body: some View {
        HSplitView {
            PaneArea(accessibilityName: "Left directory pane")
            PaneArea(accessibilityName: "Right directory pane")
            DetailsSidebar()
        }
        .frame(minWidth: 800, minHeight: 480)
    }
}

private struct PaneArea: View {
    let accessibilityName: String

    var body: some View {
        VStack(spacing: 0) {
            Text("No folder open")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(.bar)

            Divider()

            ContentUnavailableView(
                "No items",
                systemImage: "folder"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 250, maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityName)
    }
}

private struct DetailsSidebar: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Details")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
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
