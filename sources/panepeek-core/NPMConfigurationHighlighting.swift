import Foundation

enum NPMConfigurationHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = NPMConfigurationScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct NPMConfigurationScanner {
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
        let content = trimmed(start..<end)
        guard !content.isEmpty else { return }
        let first = units[content.lowerBound]
        if first == 35 || first == 59 {
            append(.comment, content)
        } else if first == 91 && units[content.upperBound - 1] == 93 {
            append(.section, content)
        } else if let separator = units[content].firstIndex(of: 61) {
            append(.key, trimmed(content.lowerBound..<separator))
            try highlightValue(trimmed((separator + 1)..<content.upperBound))
        } else {
            let comment = try commentStart(in: content)
            append(.key, trimmed(content.lowerBound..<comment))
            append(.comment, comment..<content.upperBound)
        }
    }

    private mutating func highlightValue(_ range: Range<Int>) throws {
        guard !range.isEmpty else { return }
        let first = units[range.lowerBound]
        if range.count > 1 && (first == 34 || first == 39) && units[range.upperBound - 1] == first {
            // npm INI protects comment markers only when the whole value is quoted.
            append(.string, range)
            return
        }
        let comment = try commentStart(in: range)
        let value = trimmed(range.lowerBound..<comment)
        append(valueKind(value), value)
        append(.comment, comment..<range.upperBound)
    }

    private func commentStart(in range: Range<Int>) throws -> Int {
        var index = range.lowerBound
        while index < range.upperBound {
            if (index & 1023) == 0 { try Task.checkCancellation() }
            if units[index] == 35 || units[index] == 59 { return index }
            index += units[index] == 92 && index + 1 < range.upperBound ? 2 : 1
        }
        return index
    }

    private func valueKind(_ range: Range<Int>) -> SyntaxToken.Kind {
        if range.count <= 5 {
            let word = String(decoding: units[range], as: UTF16.self)
            if ["true", "false", "null"].contains(word) { return .literal }
        }
        return !range.isEmpty && units[range].allSatisfy({ (48...57).contains($0) }) ? .number : .string
    }

    private func trimmed(_ range: Range<Int>) -> Range<Int> {
        var start = range.lowerBound
        var end = range.upperBound
        while start < end && isSpace(units[start]) { start += 1 }
        while end > start && isSpace(units[end - 1]) { end -= 1 }
        return start..<end
    }

    private func isSpace(_ unit: UInt16) -> Bool { unit == 9 || unit == 32 }
    private mutating func append(_ kind: SyntaxToken.Kind, _ range: Range<Int>) {
        if !range.isEmpty { tokens.append(SyntaxToken(range: NSRange(location: range.lowerBound, length: range.count), kind: kind)) }
    }
}
