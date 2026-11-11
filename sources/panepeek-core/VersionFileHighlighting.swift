import Foundation

/// Version-selection files, following each manager's reader rather than a shared format.
enum VersionFileHighlighting {
    enum Format: Sendable {
        /// rbenv reads only the file's first word.
        case rbenv
        /// pyenv reads each line's first word and skips lines whose first word starts with a hash.
        case pyenv
        /// asdf reads a tool name and its versions per line, with hash comments.
        case asdf
    }

    static func tokens(in text: String, format: Format) throws -> [SyntaxToken] {
        var scanner = VersionFileScanner(units: Array(text.utf16), format: format)
        return try scanner.scan()
    }
}

private struct VersionFileScanner {
    let units: [UInt16]
    let format: VersionFileHighlighting.Format
    var tokens: [SyntaxToken] = []

    mutating func scan() throws -> [SyntaxToken] {
        var start = units.first == 0xfeff ? 1 : 0
        while start < units.count {
            try Task.checkCancellation()
            var end = start
            while end < units.count && !SyntaxScanning.isCRorLF(units[end]) {
                if (end & 1023) == 0 { try Task.checkCancellation() }
                end += 1
            }
            if highlightLine(from: start, to: end) == .finished { break }
            start = end < units.count ? end + 1 : end
        }
        try Task.checkCancellation()
        return tokens
    }

    private enum Progress { case continuing, finished }

    private mutating func highlightLine(from start: Int, to end: Int) -> Progress {
        var words = Words(units: units, position: start, end: end)
        guard let first = words.next() else { return .continuing }
        switch format {
        case .rbenv:
            append(.literal, first)
            return .finished
        case .pyenv:
            append(units[first.lowerBound] == 35 ? .comment : .literal,
                   units[first.lowerBound] == 35 ? first.lowerBound..<end : first)
        case .asdf:
            if units[first.lowerBound] == 35 {
                append(.comment, first.lowerBound..<end)
                return .continuing
            }
            append(.key, first)
            while let word = words.next() {
                if units[word.lowerBound] == 35 {
                    append(.comment, word.lowerBound..<end)
                    break
                }
                append(.literal, word)
            }
        }
        return .continuing
    }

    private mutating func append(_ kind: SyntaxToken.Kind, _ range: Range<Int>) {
        if !range.isEmpty { tokens.append(SyntaxToken(range: NSRange(location: range.lowerBound, length: range.count), kind: kind)) }
    }
}

/// Space- and tab-delimited words within one line.
private struct Words {
    let units: [UInt16]
    var position: Int
    let end: Int

    mutating func next() -> Range<Int>? {
        while position < end && SyntaxScanning.isSpaceOrTab(units[position]) { position += 1 }
        guard position < end else { return nil }
        let start = position
        while position < end && !SyntaxScanning.isSpaceOrTab(units[position]) { position += 1 }
        return start..<position
    }
}
