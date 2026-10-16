import Foundation

public enum FileSizeDisplay {
    /// Compact decimal file sizes; unavailable or unrepresentable values use a dash.
    public static func string(for size: UInt64?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let size, let count = Int64(exactly: size) else { return "-" }
        return ByteCountFormatStyle(style: .file, spellsOutZero: false, locale: locale).format(count)
    }
}
