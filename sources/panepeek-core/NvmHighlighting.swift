import Foundation

enum NvmHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = NvmScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct NvmScanner {
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
        let comment = units[start..<end].firstIndex(of: 35) ?? end
        let content = trimmed(start..<comment)
        if let separator = units[content].firstIndex(of: 61) {
            let key = trimmed(content.lowerBound..<separator)
            if !key.isEmpty {
                append(.key, key)
                append(.string, trimmed((separator + 1)..<content.upperBound))
            }
        } else {
            append(.literal, content)
        }
        append(.comment, comment..<end)
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
