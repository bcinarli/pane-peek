import Foundation

enum GoHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = GoScanner(text: text)
        return try scanner.scan()
    }
}

private struct GoScanner {
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
            if [9, 10, 13, 32].contains(unit) {
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
                while index < units.count && units[index] != 10 {
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
            } else if unit == 34 || unit == 39 || unit == 96 {
                try consumeString()
                kind = .string
            } else if nameWidth(at: index, digits: false) > 0 {
                index += nameWidth(at: index, digits: false)
                while index < units.count {
                    let width = nameWidth(at: index, digits: true)
                    guard width > 0 else { break }
                    try Task.checkCancellation()
                    index += width
                }
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if Self.keywords.contains(word) { kind = .keyword }
                else if !member && ["true", "false", "nil", "iota"].contains(word) { kind = .literal }
            } else if SyntaxScanning.isASCIIDigit(unit) || (unit == 46 && index + 1 < units.count && SyntaxScanning.isASCIIDigit(units[index + 1])) {
                try consumeNumber()
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

    private mutating func consumeString() throws {
        let quote = units[index]
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == quote {
                index += 1
                return
            } else if quote != 96 && units[index] == 10 {
                return
            } else if quote != 96 && units[index] == 92 {
                index += 1
                if index < units.count && units[index] != 10 { index += 1 }
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeNumber() throws {
        let hexadecimal = SyntaxScanning.hasPrefix([48, 120], in: units, at: index) || SyntaxScanning.hasPrefix([48, 88], in: units, at: index)
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            let width = nameWidth(at: index, digits: true)
            if width > 0 { index += width }
            else if units[index] == 46 { index += 1 }
            else if [43, 45].contains(units[index]) && (hexadecimal ? [80, 112] : [69, 101]).contains(units[index - 1]) {
                index += 1
            } else { break }
        }
    }

    private func nameWidth(at position: Int, digits: Bool) -> Int {
        guard position < units.count else { return 0 }
        let unit = units[position]
        if (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || (digits && SyntaxScanning.isASCIIDigit(unit)) { return 1 }
        guard unit >= 128 else { return 0 }
        let (scalar, width) = SyntaxScanning.scalar(in: units, at: position)
        guard let scalar else { return 0 }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: return width
        case .decimalNumber: return digits ? width : 0
        default: return 0
        }
    }

    private static let keywords: Set<String> = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func",
        "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct",
        "switch", "type", "var"
    ]
    private static let number: NSRegularExpression = {
        let decimal = #"[0-9](?:_?[0-9])*"#
        let hex = #"[0-9a-fA-F](?:_?[0-9a-fA-F])*"#
        let exponent = #"[eE][+-]?"# + decimal
        let integer = #"(?:0|[1-9](?:_?[0-9])*|0[bB]_?[01](?:_?[01])*|0[oO]?_?[0-7](?:_?[0-7])*|0[xX]_?\#(hex))"#
        let decimalFloat = #"(?:\#(decimal)\.(?:\#(decimal))?(?:\#(exponent))?|\#(decimal)\#(exponent)|\.\#(decimal)(?:\#(exponent))?)"#
        let hexFloat = #"0[xX](?:_?\#(hex)\.(?:\#(hex))?|_?\#(hex)|\.\#(hex))[pP][+-]?\#(decimal)"#
        return try! NSRegularExpression(pattern: #"^(?:(?:\#(integer)|\#(decimalFloat)|\#(hexFloat))i?|\#(decimal)i)$"#)
    }()
}
