import Foundation

enum IgnoreHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = IgnoreScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct IgnoreScanner {
    let units: [UInt16]
    var tokens: [SyntaxToken] = []

    mutating func scan() throws -> [SyntaxToken] {
        var start = units.first == 0xfeff ? 1 : 0
        while start < units.count {
            try Task.checkCancellation()
            var end = start
            while end < units.count && units[end] != 10 && units[end] != 13 {
                if (end & 1023) == 0 { try Task.checkCancellation() }
                end += 1
            }
            try highlightLine(from: start, to: end)
            start = end < units.count ? end + 1 : end
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func highlightLine(from start: Int, to end: Int) throws {
        guard start < end else { return }
        if units[start] == 35 {
            append(.comment, start..<end)
            return
        }
        let end = try patternEnd(from: start, to: end)
        guard end > start else { return }
        var pattern = start
        if units[pattern] == 33 {
            append(.keyword, pattern..<(pattern + 1))
            pattern += 1
        }
        append(.string, pattern..<end)
    }

    private func patternEnd(from start: Int, to end: Int) throws -> Int {
        var index = start
        var retained = start
        // Only unescaped trailing spaces are outside the pattern.
        while index < end {
            if (index & 1023) == 0 { try Task.checkCancellation() }
            if units[index] == 92 {
                index = min(index + 2, end)
                retained = index
            } else {
                if units[index] != 32 { retained = index + 1 }
                index += 1
            }
        }
        return retained
    }

    private mutating func append(_ kind: SyntaxToken.Kind, _ range: Range<Int>) {
        if !range.isEmpty { tokens.append(SyntaxToken(range: NSRange(location: range.lowerBound, length: range.count), kind: kind)) }
    }
}
