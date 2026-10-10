import Foundation

enum JavaScriptHighlighting {
    static func tokens(in text: String, typescript: Bool, jsx: Bool = false) throws -> [SyntaxToken] {
        var scanner = JavaScriptScanner(text: text, typescript: typescript, jsx: jsx)
        return try scanner.scan()
    }
}

struct JavaScriptScanner {
    let units: [UInt16]
    let typescript: Bool
    let jsx: Bool
    var index = 0
    var tokens: [SyntaxToken] = []

    init(text: String, typescript: Bool, jsx: Bool) {
        units = Array(text.utf16)
        self.typescript = typescript
        self.jsx = jsx
    }

    mutating func scan() throws -> [SyntaxToken] {
        try scanCode(collectTokens: true)
        try Task.checkCancellation()
        return tokens
    }

    @discardableResult
    mutating func scanCode(collectTokens: Bool, interpolation: Bool = false, depth: Int = 0) throws -> Bool {
        var allowsRegex = true
        var previous = ""
        var parentheses: [Bool] = []
        var braces: [Bool] = []
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            var kind: SyntaxToken.Kind?
            if isSpace(unit) {
                index += 1
                continue
            } else if has([47, 47]) || ((index == 0 || (index == 1 && units[0] == 0xFEFF)) && has([35, 33])) {
                while index < units.count && !isNewline(units[index]) { index += 1 }
                kind = .comment
            } else if has([47, 42]) {
                index += 2
                while index < units.count && !has([42, 47]) { index += 1 }
                if index < units.count { index += 2 }
                kind = .comment
            } else if jsx && unit == 60 && allowsRegex && isJSXStart() {
                try consumeJSX(collectTokens: collectTokens, depth: depth)
                allowsRegex = false
                previous = "value"
            } else if unit == 34 || unit == 39 {
                consumeQuoted()
                kind = .string
                allowsRegex = false
                previous = "value"
            } else if unit == 96 {
                try consumeTemplate(depth: depth)
                kind = .string
                allowsRegex = false
                previous = "value"
            } else if unit == 47 && allowsRegex {
                consumeRegex()
                kind = .string
                allowsRegex = false
                previous = "value"
            } else if isIdentifierStart(unit) || has([92, 117]) || (unit == 35 && index + 1 < units.count && isIdentifierStart(units[index + 1])) {
                if unit == 35 { index += 1 }
                consumeIdentifier()
                let word = String(decoding: units[start..<index], as: UTF16.self)
                let property = previous == "."
                if !property {
                    if ["true", "false", "null"].contains(word) {
                        kind = .literal
                    } else if Self.keywords.contains(word) || (typescript && Self.typeWords.contains(word)) {
                        kind = .keyword
                    }
                }
                allowsRegex = !property && Self.expressionPrefixes.contains(word)
                previous = property ? "value" : word
            } else if isDigit(unit) || (unit == 46 && index + 1 < units.count && isDigit(units[index + 1])) {
                consumeNumber()
                let word = String(decoding: units[start..<index], as: UTF16.self)
                let range = NSRange(location: 0, length: word.utf16.count)
                if Self.number.rangeOfFirstMatch(in: word, range: range) == range { kind = .number }
                allowsRegex = false
                previous = "value"
            } else {
                index += 1
                switch unit {
                case 40:
                    parentheses.append(Self.controls.contains(previous))
                    allowsRegex = true
                case 41:
                    allowsRegex = parentheses.popLast() ?? false
                case 123:
                    // Local statement context distinguishes common block endings from object values.
                    braces.append(previous.isEmpty || [")", "=>", ";", "else", "do", "try", "finally"].contains(previous))
                    allowsRegex = true
                case 125:
                    if interpolation && braces.isEmpty { return true }
                    allowsRegex = braces.popLast() ?? true
                case 93, 46:
                    allowsRegex = false
                case 43, 45:
                    if index < units.count && units[index] == unit {
                        index += 1
                    } else {
                        allowsRegex = true
                    }
                default:
                    allowsRegex = true
                }
                previous = String(decoding: units[start..<index], as: UTF16.self)
                if unit == 61 && index < units.count && units[index] == 62 {
                    index += 1
                    previous = "=>"
                } else if unit == 63 && index < units.count && units[index] == 46 {
                    index += 1
                    previous = "."
                    allowsRegex = false
                }
            }
            if collectTokens, let kind {
                tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
            }
        }
        return false
    }

    mutating func consumeQuoted() {
        let quote = units[index]
        index += 1
        while index < units.count && !isNewline(units[index]) {
            let unit = units[index]
            index += 1
            if unit == quote { return }
            if unit == 92 && index < units.count {
                if units[index] == 13 && index + 1 < units.count && units[index + 1] == 10 { index += 1 }
                index += 1
            }
        }
    }

    mutating func consumeTemplate(depth: Int) throws {
        // Limit nested templates without losing source text or exhausting the stack.
        guard depth < 32 else { index = units.count; return }
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            let unit = units[index]
            if unit == 96 { index += 1; return }
            if unit == 92 {
                index = min(index + 2, units.count)
            } else if has([36, 123]) {
                index += 2
                try scanCode(collectTokens: false, interpolation: true, depth: depth + 1)
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeRegex() {
        index += 1
        var inClass = false
        while index < units.count && !isNewline(units[index]) {
            let unit = units[index]
            index += 1
            if unit == 92 {
                if index < units.count && !isNewline(units[index]) { index += 1 }
            } else if unit == 91 {
                inClass = true
            } else if unit == 93 {
                inClass = false
            } else if unit == 47 && !inClass {
                while index < units.count && isIdentifierPart(units[index]) { index += 1 }
                return
            }
        }
    }

    private mutating func consumeIdentifier() {
        while index < units.count {
            if has([92, 117]) {
                index += 2
                if index < units.count && units[index] == 123 {
                    index += 1
                    while index < units.count && isHex(units[index]) { index += 1 }
                    if index < units.count && units[index] == 125 { index += 1 }
                } else {
                    for _ in 0..<4 {
                        if index < units.count && isHex(units[index]) { index += 1 }
                    }
                }
            } else if isIdentifierPart(units[index]) {
                index += 1
            } else {
                return
            }
        }
    }

    private mutating func consumeNumber() {
        while index < units.count {
            let unit = units[index]
            if isIdentifierPart(unit) || unit == 46 {
                index += 1
            } else if (unit == 43 || unit == 45) && index > 0 && [69, 101].contains(units[index - 1]) {
                index += 1
            } else {
                return
            }
        }
    }

    func has(_ prefix: [UInt16]) -> Bool {
        index + prefix.count <= units.count && units[index..<(index + prefix.count)].elementsEqual(prefix)
    }
    private func isDigit(_ unit: UInt16) -> Bool { (48...57).contains(unit) }
    private func isHex(_ unit: UInt16) -> Bool { isDigit(unit) || (65...70).contains(unit) || (97...102).contains(unit) }
    private func isNewline(_ unit: UInt16) -> Bool { [10, 13, 0x2028, 0x2029].contains(unit) }
    func isSpace(_ unit: UInt16) -> Bool {
        unit <= 32 || [0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF].contains(unit) || (0x2000...0x200A).contains(unit)
    }
    func isIdentifierStart(_ unit: UInt16) -> Bool {
        (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || unit == 36 || (unit >= 128 && !isSpace(unit))
    }
    private func isIdentifierPart(_ unit: UInt16) -> Bool { isIdentifierStart(unit) || isDigit(unit) }

    private static let controls: Set<String> = ["if", "while", "for", "with", "switch", "catch"]
    private static let expressionPrefixes: Set<String> = ["return", "throw", "case", "delete", "void", "typeof", "instanceof", "in", "of", "yield", "await", "new", "else", "do"]
    private static let keywords: Set<String> = [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete",
        "do", "else", "export", "extends", "finally", "for", "function", "if", "import", "in", "instanceof",
        "let", "new", "of", "return", "static", "super", "switch", "this", "throw", "try", "typeof", "var", "void", "while", "with", "yield"
    ]
    private static let typeWords: Set<String> = [
        "abstract", "any", "as", "asserts", "bigint", "boolean", "declare", "enum", "implements", "infer", "interface",
        "is", "keyof", "module", "namespace", "never", "number", "object", "override", "private", "protected",
        "public", "readonly", "require", "satisfies", "string", "symbol", "type", "unique", "unknown"
    ]
    private static let number = try! NSRegularExpression(pattern: #"^(?:0[xX][0-9a-fA-F]+(?:_[0-9a-fA-F]+)*n?|0[bB][01]+(?:_[01]+)*n?|0[oO][0-7]+(?:_[0-7]+)*n?|(?:0|[1-9][0-9]*(?:_[0-9]+)*)n|(?:[0-9]+(?:_[0-9]+)*(?:\.(?:[0-9]+(?:_[0-9]+)*)?)?|\.[0-9]+(?:_[0-9]+)*)(?:[eE][+-]?[0-9]+(?:_[0-9]+)*)?)$"#)
}
