#if !PANEPEEK_APP_STORE
import Foundation

struct ReleaseVersion: Equatable, Comparable, Sendable {
    let text: String
    let parts: [Int]
    let build: Int

    init?(_ text: String, build: Int) {
        let components = text.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3, build > 0 else { return nil }
        let numbers = components.compactMap { component -> Int? in
            guard !component.isEmpty, component.allSatisfy({ $0.isASCII && $0.isNumber }),
                  component.count == 1 || component.first != "0" else { return nil }
            return Int(component)
        }
        guard numbers.count == 3 else { return nil }
        self.text = text
        parts = numbers
        self.build = build
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.parts != rhs.parts { return lhs.parts.lexicographicallyPrecedes(rhs.parts) }
        return lhs.build < rhs.build
    }
}

struct GitHubUpdate: Sendable {
    let offer: UpdateOffer
    let url: URL
    let size: Int64
    let digest: String
}

struct GitHubRelease: Decodable, Sendable {
    struct Asset: Decodable, Sendable {
        var name: String
        var size: Int64
        var digest: String?
        var url: String
        enum CodingKeys: String, CodingKey { case name, size, digest; case url = "browser_download_url" }
    }
    var id: Int64
    var tag: String
    var draft: Bool
    var prerelease: Bool
    var publishedAt: String?
    var htmlURL: String
    var assets: [Asset]
    enum CodingKeys: String, CodingKey {
        case id, draft, prerelease, assets
        case tag = "tag_name", publishedAt = "published_at", htmlURL = "html_url"
    }

    func select(installed: ReleaseVersion) throws -> GitHubUpdate? {
        guard id > 0, !draft, !prerelease, let publishedAt,
              ISO8601DateFormatter().date(from: publishedAt) != nil,
              tag.hasPrefix("v"), let version = ReleaseVersion(String(tag.dropFirst()), build: 1),
              htmlURL == "https://github.com/bcinarli/pane-peek/releases/tag/\(tag)" else { throw UpdateError.invalidRelease }
        let prefix = "PanePeek-\(version.text)-build"
        let suffix = "-macos-arm64.dmg"
        let matches = assets.filter { $0.name.hasPrefix(prefix) && $0.name.hasSuffix(suffix) }
        guard matches.count == 1, let asset = matches.first else { throw UpdateError.invalidRelease }
        let buildText = String(asset.name.dropFirst(prefix.count).dropLast(suffix.count))
        guard let build = Int(buildText), String(build) == buildText,
              let candidate = ReleaseVersion(version.text, build: build),
              asset.size > 0, asset.size <= UpdateTransport.maximumDownloadBytes,
              let digest = asset.digest, digest.hasPrefix("sha256:"),
              digest.count == 71, digest.dropFirst(7).allSatisfy({ "0123456789abcdef".contains($0) }),
              asset.url == "https://github.com/bcinarli/pane-peek/releases/download/\(tag)/\(asset.name)",
              let url = URL(string: asset.url) else { throw UpdateError.invalidRelease }
        guard candidate > installed else { return nil }
        let includeBuild = candidate.parts == installed.parts
        return GitHubUpdate(offer: UpdateOffer(id: "\(id):\(asset.name)",
            version: includeBuild ? "\(candidate.text) (\(candidate.build))" : candidate.text,
            installedVersion: includeBuild ? "\(installed.text) (\(installed.build))" : installed.text,
            actionTitle: "Download", actionHelp: "Download the DMG and install it manually.",
            progressTitle: "Downloading PanePeek \(candidate.text)…"),
            url: url, size: asset.size, digest: String(digest.dropFirst(7)))
    }
}

#endif
