import Foundation

enum IgnoreHighlighting {
    /// Docker reads LF-delimited lines, treats only a column-one hash as a comment and trims Unicode whitespace
    /// around each pattern and exception marker, without Git's escaped trailing spaces.
    static func tokens(in text: String, docker: Bool = false) throws -> [SyntaxToken] {
        var scanner = IgnoreScanner(units: Array(text.utf16), docker: docker)
        return try scanner.scan()
    }
}

private struct IgnoreScanner {
    let units: [UInt16]
    let docker: Bool
    var tokens: [SyntaxToken] = []

    mutating func scan() throws -> [SyntaxToken] {
        var start = units.first == 0xfeff ? 1 : 0
        while start < units.count {
            try Task.checkCancellation()
            var end = start
            while end < units.count && !isLineBreak(units[end]) {
                if (end & 1023) == 0 { try Task.checkCancellation() }
                end += 1
            }
            // Like Go's bufio.ScanLines, Docker drops only the CR of a CRLF pair; other CRs stay in the line.
            let lineEnd = docker && end > start && units[end - 1] == 13 ? end - 1 : end
            try highlightLine(from: start, to: lineEnd)
            start = end < units.count ? end + 1 : end
        }
        try Task.checkCancellation()
        return tokens
    }

    private func isLineBreak(_ unit: UInt16) -> Bool {
        docker ? unit == 10 : SyntaxScanning.isCRorLF(unit)
    }

    private mutating func highlightLine(from start: Int, to end: Int) throws {
        guard start < end else { return }
        if units[start] == 35 {
            append(.comment, start..<end)
            return
        }
        if docker { return highlightDockerPattern(trimmed(start..<end)) }
        let end = try patternEnd(from: start, to: end)
        guard end > start else { return }
        var pattern = start
        if units[pattern] == 33 {
            append(.keyword, pattern..<(pattern + 1))
            pattern += 1
        }
        append(.string, pattern..<end)
    }

    private mutating func highlightDockerPattern(_ pattern: Range<Int>) {
        guard let first = pattern.first else { return }
        if units[first] == 33 {
            append(.keyword, first..<(first + 1))
            append(.string, trimmed((first + 1)..<pattern.upperBound))
        } else {
            append(.string, pattern)
        }
    }

    /// Matches Go's `strings.TrimSpace`; every Unicode whitespace scalar is a single UTF-16 unit.
    private func trimmed(_ range: Range<Int>) -> Range<Int> {
        var start = range.lowerBound, end = range.upperBound
        while start < end && Self.isWhitespace(units[start]) { start += 1 }
        while end > start && Self.isWhitespace(units[end - 1]) { end -= 1 }
        return start..<end
    }

    private static func isWhitespace(_ unit: UInt16) -> Bool {
        Unicode.Scalar(unit)?.properties.isWhitespace ?? false
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
