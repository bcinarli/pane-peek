import Foundation

enum AttributesHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = AttributesScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct AttributesScanner {
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
        var index = start
        while index < end && isSpace(units[index]) { index += 1 }
        guard index < end else { return }
        if units[index] == 35 { append(.comment, index..<end); return }
        let pattern = index
        index = try patternEnd(at: index, limit: end)
        append(isMacro(pattern..<index) ? .section : .string, pattern..<index)
        while index < end {
            while index < end && isSpace(units[index]) { index += 1 }
            let attribute = index
            index = try wordEnd(at: index, limit: end)
            highlightAttribute(attribute..<index)
        }
    }

    private func patternEnd(at start: Int, limit: Int) throws -> Int {
        guard units[start] == 34 else { return try wordEnd(at: start, limit: limit) }
        var end = start + 1
        while end < limit {
            if (end & 1023) == 0 { try Task.checkCancellation() }
            let unit = units[end]
            end += 1
            if unit == 34 { return end }
            if unit == 92 && end < limit { end += 1 }
        }
        return end
    }

    private func wordEnd(at start: Int, limit: Int) throws -> Int {
        var end = start
        while end < limit && !isSpace(units[end]) {
            if (end & 1023) == 0 { try Task.checkCancellation() }
            end += 1
        }
        return end
    }

    private mutating func highlightAttribute(_ range: Range<Int>) {
        guard !range.isEmpty else { return }
        var start = range.lowerBound
        if units[start] == 45 || units[start] == 33 { start += 1 }
        let separator = units[start..<range.upperBound].firstIndex(of: 61) ?? range.upperBound
        guard isName(start..<separator) else { return }
        append(.reference, range.lowerBound..<start)
        append(.key, start..<separator)
        if separator < range.upperBound { append(.string, (separator + 1)..<range.upperBound) }
    }

    private func isMacro(_ range: Range<Int>) -> Bool {
        let name = range.lowerBound + Self.macroPrefix.count
        return name < range.upperBound && units[range.lowerBound..<name].elementsEqual(Self.macroPrefix) && isName(name..<range.upperBound)
    }

    private func isName(_ range: Range<Int>) -> Bool {
        !range.isEmpty && units[range.lowerBound] != 45 && units[range].allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 46, 95].contains($0)
        }
    }

    private func isSpace(_ unit: UInt16) -> Bool { unit == 9 || unit == 32 }
    private mutating func append(_ kind: SyntaxToken.Kind, _ range: Range<Int>) {
        if !range.isEmpty { tokens.append(SyntaxToken(range: NSRange(location: range.lowerBound, length: range.count), kind: kind)) }
    }
    private static let macroPrefix = Array("[attr]".utf16)
}
