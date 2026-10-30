import Foundation

enum YarnConfigurationHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = YarnConfigurationScanner(units: Array(text.utf16))
        return try scanner.scan()
    }
}

private struct YarnConfigurationScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []

    mutating func scan() throws -> [SyntaxToken] {
        var expectsKey = true
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            if SyntaxScanning.isCRorLF(unit) {
                expectsKey = true
                index += 1
            } else if SyntaxScanning.isSpaceOrTab(unit) || (index == 0 && unit == 0xfeff) || unit == 58 || unit == 44 {
                index += 1
            } else if unit == 35 {
                while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
                    if (index & 1023) == 0 { try Task.checkCancellation() }
                    index += 1
                }
                append(.comment, from: start)
            } else {
                try consumeWord()
                append(expectsKey ? .key : valueKind(from: start), from: start)
                expectsKey = false
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func consumeWord() throws {
        if units[index] == 34 {
            index += 1
            while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
                if (index & 1023) == 0 { try Task.checkCancellation() }
                let unit = units[index]
                index += 1
                if unit == 34 { return }
                if unit == 92 && index < units.count && !SyntaxScanning.isCRorLF(units[index]) { index += 1 }
            }
        } else {
            // A hash inside a bare word belongs to that word, unlike a leading hash.
            while index < units.count && ![9, 10, 13, 32, 44, 58].contains(units[index]) {
                if (index & 1023) == 0 { try Task.checkCancellation() }
                index += 1
            }
        }
    }

    private func valueKind(from start: Int) -> SyntaxToken.Kind {
        if index - start <= 5 {
            let word = String(decoding: units[start..<index], as: UTF16.self)
            if word == "true" || word == "false" { return .literal }
        }
        return units[start..<index].allSatisfy(SyntaxScanning.isASCIIDigit) ? .number : .string
    }

    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int) {
        tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
    }
}
