import Foundation

enum CSharpHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = CSharpScanner(text: text)
        return try scanner.scan()
    }
}

private struct CSharpScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []

    init(text: String) {
        units = Array(text.utf16)
    }

    mutating func scan() throws -> [SyntaxToken] {
        var member = false
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            if isSpace(unit) || isNewline(unit) {
                index += 1
                continue
            }
            if unit == 46 || has([58, 58], at: index) || has([45, 62], at: index) {
                index += unit == 46 ? 1 : 2
                member = true
                continue
            }
            var kind: SyntaxToken.Kind?
            if try consumeComment() {
                kind = .comment
            } else if let opening = try stringOpening() {
                let closed = try consumeString(opening, depth: 0)
                if closed && opening.quote == 34 && opening.dollars == 0 && (has([117, 56], at: index) || has([85, 56], at: index)) {
                    index += 2
                }
                kind = .string
            } else if unit == 64 || nameWidth(at: index, continuation: false) > 0 {
                if unit == 64 { index += 1 }
                try consumeName()
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if ["true", "false", "null"].contains(word) { kind = .literal }
                else if Self.keywords.contains(word) || (!member && Self.contextualKeywords.contains(word)) { kind = .keyword }
            } else if isDigit(unit) {
                index += 1
                try consumeName()
            } else if unit == 36 {
                index = try runEnd(of: unit, at: index)
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

    private mutating func consumeComment() throws -> Bool {
        let block = has([47, 42], at: index)
        guard block || has([47, 47], at: index) else { return false }
        index += 2
        while index < units.count {
            try Task.checkCancellation()
            if block && has([42, 47], at: index) {
                index += 2
                return true
            }
            if !block && isNewline(units[index]) { return true }
            index += 1
        }
        return true
    }

    private struct StringOpening {
        let end: Int
        let quote: UInt16
        let quotes: Int
        let verbatim: Bool
        let dollars: Int
        var raw: Bool { quotes >= 3 }
    }

    private func stringOpening() throws -> StringOpening? {
        var quote = index
        var verbatim = false
        var dollars = 0
        if units[quote] == 64 {
            verbatim = true
            quote += 1
            if quote < units.count && units[quote] == 36 { dollars = 1; quote += 1 }
        } else if units[quote] == 36 {
            quote = try runEnd(of: 36, at: quote)
            dollars = quote - index
            if quote < units.count && units[quote] == 64 { verbatim = true; quote += 1 }
        }
        guard quote < units.count && (units[quote] == 34 || (quote == index && units[quote] == 39)) else { return nil }
        let end = units[quote] == 34 && !verbatim ? try runEnd(of: 34, at: quote) : quote + 1
        let quotes = units[quote] == 34 && !verbatim && end - quote >= 3 ? end - quote : 1
        guard dollars <= 1 || (quotes >= 3 && !verbatim) else { return nil }
        return StringOpening(end: quote + quotes, quote: units[quote], quotes: quotes, verbatim: verbatim, dollars: dollars)
    }

    private mutating func consumeString(_ opening: StringOpening, depth: Int) throws -> Bool {
        // Interpolated expressions retain the containing string colour, with bounded recursion.
        guard depth < 32 else { index = units.count; return false }
        index = opening.end
        var multiline = opening.verbatim
        if opening.raw {
            var line = index
            while line < units.count && isSpace(units[line]) {
                try Task.checkCancellation()
                line += 1
            }
            multiline = line < units.count && isNewline(units[line])
        }
        var lineStart = false
        while index < units.count {
            try Task.checkCancellation()
            let unit = units[index]
            if unit == opening.quote {
                if opening.raw {
                    let end = try runEnd(of: unit, at: index)
                    if end - index == opening.quotes && (!multiline || lineStart) {
                        index = end
                        return true
                    }
                    index = end
                    lineStart = false
                } else if opening.verbatim && has([34, 34], at: index) {
                    index += 2
                } else {
                    index += 1
                    return true
                }
            } else if isNewline(unit) {
                if !multiline { return false }
                index += 1
                lineStart = true
            } else if opening.dollars > 0 && unit == 123 {
                let end = try runEnd(of: unit, at: index)
                let count = end - index
                if opening.raw {
                    index = end
                    if count >= opening.dollars { try consumeField(opening, depth: depth + 1) }
                } else {
                    index += count - count % 2
                    if count % 2 == 1 {
                        index += 1
                        try consumeField(opening, depth: depth + 1)
                    }
                }
                lineStart = false
            } else if unit == 92 && !opening.raw && !opening.verbatim {
                index += 1
                if index < units.count && !isNewline(units[index]) { index += 1 }
            } else {
                if !isSpace(unit) { lineStart = false }
                index += 1
            }
        }
        return false
    }

    private mutating func consumeField(_ opening: StringOpening, depth: Int) throws {
        guard depth < 32 else { index = units.count; return }
        var delimiters: [UInt16] = []
        while index < units.count {
            try Task.checkCancellation()
            if try consumeComment() { continue }
            if let nested = try stringOpening() {
                _ = try consumeString(nested, depth: depth)
            } else if units[index] == 125 && delimiters.isEmpty {
                let end = try runEnd(of: 125, at: index)
                if end - index >= opening.dollars {
                    index += opening.dollars
                    return
                }
                index = end
            } else if [40, 91, 123].contains(units[index]) {
                delimiters.append(units[index] == 40 ? 41 : units[index] == 91 ? 93 : 125)
                index += 1
            } else if delimiters.last == units[index] {
                delimiters.removeLast()
                index += 1
            } else if has([58, 58], at: index) {
                index += 2
            } else if units[index] == 58 && delimiters.isEmpty {
                index += 1
                try consumeFormat(opening)
                return
            } else if units[index] == 36 {
                index = try runEnd(of: 36, at: index)
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeFormat(_ opening: StringOpening) throws {
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 34 {
                if opening.raw {
                    let end = try runEnd(of: 34, at: index)
                    if end - index >= opening.quotes { return }
                    index = end
                } else if opening.verbatim && has([34, 34], at: index) {
                    index += 2
                } else { return }
            } else if isNewline(units[index]) && !opening.raw && !opening.verbatim {
                return
            } else if units[index] == 125 {
                let end = try runEnd(of: 125, at: index)
                if end - index >= opening.dollars {
                    index += opening.dollars
                    return
                }
                index = end
            } else if units[index] == 92 && !opening.raw && !opening.verbatim {
                index += 1
                if index < units.count && !isNewline(units[index]) { index += 1 }
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeName() throws {
        while index < units.count {
            let width = nameWidth(at: index, continuation: true)
            guard width > 0 else { return }
            try Task.checkCancellation()
            index += width
        }
    }

    private func nameWidth(at position: Int, continuation: Bool) -> Int {
        guard position < units.count else { return 0 }
        let unit = units[position]
        if (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || (continuation && isDigit(unit)) { return 1 }
        if unit == 92 && position + 1 < units.count && [117, 85].contains(units[position + 1]) {
            let width = units[position + 1] == 117 ? 6 : 10
            guard position + width <= units.count else { return 0 }
            return units[position + 2..<position + width].allSatisfy { isDigit($0) || (65...70).contains($0) || (97...102).contains($0) } ? width : 0
        }
        guard unit >= 128 else { return 0 }
        let (scalar, width) = SyntaxScanning.scalar(in: units, at: position)
        guard let category = scalar?.properties.generalCategory else { return 0 }
        switch category {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .letterNumber: return width
        case .decimalNumber, .connectorPunctuation, .nonspacingMark, .spacingMark, .format: return continuation ? width : 0
        default: return 0
        }
    }

    private func runEnd(of unit: UInt16, at start: Int) throws -> Int {
        var end = start
        while end < units.count && units[end] == unit {
            try Task.checkCancellation()
            end += 1
        }
        return end
    }
    private func has(_ prefix: [UInt16], at position: Int) -> Bool {
        position + prefix.count <= units.count && units[position..<position + prefix.count].elementsEqual(prefix)
    }
    private func isDigit(_ unit: UInt16) -> Bool { (48...57).contains(unit) }
    private func isNewline(_ unit: UInt16) -> Bool { [10, 13, 0x85, 0x2028, 0x2029].contains(unit) }
    private func isSpace(_ unit: UInt16) -> Bool { [9, 11, 12, 32].contains(unit) || Unicode.Scalar(UInt32(unit))?.properties.generalCategory == .spaceSeparator }

    private static let keywords: Set<String> = [
        "abstract", "as", "base", "bool", "break", "byte", "case", "catch", "char", "checked", "class",
        "const", "continue", "decimal", "default", "delegate", "do", "double", "else", "enum", "event",
        "explicit", "extern", "finally", "fixed", "float", "for", "foreach", "goto", "if", "implicit", "in",
        "int", "interface", "internal", "is", "lock", "long", "namespace", "new", "object", "operator",
        "out", "override", "params", "private", "protected", "public", "readonly", "ref", "return", "sbyte",
        "sealed", "short", "sizeof", "stackalloc", "static", "string", "struct", "switch", "this", "throw",
        "try", "typeof", "uint", "ulong", "unchecked", "unsafe", "ushort", "using", "virtual", "void", "volatile", "while"
    ]
    private static let contextualKeywords: Set<String> = [
        "add", "alias", "allows", "and", "ascending", "async", "await", "by", "Cdecl", "descending",
        "dynamic", "equals", "Fastcall", "field", "file", "from", "get", "global", "group", "init", "into",
        "join", "let", "managed", "nameof", "nint", "not", "notnull", "nuint", "on", "or", "orderby",
        "partial", "record", "remove", "required", "scoped", "select", "set", "Stdcall", "Thiscall",
        "unmanaged", "value", "var", "when", "where", "yield"
    ]
}
