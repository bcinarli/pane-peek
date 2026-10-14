import Foundation
import PanePeekCore

@MainActor struct WindowConfiguration {
    let directories: [URL]
    let order: [PaneID]
    let mode: BrowserMode
    let active: PaneID
    let detailsWidth: CGFloat

    init(record: [String: Any]?, home: URL) {
        if let names = record?["presentationOrder"] as? [String], names.count == 2,
           let first = Self.pane(names[0]), let second = Self.pane(names[1]), first != second {
            order = [first, second]
        } else { order = [.left, .right] }
        let paths = record?["directories"] as? [Any] ?? []
        directories = (0..<2).map { index in
            guard paths.indices.contains(index), let path = paths[index] as? String,
                  path.hasPrefix("/"), !path.contains("\0") else { return home }
            return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        }
        mode = record?["mode"] as? String == "onePane" ? .onePane : .twoPanes
        let storedActive = Self.pane(record?["activeBrowser"] as? String)
        active = mode == .onePane ? order[0] : storedActive ?? order[0]
        let width = record?["detailsWidth"] as? Double ?? DetailsSizing.compactWidth
        detailsWidth = width.isFinite && width >= DetailsSizing.detailsMinimum ? width : DetailsSizing.compactWidth
    }

    init(browser: BrowserState, sizing: DetailsSizing) {
        order = browser.presentationOrder
        directories = order.map { browser.pane($0).directory }
        mode = browser.mode
        active = browser.focusedPane
        detailsWidth = sizing.preferredWidth
    }

    var record: [String: Any] {
        ["directories": directories.map(\.path), "presentationOrder": order.map(Self.name),
         "mode": mode == .onePane ? "onePane" : "twoPanes", "activeBrowser": Self.name(active),
         "detailsWidth": Double(detailsWidth)]
    }

    private static func pane(_ name: String?) -> PaneID? {
        switch name { case "left": .left; case "right": .right; default: nil }
    }

    private static func name(_ pane: PaneID) -> String { pane == .left ? "left" : "right" }
}

@MainActor final class WindowRestoration {
    private let preferences: UserDefaults
    private var initialWindowClaimed = false
    private let preferenceKey = "rememberedWindow"

    init(preferences: UserDefaults) { self.preferences = preferences }

    func start(_ browser: BrowserState, sizing: DetailsSizing) async {
        guard browser.startupState == .pending else { return }
        let record = initialWindowClaimed ? nil : preferences.dictionary(forKey: preferenceKey)
        initialWindowClaimed = true
        let configuration = WindowConfiguration(record: record, home: browser.homeDirectory)
        sizing.restorePreferredWidth(configuration.detailsWidth)
        let leftIndex = configuration.order[0] == .left ? 0 : 1
        let rightIndex = 1 - leftIndex
        await browser.start(leftDirectory: configuration.directories[leftIndex],
                            rightDirectory: configuration.directories[rightIndex],
                            mode: configuration.mode, order: configuration.order, active: configuration.active)
    }

    func remember(_ browser: BrowserState, sizing: DetailsSizing) {
        guard browser.startupState == .ready else { return }
        let record = WindowConfiguration(browser: browser, sizing: sizing).record
        if let stored = preferences.dictionary(forKey: preferenceKey), NSDictionary(dictionary: stored).isEqual(to: record) { return }
        preferences.set(record, forKey: preferenceKey)
    }
}
