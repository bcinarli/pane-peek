import Foundation

public enum CopiedPaths {
    /// Formats displayed listing URLs as plain paths, optionally relative to their directory.
    public static func string(for urls: [URL], relativeTo directory: URL? = nil) -> String {
        urls.map { url in
            guard let directory else { return url.path }
            return url.pathComponents.dropFirst(directory.pathComponents.count).joined(separator: "/")
        }.joined(separator: "\n")
    }
}
