import AppKit
import Testing
@testable import PanePeek

@MainActor
struct AboutPanelTests {
    @Test func packagedMetadataIsUsedWithoutInventingReleaseValues() throws {
        let fixture = try AboutBundle(info: ["CFBundleShortVersionString": "0.7.2", "CFBundleVersion": "19",
                                             "NSHumanReadableCopyright": "Copyright Example"])
        defer { fixture.finish() }
        let options = AboutPanel.options(in: fixture.bundle)
        #expect(options[.applicationName] as? String == "PanePeek")
        #expect(options[.applicationVersion] as? String == "0.7.2")
        #expect(options[.version] as? String == "19")
        #expect(options[.init(rawValue: "Copyright")] as? String == "Copyright Example")
    }

    @Test func creditsLinkToProjectAndBundledOfflineNotices() throws {
        let fixture = try AboutBundle(info: [:], notices: true)
        defer { fixture.finish() }
        let credits = try #require(AboutPanel.options(in: fixture.bundle)[.credits] as? NSAttributedString)
        #expect(credits.string.contains("Browse and preview your documents.\nEdit text inline and copy absolute paths\nto share with AI agents."))
        var links: [String: URL] = [:]
        credits.enumerateAttribute(.link, in: NSRange(location: 0, length: credits.length)) { value, range, _ in
            if let url = value as? URL { links[(credits.string as NSString).substring(with: range)] = url }
        }
        #expect(links["GitHub"]?.absoluteString == "https://github.com/bcinarli/pane-peek")
        #expect(links["Release Notes"]?.absoluteString == "https://github.com/bcinarli/pane-peek/blob/main/CHANGELOG.md")
        #expect(links["Report an Issue"]?.absoluteString == "https://github.com/bcinarli/pane-peek/issues")
        for (label, file) in [("Privacy", "Privacy.txt"), ("Acknowledgements", "Acknowledgements.txt")] {
            let url = try #require(links[label])
            #expect(url.isFileURL && url.lastPathComponent == file)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
        #expect(links.count == 5)
    }

    @Test func unbundledLaunchHasHonestMetadataAndNoBrokenOfflineLinks() throws {
        let fixture = try AboutBundle(info: [:])
        defer { fixture.finish() }
        let options = AboutPanel.options(in: fixture.bundle)
        #expect(options[.applicationVersion] as? String == "Development build")
        #expect(options[.version] as? String == "")
        #expect(options[.init(rawValue: "Copyright")] as? String == "")
        let credits = try #require(options[.credits] as? NSAttributedString)
        #expect(credits.string.contains("Offline notices are unavailable in this unbundled build."))
        var files = 0
        credits.enumerateAttribute(.link, in: NSRange(location: 0, length: credits.length)) { value, _, _ in
            if (value as? URL)?.isFileURL == true { files += 1 }
        }
        #expect(files == 0)
    }
}

private struct AboutBundle {
    let root: URL
    let bundle: Bundle

    init(info: [String: String], notices: Bool = false) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-about-\(UUID()).bundle")
        let resources = root.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: root.appendingPathComponent("Contents/Info.plist"))
        if notices {
            for name in ["Privacy.txt", "Acknowledgements.txt"] {
                try Data("Offline fixture".utf8).write(to: resources.appendingPathComponent(name))
            }
        }
        bundle = try #require(Bundle(url: root))
    }

    func finish() { try? FileManager.default.removeItem(at: root) }
}
