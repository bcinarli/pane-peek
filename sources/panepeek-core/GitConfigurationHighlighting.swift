import Foundation

enum GitConfigurationHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = GitConfigurationScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct GitConfigurationScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            if isSpace(unit) || isNewline(unit) || (index == 0 && unit == 0xfeff) {
                index += 1
            } else if unit == 35 || unit == 59 {
                index = try lineEnd(at: index)
                append(.comment, from: start, to: index)
            } else if unit == 91 {
                try consumeHeader()
                append(.section, from: start, to: index)
            } else {
                try consumeSetting()
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func consumeHeader() throws {
        index += 1
        var quoted = false
        while index < units.count && !isNewline(units[index]) {
            if (index & 1023) == 0 { try Task.checkCancellation() }
            let unit = units[index]
            index += 1
            if quoted && unit == 92 && index < units.count && !isNewline(units[index]) { index += 1 }
            else if unit == 34 { quoted.toggle() }
            else if unit == 93 && !quoted { return }
        }
    }

    private mutating func consumeSetting() throws {
        let start = index
        guard isLetter(units[index]) else { index = try lineEnd(at: index); return }
        while index < units.count && (isLetter(units[index]) || (48...57).contains(units[index]) || units[index] == 45) {
            if (index & 1023) == 0 { try Task.checkCancellation() }
            index += 1
        }
        guard index == units.count || isSpace(units[index]) || isNewline(units[index]) || [35, 59, 61].contains(units[index]) else {
            index = try lineEnd(at: index)
            return
        }
        append(.key, from: start, to: index)
        skipSpace()
        guard index < units.count && units[index] == 61 else { return }
        index += 1
        skipSpace()
        let value = index
        try consumeValue()
        var end = index
        while end > value && isSpace(units[end - 1]) { end -= 1 }
        append(valueKind(from: value, to: end), from: value, to: end)
    }

    private mutating func consumeValue() throws {
        var quoted = false
        while index < units.count && !isNewline(units[index]) {
            if (index & 1023) == 0 { try Task.checkCancellation() }
            let unit = units[index]
            if unit == 92 && index + 1 < units.count {
                index += 2
                if units[index - 1] == 13 && index < units.count && units[index] == 10 { index += 1 }
            } else if unit == 34 {
                quoted.toggle()
                index += 1
            } else if !quoted && (unit == 35 || unit == 59) {
                return
            } else {
                index += 1
            }
        }
    }

    private func valueKind(from start: Int, to end: Int) -> SyntaxToken.Kind {
        guard start < end else { return .string }
        if end - start <= 5 {
            let word = String(decoding: units[start..<end], as: UTF16.self).lowercased()
            if ["true", "false", "yes", "no", "on", "off"].contains(word) { return .literal }
        }
        var first = start
        var last = end
        if [43, 45].contains(units[first]) { first += 1 }
        if [75, 77, 71, 107, 109, 103].contains(units[last - 1]) { last -= 1 }
        return first < last && units[first..<last].allSatisfy({ (48...57).contains($0) }) ? .number : .string
    }

    private func lineEnd(at start: Int) throws -> Int {
        var end = start
        while end < units.count && !isNewline(units[end]) {
            if (end & 1023) == 0 { try Task.checkCancellation() }
            end += 1
        }
        return end
    }

    private mutating func skipSpace() { while index < units.count && isSpace(units[index]) { index += 1 } }
    private func isSpace(_ unit: UInt16) -> Bool { unit == 9 || unit == 32 }
    private func isNewline(_ unit: UInt16) -> Bool { unit == 10 || unit == 13 }
    private func isLetter(_ unit: UInt16) -> Bool { (65...90).contains(unit) || (97...122).contains(unit) }
    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int, to end: Int) {
        if end > start { tokens.append(SyntaxToken(range: NSRange(location: start, length: end - start), kind: kind)) }
    }
}
