import Foundation
import Testing
@testable import PanePeek

struct ReleaseSelectionTests {
    @Test func channelRequiresAnExplicitGitHubMarker() {
        for marker in [nil, "", "store", "development", "GitHub"] as [String?] {
            #expect(!UpdateChannel.isEnabled(marker))
        }
        #expect(UpdateChannel.isEnabled("github"))
    }

    @Test func selectsOnlyANewerMatchingPublishedStableArtifact() throws {
        let installed = try #require(ReleaseVersion("1.1.0", build: 9))
        #expect(try selection(version: "1.0.9", build: 20, installed: installed) == nil)
        #expect(try selection(version: "1.1.0", build: 8, installed: installed) == nil)
        #expect(try selection(version: "1.1.0", build: 9, installed: installed) == nil)
        let sameVersion = try #require(try selection(version: "1.1.0", build: 10, installed: installed))
        #expect(sameVersion.offer.version == "1.1.0 (10)")
        #expect(sameVersion.offer.installedVersion == "1.1.0 (9)")
        let next = try #require(try selection(version: "1.2.0", build: 10, installed: installed))
        #expect(next.offer.version == "1.2.0" && next.offer.installedVersion == "1.1.0")
        #expect(next.offer.actionTitle == "Download")
        #expect(next.offer.actionHelp == "Download the DMG and install it manually.")
    }

    @Test func invalidVersionsCannotBecomeAnUpdate() {
        for version in ["", "1.2", "1.2.3.4", "1.2.3-beta", "-1.2.3", "1.02.3", "1.2.999999999999999999999"] {
            #expect(ReleaseVersion(version, build: 1) == nil)
        }
        #expect(ReleaseVersion("1.2.3", build: 0) == nil)
    }

    @Test func ambiguousMissingOrUntrustedArtifactsAreFailures() throws {
        let installed = try #require(ReleaseVersion("1.1.0", build: 9))
        let good = release(version: "1.2.0", build: 10)
        for mutate in [
            { (data: inout GitHubRelease) in data.draft = true },
            { $0.prerelease = true }, { $0.publishedAt = nil },
            { $0.tag = "v1.2.0-beta" }, { $0.assets = [] },
            { $0.assets.append($0.assets[0]) },
            { $0.assets[0].url = "https://example.org/update.dmg" },
            { $0.assets[0].digest = nil }, { $0.assets[0].size = 0 },
            { $0.assets[0].size = UpdateTransport.maximumDownloadBytes + 1 },
            { $0.htmlURL = "https://github.com/other/project/releases/tag/v1.2.0" }
        ] as [(inout GitHubRelease) -> Void] {
            var candidate = good
            mutate(&candidate)
            #expect(throws: (any Error).self) { try candidate.select(installed: installed) }
        }
    }

    private func selection(version: String, build: Int, installed: ReleaseVersion) throws -> GitHubUpdate? {
        try release(version: version, build: build).select(installed: installed)
    }
    private func release(version: String, build: Int) -> GitHubRelease {
        let name = "PanePeek-\(version)-build\(build)-macos-arm64.dmg"
        return GitHubRelease(id: 123, tag: "v\(version)", draft: false, prerelease: false,
            publishedAt: "2026-10-20T12:00:00Z", htmlURL: "https://github.com/bcinarli/pane-peek/releases/tag/v\(version)",
            assets: [.init(name: name, size: 3_723_956, digest: "sha256:" + String(repeating: "a", count: 64),
                url: "https://github.com/bcinarli/pane-peek/releases/download/v\(version)/\(name)")])
    }
}
