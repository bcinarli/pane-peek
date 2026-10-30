import Foundation

enum JavaHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = try JavaScanner(text: text)
        return try scanner.scan()
    }
}

private struct JavaScanner {
    let units: [UInt16]
    let sourceOffsets: [Int]
    var index = 0
    var tokens: [SyntaxToken] = []

    init(text: String) throws {
        (units, sourceOffsets) = try Self.translateUnicode(Array(text.utf16))
    }

    mutating func scan() throws -> [SyntaxToken] {
        var member = false
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            if [9, 10, 12, 13, 32].contains(unit) {
                index += 1
                continue
            }
            if unit == 46 && (index + 1 == units.count || !SyntaxScanning.isASCIIDigit(units[index + 1])) {
                index += 1
                member = true
                continue
            }
            var kind: SyntaxToken.Kind?
            if SyntaxScanning.hasPrefix([47, 47], in: units, at: index) {
                while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
                    try Task.checkCancellation()
                    index += 1
                }
                kind = .comment
            } else if SyntaxScanning.hasPrefix([47, 42], in: units, at: index) {
                index += 2
                while index < units.count && !SyntaxScanning.hasPrefix([42, 47], in: units, at: index) {
                    try Task.checkCancellation()
                    index += 1
                }
                if index < units.count { index += 2 }
                kind = .comment
            } else if unit == 34 || unit == 39 {
                try consumeString()
                kind = .string
            } else if unit == 110 && SyntaxScanning.hasPrefix(Self.nonSealed, in: units, at: index) && nameWidth(at: index + Self.nonSealed.count, continuation: true) == 0 {
                index += Self.nonSealed.count
                kind = .keyword
            } else if nameWidth(at: index, continuation: false) > 0 {
                index += nameWidth(at: index, continuation: false)
                while index < units.count {
                    let width = nameWidth(at: index, continuation: true)
                    guard width > 0 else { break }
                    try Task.checkCancellation()
                    index += width
                }
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if Self.keywords.contains(word) || (!member && Self.contextualKeywords.contains(word)) {
                    kind = .keyword
                } else if ["true", "false", "null"].contains(word) {
                    kind = .literal
                }
            } else if SyntaxScanning.isASCIIDigit(unit) || (unit == 46 && index + 1 < units.count && SyntaxScanning.isASCIIDigit(units[index + 1])) {
                try consumeNumber()
                let word = String(decoding: units[start..<index], as: UTF16.self)
                let range = NSRange(location: 0, length: word.utf16.count)
                if Self.number.rangeOfFirstMatch(in: word, range: range) == range { kind = .number }
            } else {
                index += 1
            }
            if let kind {
                let range = NSRange(location: sourceOffsets[start], length: sourceOffsets[index] - sourceOffsets[start])
                tokens.append(SyntaxToken(range: range, kind: kind))
            }
            if kind != .comment { member = false }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func consumeString() throws {
        let quote = units[index]
        let block = try textBlockOpening()
        index += block ? 3 : 1
        while index < units.count {
            try Task.checkCancellation()
            if block ? SyntaxScanning.hasPrefix([34, 34, 34], in: units, at: index) : units[index] == quote {
                index += block ? 3 : 1
                return
            } else if !block && SyntaxScanning.isCRorLF(units[index]) {
                return
            } else if units[index] == 92 {
                index += 1
                if index < units.count && (block || !SyntaxScanning.isCRorLF(units[index])) { index += 1 }
            } else {
                index += 1
            }
        }
    }

    private func textBlockOpening() throws -> Bool {
        guard SyntaxScanning.hasPrefix([34, 34, 34], in: units, at: index) else { return false }
        var position = index + 3
        while position < units.count && [9, 12, 32].contains(units[position]) {
            try Task.checkCancellation()
            position += 1
        }
        return position < units.count && SyntaxScanning.isCRorLF(units[position])
    }

