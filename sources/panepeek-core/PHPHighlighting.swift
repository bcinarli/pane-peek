import Foundation

enum PHPHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = PHPScanner(text: text)
        return try scanner.scan()
    }
}

private struct PHPScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []

    init(text: String) {
        units = Array(text.utf16)
    }

    mutating func scan() throws -> [SyntaxToken] {
        var inCode = false
        var member = false
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            if inCode && isSpace(unit) {
                index += 1
                continue
            }
            if inCode && (has([45, 62]) || has([63, 45, 62])) {
                index += unit == 63 ? 3 : 2
                member = true
                continue
            }
            var kind: SyntaxToken.Kind?
            if !inCode {
                if let length = openingTagLength() {
                    index += length
                    kind = .section
                    inCode = true
                } else {
                    index += 1
                }
            } else if has([63, 62]) {
                index += 2
                kind = .section
                inCode = false
            } else if has([47, 42]) {
                try consumeBlockComment()
                kind = .comment
            } else if has([47, 47]) || (unit == 35 && !has([35, 91])) {
                try consumeLineComment()
                kind = .comment
            } else if unit == 34 || unit == 39 || unit == 96 {
                try consumeString()
                kind = .string
            } else if has([60, 60, 60]), try consumeHeredoc() {
                kind = .string
            } else if unit == 36 && index + 1 < units.count && isNameStart(units[index + 1]) {
                index += 2
                while index < units.count && isName(units[index]) { index += 1 }
                kind = .reference
            } else if isNameStart(unit) || unit == 92 {
                index += 1
                while index < units.count && (isName(units[index]) || units[index] == 92) { index += 1 }
                let word = String(decoding: units[start..<index], as: UTF16.self).lowercased()
                if !member && ["true", "false", "null"].contains(word) {
                    kind = .literal
                } else if !member && Self.keywords.contains(word) {
                    kind = .keyword
                }
            } else if isDigit(unit) || (unit == 46 && index + 1 < units.count && isDigit(units[index + 1])) {
                consumeNumber()
                let word = String(decoding: units[start..<index], as: UTF16.self)
                let range = NSRange(location: 0, length: word.utf16.count)
                if Self.number.rangeOfFirstMatch(in: word, range: range) == range { kind = .number }
            } else {
                index += 1
            }
            if let kind {
                tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
            }
            if kind != .comment { member = false }
        }
        try Task.checkCancellation()
        return tokens
    }

    private func openingTagLength() -> Int? {
        if has([60, 63, 61]) { return 3 }
        guard index + 5 <= units.count, has([60, 63]),
              [80, 112].contains(units[index + 2]), [72, 104].contains(units[index + 3]),
              [80, 112].contains(units[index + 4]),
              index + 5 == units.count || isSpace(units[index + 5]) else { return nil }
        return 5
    }

    private mutating func consumeBlockComment() throws {
        index += 2
        while index < units.count && !has([42, 47]) {
            try Task.checkCancellation()
            index += 1
        }
        if index < units.count { index += 2 }
    }

    private mutating func consumeLineComment() throws {
        while index < units.count && !isNewline(units[index]) && !has([63, 62]) {
            try Task.checkCancellation()
            index += 1
        }
    }

    private mutating func consumeString(depth: Int = 0) throws {
        guard depth < 32 else { index = units.count; return }
        let quote = units[index]
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == quote {
                index += 1
                return
            } else if units[index] == 92 {
                index = min(index + 2, units.count)
            } else if quote != 39 && (has([123, 36]) || has([36, 123])) {
                if units[index] == 36 { index += 1 }
                try consumeInterpolation(depth: depth + 1)
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeInterpolation(depth: Int) throws {
        guard depth < 32 else { index = units.count; return }
        var braces = 1
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            let unit = units[index]
            if unit == 34 || unit == 39 || unit == 96 {
                try consumeString(depth: depth)
            } else if has([47, 42]) {
                try consumeBlockComment()
            } else if has([47, 47]) || (unit == 35 && !has([35, 91])) {
                try consumeLineComment()
                if has([63, 62]) { index = units.count }
            } else if has([60, 60, 60]), try consumeHeredoc(depth: depth) {
                continue
            } else {
                index += 1
                if unit == 123 { braces += 1 }
                if unit == 125 {
                    braces -= 1
                    if braces == 0 { return }
                }
            }
        }
    }

    private mutating func consumeHeredoc(depth: Int = 0) throws -> Bool {
        var cursor = index + 3
        while cursor < units.count && [9, 32].contains(units[cursor]) { cursor += 1 }
        var quote: UInt16?
        if cursor < units.count && [34, 39].contains(units[cursor]) {
            quote = units[cursor]
            cursor += 1
        }
        let start = cursor
        guard cursor < units.count && isNameStart(units[cursor]) else { return false }
        cursor += 1
        while cursor < units.count && isName(units[cursor]) { cursor += 1 }
        let label = Array(units[start..<cursor])
        if let quote {
            guard cursor < units.count && units[cursor] == quote else { return false }
            cursor += 1
        }
        guard cursor < units.count && isNewline(units[cursor]) else { return false }
        guard depth < 32 else { index = units.count; return true }
        index = cursor
        consumeNewline()
        while index < units.count {
            try Task.checkCancellation()
            if isNewline(units[index - 1]) {
                while index < units.count && [9, 32].contains(units[index]) { index += 1 }
                if has(label) && (index + label.count == units.count || !isName(units[index + label.count])) {
                    index += label.count
                    return true
                }
            }
            if quote != 39 && (has([123, 36]) || has([36, 123])) {
                if units[index] == 36 { index += 1 }
                try consumeInterpolation(depth: depth + 1)
            } else if quote != 39 && index + 1 < units.count && units[index] == 92 && !isNewline(units[index + 1]) {
                index += 2
            } else if index < units.count {
                index += 1
            }
        }
        return true
    }

    private mutating func consumeNewline() {
        if has([13, 10]) { index += 2 }
        else if index < units.count && isNewline(units[index]) { index += 1 }
    }

    private mutating func consumeNumber() {
        index += 1
        while index < units.count {
            let unit = units[index]
            if isName(unit) || unit == 46 {
                index += 1
            } else if [43, 45].contains(unit) && [69, 101].contains(units[index - 1]) {
                index += 1
            } else {
                break
            }
        }
    }

    private func has(_ sequence: [UInt16]) -> Bool {
        index + sequence.count <= units.count && units[index..<index + sequence.count].elementsEqual(sequence)
    }
    private func isDigit(_ unit: UInt16) -> Bool { (48...57).contains(unit) }
    private func isNewline(_ unit: UInt16) -> Bool { unit == 10 || unit == 13 }
    private func isSpace(_ unit: UInt16) -> Bool { [9, 10, 13, 32].contains(unit) }
    private func isNameStart(_ unit: UInt16) -> Bool {
        (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || unit >= 128
    }
    private func isName(_ unit: UInt16) -> Bool { isNameStart(unit) || isDigit(unit) }

    private static let keywords: Set<String> = [
        "__halt_compiler", "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class", "clone",
        "const", "continue", "declare", "default", "die", "do", "echo", "else", "elseif", "empty", "enddeclare",
        "endfor", "endforeach", "endif", "endswitch", "endwhile", "enum", "eval", "exit", "extends", "final", "finally",
        "fn", "for", "foreach", "function", "global", "goto", "if", "implements", "include", "include_once", "instanceof",
        "insteadof", "interface", "isset", "list", "match", "namespace", "new", "or", "print", "private", "protected",
        "public", "readonly", "require", "require_once", "return", "static", "switch", "throw", "trait", "try", "unset",
        "use", "var", "while", "xor", "yield", "from", "self", "parent", "int", "float", "bool", "string", "void",
        "iterable", "object", "mixed", "never", "get", "set"
    ]
    private static let number = try! NSRegularExpression(pattern: #"^(?:0[xX][0-9a-fA-F]+(?:_[0-9a-fA-F]+)*|0[bB][01]+(?:_[01]+)*|0[oO][0-7]+(?:_[0-7]+)*|(?:[0-9]+(?:_[0-9]+)*(?:\.(?:[0-9]+(?:_[0-9]+)*)?)?|\.[0-9]+(?:_[0-9]+)*)(?:[eE][+-]?[0-9]+(?:_[0-9]+)*)?)$"#)
}
