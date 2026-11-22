import Foundation

extension Bundle {
    var panePeekVersionLabel: String? {
        guard let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else { return nil }
        guard version.wholeMatch(of: #/[0-9]+\.[0-9]+\.[0-9]+/#) != nil,
              let suffix = object(forInfoDictionaryKey: "PanePeekPrereleaseSuffix") as? String,
              let match = suffix.wholeMatch(of: #/(?:beta|rc)\.([1-9][0-9]*)/#),
              let sequence = Int64(match.1), sequence <= 9_007_199_254_740_991 else { return version }
        return "\(version)-\(suffix)"
    }
}
