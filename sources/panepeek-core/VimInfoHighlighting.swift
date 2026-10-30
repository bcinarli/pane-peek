import Foundation

enum VimInfoHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = VimInfoScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct VimInfoScanner {
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
        if units[start] == 35 { append(.comment, start..<end); return }
        if units[start] == 42 { highlightOption(start..<end); return }
        guard var payload = prefixEnd(at: start, limit: end) else { return }
        append(.keyword, start..<payload)
        if units[start] == 124 && payload == start + 1 {
            let number = payload
            while payload < end && (48...57).contains(units[payload]) {
                if (payload & 1023) == 0 { try Task.checkCancellation() }
                payload += 1
            }
            append(.number, number..<payload)
        }
        // Payloads are stored data, even when they contain commands or quotes.
        append(.string, payload..<end)
    }

    private func prefixEnd(at start: Int, limit: Int) -> Int? {
        switch units[start] {
        case 124:
            return start + 1 < limit && units[start + 1] == 60 ? start + 2 : start + 1
        case 45, 39, 62:
            return start + 1 < limit && units[start + 1] < 128 ? start + 2 : start + 1
        case 34:
            let register = start + (start + 1 < limit && units[start + 1] == 34 ? 2 : 1)
            return register < limit && units[register] < 128 ? register + 1 : register
        case 47, 38, 36, 64, 58, 63, 61, 37, 33, 60, 126:
            return start + 1
        default:
            return nil
        }
    }

    private mutating func highlightOption(_ range: Range<Int>) {
        let start = range.lowerBound + 1
        guard let separator = units[start..<range.upperBound].firstIndex(of: 61), separator > start,
              units[start..<separator].allSatisfy({ (65...90).contains($0) || (97...122).contains($0) }) else { return }
        append(.keyword, range.lowerBound..<start)
        append(.key, start..<separator)
        append(.string, (separator + 1)..<range.upperBound)
    }

    private mutating func append(_ kind: SyntaxToken.Kind, _ range: Range<Int>) {
        if !range.isEmpty { tokens.append(SyntaxToken(range: NSRange(location: range.lowerBound, length: range.count), kind: kind)) }
    }
}
