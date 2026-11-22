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
        #expect(AboutPanel.versionLine(options) == "Version 0.7.2 (19)")
        #expect(options[.init(rawValue: "Copyright")] as? String == "Copyright Example")
    }

    @Test(arguments: ["beta.2", "rc.1", "beta.9007199254740991"])
    func packagedPrereleaseIsShownInTheAboutVersion(suffix: String) throws {
        let fixture = try AboutBundle(info: ["CFBundleShortVersionString": "1.3.0", "CFBundleVersion": "12",
                                             "PanePeekPrereleaseSuffix": suffix])
        defer { fixture.finish() }
        let options = AboutPanel.options(in: fixture.bundle)
        #expect(options[.applicationVersion] as? String == "1.3.0-\(suffix)")
        #expect(options[.version] as? String == "12")
        #expect(AboutPanel.versionLine(options) == "Version 1.3.0-\(suffix) (12)")
        #expect(fixture.bundle.infoDictionary?["CFBundleShortVersionString"] as? String == "1.3.0")
    }

    @Test(arguments: ["beta.0", "rc.01", "beta.9007199254740992", "rc.1\n", "preview.1"])
    func invalidPrereleaseSuffixKeepsTheNumericVersion(suffix: String) throws {
        let fixture = try AboutBundle(info: ["CFBundleShortVersionString": "1.3.0", "PanePeekPrereleaseSuffix": suffix])
        defer { fixture.finish() }
        let options = AboutPanel.options(in: fixture.bundle)
        #expect(options[.applicationVersion] as? String == "1.3.0")
        #expect(AboutPanel.versionLine(options) == "1.3.0")
    }

    @Test func aSuffixWithoutTheNumericVersionUsesTheUnavailableFallback() throws {
        let fixture = try AboutBundle(info: ["PanePeekPrereleaseSuffix": "beta.2"])
        defer { fixture.finish() }
        #expect(AboutPanel.options(in: fixture.bundle)[.applicationVersion] as? String == "Version unavailable")
    }

    @Test(arguments: [nil as String?, ""])
    func missingOrEmptyVersionKeepsAnAvailableBuild(version: String?) throws {
        var info = ["CFBundleVersion": "13"]
        info["CFBundleShortVersionString"] = version
        let fixture = try AboutBundle(info: info)
        defer { fixture.finish() }
        let options = AboutPanel.options(in: fixture.bundle)
        #expect(options[.applicationVersion] as? String == "Version unavailable")
        #expect(options[.version] as? String == "13")
        #expect(AboutPanel.versionLine(options) == "Version unavailable (build 13)")
    }

    @Test func absentVersionOptionUsesTheSameFallback() {
        #expect(AboutPanel.versionLine([:]) == "Version unavailable")
        #expect(AboutPanel.versionLine([.version: "13"]) == "Version unavailable (build 13)")
    }

    @Test func creditsLinkToProjectAndBundledOfflineNotices() throws {
        let fixture = try AboutBundle(info: [:], notices: ["Privacy", "Acknowledgements"])
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
        #expect(credits.string.hasSuffix("\nPrivacy · Acknowledgements"))
    }

    @Test(arguments: [("Privacy", "Acknowledgements"), ("Acknowledgements", "Privacy")])
    func missingNoticeLeavesTheOtherLinkAvailable(available: String, missing: String) throws {
        let fixture = try AboutBundle(info: [:], notices: [available])
        defer { fixture.finish() }
        let credits = try #require(AboutPanel.options(in: fixture.bundle)[.credits] as? NSAttributedString)
        #expect(credits.string.hasSuffix("\n\(available)\n\n\(missing) notice unavailable."))
        let range = (credits.string as NSString).range(of: available)
        try #require(range.location != NSNotFound)
        let url = try #require(credits.attribute(.link, at: range.location, effectiveRange: nil) as? URL)
        #expect(url.isFileURL && url.lastPathComponent == "\(available).txt")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func unbundledLaunchHasHonestMetadataAndNoBrokenOfflineLinks() throws {
        let fixture = try AboutBundle(info: [:])
        defer { fixture.finish() }
        let options = AboutPanel.options(in: fixture.bundle)
        #expect(options[.applicationVersion] as? String == "Version unavailable")
        #expect(options[.version] as? String == "")
        #expect(AboutPanel.versionLine(options) == "Version unavailable")
        #expect(options[.init(rawValue: "Copyright")] as? String == "")
        let credits = try #require(options[.credits] as? NSAttributedString)
        #expect(credits.string.hasSuffix("\n\nPrivacy and Acknowledgements notices unavailable."))
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

    init(info: [String: String], notices: [String] = []) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-about-\(UUID()).bundle")
        let resources = root.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: root.appendingPathComponent("Contents/Info.plist"))
        for notice in notices {
            try Data("Offline fixture".utf8).write(to: resources.appendingPathComponent("\(notice).txt"))
        }
        bundle = try #require(Bundle(url: root))
    }

    func finish() { try? FileManager.default.removeItem(at: root) }
}
