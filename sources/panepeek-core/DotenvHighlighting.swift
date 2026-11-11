import Foundation

/// Dotenv files as Node.js reads them; values are text, never expanded or loaded.
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
        var index = skipBlanks(from: start)
        guard index < units.count, !SyntaxScanning.isCRorLF(units[index]) else { return nextLine(from: index) }
        if units[index] == 35 { return comment(from: index) }
        var prefix: Range<Int>?
        if SyntaxScanning.hasPrefix(Self.export, in: units, at: index) {
            let after = index + Self.export.count
            if after < units.count && SyntaxScanning.isSpaceOrTab(units[after]) {
                let key = skipBlanks(from: after)
                if key < units.count && isKeyStart(units[key]) { prefix = index..<after; index = key }
            }
        }
        guard index < units.count, isKeyStart(units[index]) else { return nextLine(from: index) }
        var keyEnd = index + 1
        while keyEnd < units.count && isKeyPart(units[keyEnd]) { keyEnd += 1 }
        let separator = skipBlanks(from: keyEnd)
        guard separator < units.count, units[separator] == 61 else { return nextLine(from: separator) }
        if let prefix { append(.keyword, prefix) }
        append(.key, index..<keyEnd)
        return try value(from: skipBlanks(from: separator + 1))
    }

    private mutating func value(from start: Int) throws -> Int {
        guard start < units.count else { return start }
        let quote = units[start]
        if quote == 34 || quote == 39 {
            var index = start + 1
            while index < units.count && units[index] != quote {
                if (index & 1023) == 0 { try Task.checkCancellation() }
                index += 1
            }
            let end = min(index + 1, units.count)
            append(.string, start..<end)
            let rest = skipBlanks(from: end)
            if rest < units.count && units[rest] == 35 { return comment(from: rest) }
            return nextLine(from: rest)
        }
        var index = start
        while index < units.count && !SyntaxScanning.isCRorLF(units[index]) && units[index] != 35 {
            if (index & 1023) == 0 { try Task.checkCancellation() }
            index += 1
        }
        var end = index
        while end > start && SyntaxScanning.isSpaceOrTab(units[end - 1]) { end -= 1 }
        append(.string, start..<end)
        return index < units.count && units[index] == 35 ? comment(from: index) : nextLine(from: index)
    }

    private mutating func comment(from start: Int) -> Int {
        let end = lineEnd(from: start)
        append(.comment, start..<end)
        return nextLine(from: end)
    }

    private func isKeyStart(_ unit: UInt16) -> Bool { unit == 95 || (65...90).contains(unit) || (97...122).contains(unit) }
    private func isKeyPart(_ unit: UInt16) -> Bool { isKeyStart(unit) || SyntaxScanning.isASCIIDigit(unit) }

    private func skipBlanks(from start: Int) -> Int {
        var index = start
        while index < units.count && SyntaxScanning.isSpaceOrTab(units[index]) { index += 1 }
        return index
    }

    private func lineEnd(from start: Int) -> Int {
        var index = start
        while index < units.count && !SyntaxScanning.isCRorLF(units[index]) { index += 1 }
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
