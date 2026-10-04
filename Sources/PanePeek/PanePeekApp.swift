import SwiftUI

@main
struct PanePeekApp: App {
    var body: some Scene {
        Window("PanePeek", id: "browser") {
            BrowserWindow()
        }
        .defaultSize(width: 1100, height: 650)
        .windowResizability(.contentMinSize)
    }
}