    private mutating func consumeNumber() throws {
        let hexadecimal = SyntaxScanning.hasPrefix([48, 120], in: units, at: index) || SyntaxScanning.hasPrefix([48, 88], in: units, at: index)
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            let width = nameWidth(at: index, continuation: true)
            if width > 0 { index += width }
            else if units[index] == 46 { index += 1 }
            else if [43, 45].contains(units[index]) && (hexadecimal ? [80, 112] : [69, 101]).contains(units[index - 1]) {
                index += 1
            } else { break }
        }
    }

    private func nameWidth(at position: Int, continuation: Bool) -> Int {
        guard position < units.count else { return 0 }
        let unit = units[position]
        if (65...90).contains(unit) || (97...122).contains(unit) || [36, 95].contains(unit) { return 1 }
        if continuation && (SyntaxScanning.isASCIIDigit(unit) || (0...8).contains(unit) || (14...27).contains(unit) || (127...159).contains(unit)) { return 1 }
        guard unit >= 128 else { return 0 }
        let (scalar, width) = SyntaxScanning.scalar(in: units, at: position)
        guard let scalar else { return 0 }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .letterNumber, .currencySymbol, .connectorPunctuation:
            return width
        case .decimalNumber, .nonspacingMark, .spacingMark, .format:
            return continuation ? width : 0
        default:
            return 0
        }
    }

    // Java translates Unicode escapes before lexing; colours still cover the original source.
    private static func translateUnicode(_ source: [UInt16]) throws -> ([UInt16], [Int]) {
        var translated: [UInt16] = []
        var offsets: [Int] = []
        translated.reserveCapacity(source.count)
        offsets.reserveCapacity(source.count + 1)
        var position = 0
        var backslashes = 0
        var previousWasEscape = false
        while position < source.count {
            try Task.checkCancellation()
            let start = position
            var unit = source[position]
            var escaped = false
            if unit == 92 && (previousWasEscape || backslashes.isMultiple(of: 2)) {
                var digits = position + 1
                while digits < source.count && source[digits] == 117 {
                    try Task.checkCancellation()
                    digits += 1
                }
                if digits > position + 1 && digits + 4 <= source.count {
                    var value: UInt16 = 0
                    var valid = true
                    for digit in source[digits..<digits + 4] {
                        guard let hex = hexValue(digit) else { valid = false; break }
                        value = value * 16 + hex
                    }
                    if valid {
                        unit = value
                        position = digits + 4
                        escaped = true
                    }
                }
            }
            if !escaped { position += 1 }
            translated.append(unit)
            offsets.append(start)
            backslashes = unit == 92 ? backslashes + 1 : 0
            previousWasEscape = escaped
        }
        offsets.append(source.count)
        return (translated, offsets)
    }

    private static func hexValue(_ unit: UInt16) -> UInt16? {
        if SyntaxScanning.isASCIIDigit(unit) { return unit - 48 }
        if (65...70).contains(unit) { return unit - 55 }
        if (97...102).contains(unit) { return unit - 87 }
        return nil
    }

    private static let nonSealed = Array("non-sealed".utf16)
    private static let keywords: Set<String> = [
        "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const",
        "continue", "default", "do", "double", "else", "enum", "extends", "final", "finally", "float",
        "for", "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native",
        "new", "package", "private", "protected", "public", "return", "short", "static", "strictfp",
        "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "void",
        "volatile", "while", "_"
    ]
    private static let contextualKeywords: Set<String> = [
        "exports", "module", "open", "opens", "permits", "provides", "record", "requires", "sealed",
        "to", "transitive", "uses", "var", "when", "with", "yield"
    ]
    private static let number: NSRegularExpression = {
        let decimal = #"[0-9](?:[0-9_]*[0-9])?"#
        let hex = #"[0-9a-fA-F](?:[0-9a-fA-F_]*[0-9a-fA-F])?"#
        let binary = #"[01](?:[01_]*[01])?"#
        let exponent = #"[eE][+-]?"# + decimal
        let integer = #"(?:0|[1-9](?:[0-9_]*[0-9])?|0[0-7_]*[0-7]|0[xX]\#(hex)|0[bB]\#(binary))[lL]?"#
        let decimalFloat = #"(?:\#(decimal)\.(?:\#(decimal))?(?:\#(exponent))?[fFdD]?|\.\#(decimal)(?:\#(exponent))?[fFdD]?|\#(decimal)\#(exponent)[fFdD]?|\#(decimal)[fFdD])"#
        let hexFloat = #"0[xX](?:\#(hex)\.?|(?:\#(hex))?\.\#(hex))[pP][+-]?\#(decimal)[fFdD]?"#
        return try! NSRegularExpression(pattern: #"^(?:\#(integer)|\#(decimalFloat)|\#(hexFloat))$"#)
    }()
}
