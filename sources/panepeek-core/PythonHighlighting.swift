import Foundation

enum PythonHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = PythonScanner(text: text)
        return try scanner.scan()
    }
}

private struct PythonScanner {
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
            if unit == 35 {
                try consumeComment()
                kind = .comment
            } else if let opening = stringOpening() {
                try consumeString(opening: opening, depth: 0)
                kind = .string
            } else if nameWidth(at: index, continuation: false) > 0 {
                try consumeName()
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if ["True", "False", "None"].contains(word) { kind = .literal }
                else if Self.keywords.contains(word) || (!member && Self.softKeywords.contains(word)) { kind = .keyword }
            } else if SyntaxScanning.isASCIIDigit(unit) || (unit == 46 && index + 1 < units.count && SyntaxScanning.isASCIIDigit(units[index + 1])) {
                if try consumeNumber() { kind = .number }
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

    private mutating func consumeComment() throws {
        while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
            try Task.checkCancellation()
            index += 1
        }
    }

    private func stringOpening() -> (quote: Int, formatted: Bool, raw: Bool)? {
        if [34, 39].contains(units[index]) { return (index, false, false) }
        var quote = index
        while quote < units.count && quote < index + 2 && isLetter(units[quote]) { quote += 1 }
        guard quote > index && quote < units.count && [34, 39].contains(units[quote]) else { return nil }
        let prefix = String(decoding: units[index..<quote], as: UTF16.self).lowercased()
        guard Self.stringPrefixes.contains(prefix) else { return nil }
        return (quote, prefix.contains("f") || prefix.contains("t"), prefix.contains("r"))
    }

    private mutating func consumeString(opening: (quote: Int, formatted: Bool, raw: Bool), depth: Int) throws {
        // Bound mixed string/field recursion while keeping pathological source readable.
        guard depth < 32 else { index = units.count; return }
        let quote = units[opening.quote]
        let count = SyntaxScanning.hasPrefix([quote, quote, quote], in: units, at: opening.quote) ? 3 : 1
        let closing = Array(repeating: quote, count: count)
        index = opening.quote + count
        while index < units.count {
            try Task.checkCancellation()
            if SyntaxScanning.hasPrefix(closing, in: units, at: index) {
                index += count
                return
            } else if count == 1 && SyntaxScanning.isCRorLF(units[index]) {
                return
            } else if opening.formatted && SyntaxScanning.hasPrefix([123, 123], in: units, at: index) {
                index += 2
            } else if opening.formatted && units[index] == 123 {
                index += 1
                try consumeField(depth: depth + 1)
            } else if units[index] == 92 {
                index += 1
                if opening.formatted && !opening.raw && SyntaxScanning.hasPrefix([78, 123], in: units, at: index) {
                    index += 2
                    while index < units.count && units[index] != 125 && !SyntaxScanning.isCRorLF(units[index]) {
                        try Task.checkCancellation()
                        index += 1
                    }
                    if index < units.count && units[index] == 125 { index += 1 }
                } else if index < units.count && !(opening.formatted && [123, 125].contains(units[index])) {
                    if SyntaxScanning.hasPrefix([13, 10], in: units, at: index) { index += 2 }
                    else { index += 1 }
                }
            } else {
                index += 1
            }
        }
    }

    // Replacement fields retain their containing string colour.
    private mutating func consumeField(depth: Int) throws {
        guard depth < 32 else { index = units.count; return }
        var delimiters: [UInt16] = []
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 35 {
                try consumeComment()
            } else if let opening = stringOpening() {
                try consumeString(opening: opening, depth: depth)
            } else if [40, 91, 123].contains(units[index]) {
                delimiters.append(units[index] == 40 ? 41 : units[index] == 91 ? 93 : 125)
                index += 1
            } else if units[index] == 125 && delimiters.isEmpty {
                index += 1
                return
            } else if delimiters.last == units[index] {
                delimiters.removeLast()
                index += 1
            } else if units[index] == 58 && delimiters.isEmpty {
                index += 1
                try consumeFormat(depth: depth)
                return
            } else if nameWidth(at: index, continuation: false) > 0 {
                try consumeName()
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeFormat(depth: Int) throws {
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 125 {
                index += 1
                return
            } else if units[index] == 123 {
                index += 1
                try consumeField(depth: depth + 1)
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

    private mutating func consumeNumber() throws -> Bool {
        let start = index
        for (prefix, radix) in [(UInt16(98), 2), (111, 8), (120, 16)] {
            if SyntaxScanning.hasPrefix([48, prefix], in: units, at: index) || SyntaxScanning.hasPrefix([48, prefix - 32], in: units, at: index) {
                index += 2
                if index < units.count && units[index] == 95 { index += 1 }
                let valid = try consumeDigits(radix: radix)
                let end = index
                try consumeName()
                return valid && end == index
            }
        }
        let integerStart = index
        var valid = true
        if units[index] != 46 { valid = try consumeDigits(radix: 10) }
        let integerEnd = index
        var floating = false
        if index < units.count && units[index] == 46 && !SyntaxScanning.hasPrefix([46, 46], in: units, at: index) {
            floating = true
            index += 1
            if index < units.count && (SyntaxScanning.isASCIIDigit(units[index]) || units[index] == 95) {
                let fraction = try consumeDigits(radix: 10)
                valid = valid && fraction
            } else if integerStart == integerEnd {
                valid = false
            }
        }
        if index < units.count && [69, 101].contains(units[index]) {
            floating = true
            index += 1
            if index < units.count && [43, 45].contains(units[index]) { index += 1 }
            let exponent = try consumeDigits(radix: 10)
            valid = valid && exponent
        }
        let imaginary = index < units.count && [74, 106].contains(units[index])
        if imaginary { index += 1 }
        if !floating && !imaginary && units[start] == 48 {
            valid = valid && units[integerStart..<integerEnd].allSatisfy { $0 == 48 || $0 == 95 }
        }
        let end = index
        try consumeName()
        return valid && end == index
    }

    private mutating func consumeDigits(radix: Int) throws -> Bool {
        var valid = true
        var previousDigit = false
        var digits = 0
        while index < units.count {
            let unit = units[index]
            let hex = (65...70).contains(unit) || (97...102).contains(unit)
            guard SyntaxScanning.isASCIIDigit(unit) || unit == 95 || (radix == 16 && hex) else { break }
            try Task.checkCancellation()
            if unit == 95 {
                valid = valid && previousDigit
                previousDigit = false
            } else {
                if radix < 10 && Int(unit - 48) >= radix { valid = false }
                previousDigit = true
                digits += 1
            }
            index += 1
        }
        return valid && previousDigit && digits > 0
    }

    private func nameWidth(at position: Int, continuation: Bool) -> Int {
        guard position < units.count else { return 0 }
        let unit = units[position]
        if isLetter(unit) || unit == 95 || (continuation && SyntaxScanning.isASCIIDigit(unit)) { return 1 }
        guard unit >= 128 else { return 0 }
        let (scalar, width) = SyntaxScanning.scalar(in: units, at: position)
        guard let scalar else { return 0 }
        return (continuation ? scalar.properties.isXIDContinue : scalar.properties.isXIDStart) ? width : 0
    }

    private func isLetter(_ unit: UInt16) -> Bool { (65...90).contains(unit) || (97...122).contains(unit) }

    private static let keywords: Set<String> = [
        "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif",
        "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda",
        "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"
    ]
    private static let stringPrefixes: Set<String> = ["r", "u", "b", "br", "rb", "f", "fr", "rf", "t", "tr", "rt"]
    private static let softKeywords: Set<String> = ["match", "case", "_", "type", "lazy"]
}
