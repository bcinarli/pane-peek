import Foundation

enum CFamilyHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = CFamilyScanner(text: text)
        return try scanner.scan()
    }
}

private struct CFamilyScanner {
    let units: [UInt16]
    let source: NSString
    var index = 0
    var tokens: [SyntaxToken] = []
    var lineStart = true
    var directiveName = false
    var headerName = false

    init(text: String) {
        units = Array(text.utf16)
        source = text as NSString
    }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            index = try skipSplices(at: index)
            guard index < units.count else { break }
            let start = index
            let unit = units[index]
            if SyntaxScanning.isCRorLF(unit) {
                newLine()
                index += 1
                continue
            }
            if SyntaxScanning.isASCIIHorizontalWhitespace(unit) {
                index += 1
                continue
            }
            var kind: SyntaxToken.Kind?
            if let end = try matchedEnd([47, 47], at: index) {
                index = end
                try consumeComment(block: false)
                kind = .comment
            } else if let end = try matchedEnd([47, 42], at: index) {
                index = end
                try consumeComment(block: true)
                kind = .comment
            } else if try unit == 35 && lineStart && matchedEnd([35, 35], at: index) == nil {
                index += 1
                lineStart = false
                directiveName = true
                kind = .reference
            } else {
                var nextHeader = false
                if headerName && [34, 60].contains(unit) {
                    try consumeHeader(closing: unit == 60 ? 62 : 34)
                    kind = .string
                } else if let opening = try stringOpening() {
                    let closed = try consumeString(opening: opening)
                    if closed { _ = try consumeName() }
                    kind = .string
                } else if try isName(unit) || universalNameEnd(at: index) != nil {
                    let word = String(decoding: try consumeName(), as: UTF16.self)
                    if directiveName {
                        kind = .reference
                        nextHeader = ["include", "include_next", "embed", "import"].contains(word)
                    } else if ["true", "false", "nullptr"].contains(word) {
                        kind = .literal
                    } else if Self.keywords.contains(word) {
                        kind = .keyword
                    }
                } else if SyntaxScanning.isASCIIDigit(unit) || (unit == 46 && index + 1 < units.count && SyntaxScanning.isASCIIDigit(units[index + 1])) {
                    try consumeNumber()
                } else {
                    index += 1
                }
                lineStart = false
                directiveName = false
                headerName = nextHeader
            }
            if let kind { append(kind, from: start) }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func consumeComment(block: Bool) throws {
        while index < units.count {
            try Task.checkCancellation()
            index = try skipSplices(at: index)
            guard index < units.count else { return }
            if block, let end = try matchedEnd([42, 47], at: index) {
                index = end
                return
            }
            if SyntaxScanning.isCRorLF(units[index]) {
                if !block { return }
                newLine()
            }
            index += 1
        }
    }

    private func stringOpening() throws -> (end: Int, quote: UInt16, raw: Bool)? {
        for prefix in Self.stringPrefixes {
            if let end = try matchedEnd(prefix, at: index) {
                let raw = prefix.contains(82)
                if raw && rawDelimiterEnd(at: end) == nil { continue }
                return (end, prefix.last ?? 34, raw)
            }
        }
        return nil
    }

    private mutating func consumeString(opening: (end: Int, quote: UInt16, raw: Bool)) throws -> Bool {
        index = opening.end
        if opening.raw {
            let delimiterStart = index
            guard let end = rawDelimiterEnd(at: index) else { return false }
            index = end
            let delimiter = source.substring(with: NSRange(location: delimiterStart, length: index - delimiterStart))
            index += 1
            // Raw bodies keep physical backslash/newline sequences in their terminator search.
            let closing = source.range(of: ")" + delimiter + "\"", options: .literal, range: NSRange(location: index, length: units.count - index))
            try Task.checkCancellation()
            index = closing.location == NSNotFound ? units.count : NSMaxRange(closing)
            return closing.location != NSNotFound
        }
        while index < units.count {
            try Task.checkCancellation()
            index = try skipSplices(at: index)
            guard index < units.count else { return false }
            if SyntaxScanning.isCRorLF(units[index]) { return false }
            if units[index] == opening.quote {
                index += 1
                return true
            }
            if units[index] == 92 {
                index = try skipSplices(at: index + 1)
                if index < units.count && !SyntaxScanning.isCRorLF(units[index]) { index += 1 }
            } else {
                index += 1
            }
        }
        return false
    }

    private func rawDelimiterEnd(at start: Int) -> Int? {
        var end = start
        while end < units.count && end - start <= 16 {
            if units[end] == 40 { return end }
            guard (33...126).contains(units[end]) && ![41, 92].contains(units[end]) else { return nil }
            end += 1
        }
        return nil
    }

