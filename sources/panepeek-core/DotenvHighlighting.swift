import Foundation

/// Dotenv files as Node.js reads them; values are text, never expanded or loaded.
/// Node removes every carriage return before parsing, so only LF ends a line and CR counts as blank.
enum DotenvHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = DotenvScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct DotenvScanner {
    let units: [UInt16]
    var tokens: [SyntaxToken] = []
    private static let export: [UInt16] = Array("export".utf16)

    init(units: [UInt16]) { self.units = units }

    mutating func scan() throws -> [SyntaxToken] {
        var position = units.first == 0xfeff ? 1 : 0
        while position < units.count {
            try Task.checkCancellation()
            position = try entry(from: position)
        }
        try Task.checkCancellation()
        return tokens
    }

    /// Highlights one entry and returns the start of the next line; a quoted value may span lines.
    private mutating func entry(from start: Int) throws -> Int {
        let begin = skipBlanks(from: start)
        guard begin < units.count, units[begin] != 10 else { return nextLine(from: begin) }
        if units[begin] == 35 { return comment(from: begin) }
        let end = lineEnd(from: begin)
        guard let separator = firstIndex(of: 61, in: begin..<end), separator > begin else { return nextLine(from: end) }
        // Node accepts any trimmed text before `=` as the key, removing an `export ` prefix.
        var key = begin..<trimmedEnd(from: begin, to: separator)
        let prefixEnd = begin + Self.export.count
        if key.count > Self.export.count + 1, SyntaxScanning.hasPrefix(Self.export, in: units, at: begin),
           units[prefixEnd] == 32 {
            append(.keyword, begin..<prefixEnd)
            key = skipBlanks(from: prefixEnd)..<key.upperBound
        }
        append(.key, key)
        return try value(from: skipBlanks(from: separator + 1))
    }

    private mutating func value(from start: Int) throws -> Int {
        guard start < units.count, units[start] != 10 else { return nextLine(from: start) }
        let quote = units[start]
        if quote == 34 || quote == 39 || quote == 96 {
            // Without a closing quote anywhere later, Node keeps the rest of the line, quote included.
            guard let closing = try closingQuote(quote, after: start) else {
                let end = lineEnd(from: start)
                append(.string, start..<trimmedEnd(from: start, to: end))
                return nextLine(from: end)
            }
            append(.string, start..<closing + 1)
            let rest = skipBlanks(from: closing + 1)
            if rest < units.count && units[rest] == 35 { return comment(from: rest) }
            return nextLine(from: rest)
        }
        let end = lineEnd(from: start)
        let hash = firstIndex(of: 35, in: start..<end) ?? end
        append(.string, start..<trimmedEnd(from: start, to: hash))
        return hash < end ? comment(from: hash) : nextLine(from: end)
    }

    /// A failed search leaves no later quote of that kind to open another value, so scanning stays linear.
    private func closingQuote(_ quote: UInt16, after start: Int) throws -> Int? {
        var index = start + 1
        while index < units.count {
            if units[index] == quote { return index }
            if (index & 1023) == 0 { try Task.checkCancellation() }
            index += 1
        }
        return nil
    }

    private mutating func comment(from start: Int) -> Int {
        let end = lineEnd(from: start)
        append(.comment, start..<trimmedEnd(from: start, to: end))
        return nextLine(from: end)
    }

    private func isBlank(_ unit: UInt16) -> Bool { SyntaxScanning.isSpaceOrTab(unit) || unit == 13 }

    private func skipBlanks(from start: Int) -> Int {
        var index = start
        while index < units.count && isBlank(units[index]) { index += 1 }
        return index
    }

    private func trimmedEnd(from start: Int, to end: Int) -> Int {
        var index = end
        while index > start && isBlank(units[index - 1]) { index -= 1 }
        return index
    }

    private func firstIndex(of unit: UInt16, in range: Range<Int>) -> Int? {
        var index = range.lowerBound
        while index < range.upperBound && units[index] != unit { index += 1 }
        return index < range.upperBound ? index : nil
    }

    private func lineEnd(from start: Int) -> Int {
        var index = start
        while index < units.count && units[index] != 10 { index += 1 }
        return index
    }

    private func nextLine(from start: Int) -> Int {
        let end = lineEnd(from: start)
        return end < units.count ? end + 1 : end
    }

    private mutating func append(_ kind: SyntaxToken.Kind, _ range: Range<Int>) {
        if !range.isEmpty { tokens.append(SyntaxToken(range: NSRange(location: range.lowerBound, length: range.count), kind: kind)) }
    }
}
