import Foundation
import PanePeekCore

@MainActor struct WindowConfiguration {
    let directories: [URL]
    let order: [PaneID]
    let mode: BrowserMode
    let active: PaneID
    let detailsWidth: CGFloat
    let detailsExpanded: Bool
    let browserProportion: CGFloat
    let frame: NSRect?

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
        detailsExpanded = record?["detailsExpanded"] as? Bool ?? false
        let proportion = record?["browserProportion"] as? Double ?? 1
        browserProportion = proportion.isFinite && proportion > 0 ? proportion : 1
        frame = WindowGeometry.decode(record?["windowFrame"])
    }

    init(browser: BrowserState, sizing: DetailsSizing, frame: NSRect? = nil) {
        order = browser.presentationOrder
        directories = order.map { browser.pane($0).directory }
        mode = browser.mode
        active = browser.focusedPane
        detailsWidth = sizing.preferredWidth
        detailsExpanded = sizing.isExpanded
        browserProportion = sizing.browserProportion
        self.frame = frame
    }

    var record: [String: Any] {
        var record: [String: Any] = ["directories": directories.map(\.path), "presentationOrder": order.map(Self.name),
         "mode": mode == .onePane ? "onePane" : "twoPanes", "activeBrowser": Self.name(active),
         "detailsWidth": Double(detailsWidth), "detailsExpanded": detailsExpanded,
         "browserProportion": Double(browserProportion)]
        if let frame { record["windowFrame"] = WindowGeometry.record(frame) }
        return record
    }

    private static func pane(_ name: String?) -> PaneID? {
        switch name { case "left": .left; case "right": .right; default: nil }
    }

    private static func name(_ pane: PaneID) -> String { pane == .left ? "left" : "right" }
}

@MainActor final class WindowRestoration {
    private let preferences: UserDefaults
    private var restoresNextWindow = true
    private let preferenceKey = "rememberedWindow"

    init(preferences: UserDefaults) { self.preferences = preferences }

    func reopen() { restoresNextWindow = true }

    func start(_ browser: BrowserState, sizing: DetailsSizing, restoreFrame: () -> Void = {}) async {
        guard browser.startupState == .pending else { return }
        let record = restoresNextWindow ? preferences.dictionary(forKey: preferenceKey) : nil
        restoresNextWindow = false
        let configuration = WindowConfiguration(record: record, home: browser.homeDirectory)
        sizing.restorePreferredWidth(configuration.detailsWidth, expanded: configuration.detailsExpanded)
        sizing.setBrowserProportion(configuration.browserProportion)
        sizing.frameToRestore = configuration.frame
        restoreFrame()
        let leftIndex = configuration.order[0] == .left ? 0 : 1
        let rightIndex = 1 - leftIndex
        await browser.start(leftDirectory: configuration.directories[leftIndex],
                            rightDirectory: configuration.directories[rightIndex],
                            mode: configuration.mode, order: configuration.order, active: configuration.active)
    }

    func remember(_ browser: BrowserState, sizing: DetailsSizing, frame: NSRect? = nil) {
        guard browser.startupState == .ready else { return }
        let record = WindowConfiguration(browser: browser, sizing: sizing, frame: frame).record
        if let stored = preferences.dictionary(forKey: preferenceKey), NSDictionary(dictionary: stored).isEqual(to: record) { return }
        preferences.set(record, forKey: preferenceKey)
    }
}
