import Foundation

enum JSONConfigurationHighlighting {
    static func tokens(in text: String, json5: Bool) throws -> [SyntaxToken] {
        var scanner = JSONConfigurationScanner(units: Array(text.utf16), json5: json5)
        return try scanner.scan()
    }
}

private struct JSONConfigurationScanner {
    let units: [UInt16]
    let json5: Bool
    var index = 0
    var tokens: [SyntaxToken] = []

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            if isSpace(units[index]) || isDelimiter(units[index]) {
                index += 1
            } else if let end = commentEnd(at: index) {
                index = end
                append(.comment, from: start)
            } else if units[index] == 34 || (json5 && units[index] == 39) {
                index = quotedEnd(at: index)
                append(isKey(after: index) ? .key : .string, from: start)
            } else {
                index = atomEnd(at: index)
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if json5 && isKey(after: index) && matches(Self.identifier, word) {
                    append(.key, from: start)
                } else if ["true", "false", "null"].contains(word) {
                    append(.literal, from: start)
                } else if matches(json5 ? Self.json5Number : Self.jsonNumber, word) {
                    append(.number, from: start)
                }
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int) {
        tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
    }

    private func atomEnd(at start: Int) -> Int {
        var end = start
        while end < units.count && !isSpace(units[end]) && !isDelimiter(units[end]) && !isComment(at: end) { end += 1 }
        return max(start + 1, end)
    }

    private func quotedEnd(at start: Int) -> Int {
        let quote = units[start]
        var end = start + 1
        while end < units.count {
            if units[end] == quote { return end + 1 }
            if units[end] == 92 {
                end += 1
                if json5 && has([13, 10], at: end) { end += 2 }
                else { end = min(end + 1, units.count) }
            } else if units[end] == 10 || units[end] == 13 {
                return end
            } else {
                end += 1
            }
        }
        return end
    }

    private func isKey(after start: Int) -> Bool {
        var end = start
        while end < units.count {
            if isSpace(units[end]) { end += 1 }
            else if let comment = commentEnd(at: end) { end = comment }
            else { return units[end] == 58 }
        }
        return false
    }

    private func commentEnd(at start: Int) -> Int? {
        guard isComment(at: start) else { return nil }
        let line = units[start + 1] == 47
        var end = start + 2
        while end < units.count {
            if line && isNewline(units[end]) { return end }
            if !line && has([42, 47], at: end) { return end + 2 }
            end += 1
        }
        return end
    }

    private func isComment(at start: Int) -> Bool {
        start + 1 < units.count && units[start] == 47 && (units[start + 1] == 47 || units[start + 1] == 42)
    }
    private func has(_ prefix: [UInt16], at start: Int) -> Bool {
        start + prefix.count <= units.count && units[start..<(start + prefix.count)].elementsEqual(prefix)
    }
    private func isSpace(_ unit: UInt16) -> Bool {
        if [9, 10, 13, 32].contains(unit) { return true }
        if unit < 128 { return json5 && (unit == 11 || unit == 12) }
        guard json5, let scalar = UnicodeScalar(unit) else { return false }
        return unit == 0xfeff || CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
    private func isNewline(_ unit: UInt16) -> Bool {
        unit == 10 || unit == 13 || (json5 && (unit == 0x2028 || unit == 0x2029))
    }
    private func isDelimiter(_ unit: UInt16) -> Bool {
        switch unit {
        case 44, 58, 91, 93, 123, 125: true
        default: false
        }
    }
    private func matches(_ expression: NSRegularExpression, _ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        return expression.rangeOfFirstMatch(in: word, range: range) == range
    }

    private static let jsonNumber = try! NSRegularExpression(pattern: #"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#)
    private static let json5Number = try! NSRegularExpression(pattern: #"^[+-]?(?:0[xX][0-9a-fA-F]+|(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?|\.[0-9]+(?:[eE][+-]?[0-9]+)?|Infinity|NaN)$"#)
    private static let identifier = try! NSRegularExpression(pattern: #"^(?:[$_\p{L}\p{Nl}]|\\u[0-9a-fA-F]{4})(?:[$\p{L}\p{Nl}\p{Mn}\p{Mc}\p{Nd}\p{Pc}\u200C\u200D]|\\u[0-9a-fA-F]{4})*$"#)
}