    private mutating func consumeHeader(closing: UInt16) throws {
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            index = try skipSplices(at: index)
            guard index < units.count && !SyntaxScanning.isCRorLF(units[index]) else { return }
            let unit = units[index]
            index += 1
            if unit == closing { return }
        }
    }

    private mutating func consumeName() throws -> [UInt16] {
        var word: [UInt16] = []
        while index < units.count {
            let position = try skipSplices(at: index)
            guard position < units.count else { break }
            if let end = try universalNameEnd(at: position) {
                word.append(contentsOf: units[position..<end])
                index = end
            } else if isName(units[position]) || (!word.isEmpty && SyntaxScanning.isASCIIDigit(units[position])) {
                word.append(units[position])
                index = position + 1
            } else { break }
        }
        return word
    }

    private func universalNameEnd(at position: Int) throws -> Int? {
        guard position < units.count && units[position] == 92 else { return nil }
        let letter = try skipSplices(at: position + 1)
        guard letter < units.count && [117, 85, 78].contains(units[letter]) else { return nil }
        var end = try skipSplices(at: letter + 1)
        if end < units.count && units[end] == 123 {
            end += 1
            let start = end
            while end < units.count && units[end] != 125 && !SyntaxScanning.isCRorLF(units[end]) {
                try Task.checkCancellation()
                let unit = units[end]
                let hex = SyntaxScanning.isASCIIHexDigit(unit)
                guard units[letter] == 78 ? (isName(unit) || SyntaxScanning.isASCIIDigit(unit) || [32, 45].contains(unit)) : hex else { return nil }
                end += 1
            }
            return end > start && end < units.count && units[end] == 125 ? end + 1 : nil
        }
        guard units[letter] != 78 else { return nil }
        for _ in 0..<(units[letter] == 85 ? 8 : 4) {
            end = try skipSplices(at: end)
            guard end < units.count && (SyntaxScanning.isASCIIHexDigit(units[end])) else { return nil }
            end += 1
        }
        return end
    }

    private mutating func consumeNumber() throws {
        var previous: UInt16 = 0
        while index < units.count {
            let position = try skipSplices(at: index)
            guard position < units.count else { return }
            let unit = units[position]
            if isName(unit) || SyntaxScanning.isASCIIDigit(unit) || unit == 46 || ([43, 45].contains(unit) && [69, 101, 80, 112].contains(previous)) {
                previous = unit
                index = position + 1
            } else if unit == 39 {
                let next = try skipSplices(at: position + 1)
                guard next < units.count && (isName(units[next]) || SyntaxScanning.isASCIIDigit(units[next])) else { return }
                previous = unit
                index = position + 1
            } else { return }
        }
    }

    private func skipSplices(at position: Int) throws -> Int {
        var end = position
        while end + 1 < units.count && units[end] == 92 && SyntaxScanning.isCRorLF(units[end + 1]) {
            try Task.checkCancellation()
            end += 2
            if units[end - 1] == 13 && end < units.count && units[end] == 10 { end += 1 }
        }
        try Task.checkCancellation()
        return end
    }

    private func matchedEnd(_ prefix: [UInt16], at position: Int) throws -> Int? {
        var end = position
        for unit in prefix {
            end = try skipSplices(at: end)
            guard end < units.count && units[end] == unit else { return nil }
            end += 1
        }
        return end
    }

    private mutating func newLine() {
        lineStart = true
        directiveName = false
        headerName = false
    }
    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int) {
        tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
    }
    private func isName(_ unit: UInt16) -> Bool { (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || unit >= 128 }
    private static let stringPrefixes: [[UInt16]] = ["u8R\"", "uR\"", "UR\"", "LR\"", "R\"", "u8\"", "u\"", "U\"", "L\"", "\"", "u8'", "u'", "U'", "L'", "'"].map { Array($0.utf16) }
    private static let keywords: Set<String> = [
        "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand", "bitor", "bool", "break",
        "case", "catch", "char", "char8_t", "char16_t", "char32_t", "class", "compl", "concept",
        "const", "consteval", "constexpr", "constinit", "const_cast", "continue", "co_await", "co_return", "co_yield",
        "decltype", "default", "delete", "do", "double", "dynamic_cast", "else", "enum", "explicit", "export",
        "extern", "float", "for", "friend", "goto", "if", "inline", "int", "long", "mutable", "namespace",
        "new", "noexcept", "not", "not_eq", "operator", "or", "or_eq", "private", "protected", "public",
        "register", "reinterpret_cast", "requires", "restrict", "return", "short", "signed", "sizeof", "static",
        "static_assert", "static_cast", "struct", "switch", "template", "this", "thread_local", "throw", "try",
        "typedef", "typeid", "typename", "typeof", "typeof_unqual", "union", "unsigned", "using", "virtual",
        "void", "volatile", "wchar_t", "while", "xor", "xor_eq", "_Alignas", "_Alignof", "_Atomic", "_BitInt",
        "_Bool", "_Complex", "_Decimal32", "_Decimal64", "_Decimal128", "_Generic", "_Imaginary", "_Noreturn",
        "_Static_assert", "_Thread_local"
    ]
}
