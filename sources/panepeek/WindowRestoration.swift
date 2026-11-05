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
    let columnWidths: [PaneID: BrowserColumnWidths]
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
        if record == nil { mode = .onePane }
        else { mode = record?["mode"] as? String == "onePane" ? .onePane : .twoPanes }
        let storedActive = Self.pane(record?["activeBrowser"] as? String)
        active = mode == .onePane ? order[0] : storedActive ?? order[0]
        let width = record?["detailsWidth"] as? Double ?? DetailsSizing.compactWidth
        detailsWidth = width.isFinite && width >= DetailsSizing.detailsMinimum ? width : DetailsSizing.compactWidth
        detailsExpanded = record?["detailsExpanded"] as? Bool ?? (record == nil)
        let proportion = record?["browserProportion"] as? Double ?? 1
        browserProportion = proportion.isFinite && proportion > 0 ? proportion : 1
        let widths = record?["columnWidths"] as? [String: Any]
        columnWidths = [.left: BrowserColumnWidths(record: widths?["left"]), .right: BrowserColumnWidths(record: widths?["right"])]
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
        columnWidths = [.left: browser.left.columnWidths, .right: browser.right.columnWidths]
        self.frame = frame
    }

    var record: [String: Any] {
        var record: [String: Any] = ["directories": directories.map(\.path), "presentationOrder": order.map(Self.name),
         "mode": mode == .onePane ? "onePane" : "twoPanes", "activeBrowser": Self.name(active),
         "detailsWidth": Double(detailsWidth), "detailsExpanded": detailsExpanded,
         "browserProportion": Double(browserProportion)]
        let widths = columnWidths.reduce(into: [String: [String: Double]]()) { records, browser in
            let stored = browser.value.record
            if !stored.isEmpty { records[Self.name(browser.key)] = stored }
        }
        if !widths.isEmpty { record["columnWidths"] = widths }
        if let frame { record["windowFrame"] = WindowGeometry.record(frame) }
        return record
    }

    private static func pane(_ name: String?) -> PaneID? {
        switch name { case "left": .left; case "right": .right; default: nil }
    }

    private static func name(_ pane: PaneID) -> String { pane == .left ? "left" : "right" }
}

private extension BrowserColumnWidths {
    init(record: Any?) {
        let fields = record as? [String: Any]
        func width(_ key: String, for field: DirectorySortField) -> CGFloat? {
            guard let value = fields?[key] as? Double,
                  value >= Self.minimum(for: field), value <= Double(Float.greatestFiniteMagnitude) else { return nil }
            return value
        }
        let name: Name?
        if let preferred = width("name", for: .name),
           let viewport = fields?["nameViewport"] as? Double, viewport.isFinite, viewport > 0 {
            name = Name(width: preferred, viewport: viewport)
        } else {
            name = nil
        }
        self.init(name: name, size: width("size", for: .size), modified: width("modified", for: .lastModified))
    }

    var record: [String: Double] {
        var fields: [String: Double] = [:]
        if let name {
            fields["name"] = Double(name.width)
            fields["nameViewport"] = Double(name.viewport)
        }
        if let size { fields["size"] = Double(size) }
        if let modified { fields["modified"] = Double(modified) }
        return fields
    }
}

@MainActor final class WindowRestoration {
    private let preferences: UserDefaults
    private var restoresNextWindow = true
    private let preferenceKey = "rememberedWindow"
    private let folderAccess: FolderAccess?

    init(preferences: UserDefaults, folderAccess: FolderAccess? = nil) {
        self.preferences = preferences
        self.folderAccess = folderAccess
    }

    func reopen() { restoresNextWindow = true }

    func start(_ browser: BrowserState, sizing: DetailsSizing, restoreFrame: () -> Void = {}) async {
        guard browser.startupState == .pending else { return }
        let record = restoresNextWindow ? preferences.dictionary(forKey: preferenceKey) : nil
        restoresNextWindow = false
        let configuration = WindowConfiguration(record: record, home: browser.homeDirectory)
        browser.left.columnWidths = configuration.columnWidths[.left] ?? BrowserColumnWidths()
        browser.right.columnWidths = configuration.columnWidths[.right] ?? BrowserColumnWidths()
        sizing.restorePreferredWidth(configuration.detailsWidth, expanded: configuration.detailsExpanded)
        sizing.setBrowserProportion(configuration.browserProportion)
        sizing.frameToRestore = configuration.frame
        restoreFrame()
        let leftIndex = configuration.order[0] == .left ? 0 : 1
        let rightIndex = 1 - leftIndex
        let bookmarks = record?["directoryAccess"] as? [Data] ?? []
        let directories = configuration.directories
        let restoreAccess: (@Sendable (URL) async throws -> DirectoryListing)?
        if browser.requiresFolderAccess, let folderAccess {
            restoreAccess = { directory in
                let index = directories.firstIndex(of: directory) ?? 0
                let data = bookmarks.indices.contains(index) ? bookmarks[index] : Data()
                let location = data.isEmpty ? nil : try JSONDecoder().decode(FolderAccess.Location.self, from: data)
                return try await folderAccess.readSaved(directory, location: location)
            }
        } else { restoreAccess = nil }
        await browser.start(leftDirectory: configuration.directories[leftIndex],
                            rightDirectory: configuration.directories[rightIndex],
                            mode: configuration.mode, order: configuration.order, active: configuration.active, restoreAccess: restoreAccess)
    }

    func remember(_ browser: BrowserState, sizing: DetailsSizing, frame: NSRect? = nil) {
        guard browser.startupState == .ready else { return }
        let configuration = WindowConfiguration(browser: browser, sizing: sizing, frame: frame)
        var record = configuration.record
        if browser.requiresFolderAccess, let folderAccess {
            let stored = preferences.dictionary(forKey: preferenceKey)
            let paths = stored?["directories"] as? [String] ?? []
            let bookmarks = stored?["directoryAccess"] as? [Data] ?? []
            record["directoryAccess"] = configuration.directories.map { directory -> Data in
                if let location = folderAccess.location(for: directory), let data = try? JSONEncoder().encode(location) { return data }
                if let index = paths.firstIndex(of: directory.path), bookmarks.indices.contains(index) { return bookmarks[index] }
                return Data()
            }
        }
        if let stored = preferences.dictionary(forKey: preferenceKey), NSDictionary(dictionary: stored).isEqual(to: record) { return }
        preferences.set(record, forKey: preferenceKey)
    }
}
