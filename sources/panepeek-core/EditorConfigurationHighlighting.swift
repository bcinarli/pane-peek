import Foundation

enum EditorConfigurationHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = EditorConfigurationScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct EditorConfigurationScanner {
    let units: [UInt16]
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
            highlightLine(from: start, to: end)
            start = end < units.count ? end + 1 : end
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func highlightLine(from start: Int, to end: Int) {
        let content = trimmed(start..<end)
        guard !content.isEmpty else { return }
        let first = units[content.lowerBound]
        if first == 35 || first == 59 {
            append(.comment, content)
        } else if first == 91 {
            // Glob headers can contain brackets, equals signs and comment markers.
            append(.section, content)
        } else if let separator = units[content].firstIndex(of: 61) {
            append(.key, trimmed(content.lowerBound..<separator))
            let value = trimmed((separator + 1)..<content.upperBound)
            append(valueKind(value), value)
        }
    }

    private func valueKind(_ range: Range<Int>) -> SyntaxToken.Kind {
        if range.count <= 5 {
            let word = String(decoding: units[range], as: UTF16.self).lowercased()
            if ["true", "false", "unset"].contains(word) { return .literal }
        }
        return !range.isEmpty && units[range].allSatisfy(SyntaxScanning.isASCIIDigit) ? .number : .string
    }

    private func trimmed(_ range: Range<Int>) -> Range<Int> {
        var start = range.lowerBound
        var end = range.upperBound
        while start < end && SyntaxScanning.isSpaceOrTab(units[start]) { start += 1 }
        while end > start && SyntaxScanning.isSpaceOrTab(units[end - 1]) { end -= 1 }
        return start..<end
    }

    private mutating func append(_ kind: SyntaxToken.Kind, _ range: Range<Int>) {
        if !range.isEmpty { tokens.append(SyntaxToken(range: NSRange(location: range.lowerBound, length: range.count), kind: kind)) }
    }
}
