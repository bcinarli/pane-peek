import Foundation

enum RustHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = RustScanner(text: text)
        return try scanner.scan()
    }
}

private struct RustScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []

    init(text: String) {
        units = Array(text.utf16)
    }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            var kind: SyntaxToken.Kind?
            if SyntaxScanning.hasPrefix([47, 47], in: units, at: index) {
                while index < units.count && units[index] != 10 {
                    try Task.checkCancellation()
                    index += 1
                }
                kind = .comment
            } else if SyntaxScanning.hasPrefix([47, 42], in: units, at: index) {
                try consumeComment()
                kind = .comment
            } else if let opening = stringOpening() {
                try consumeString(quote: opening.quote, hashes: opening.hashes)
                try consumeName()
                kind = .string
            } else if units[index] == 39 || SyntaxScanning.hasPrefix([98, 39], in: units, at: index) {
                let quote = units[index] == 39 ? index : index + 1
                if let end = try characterEnd(at: quote) {
                    index = end
                    try consumeName()
                    kind = .string
                } else if quote == index {
                    index += 1
                    if SyntaxScanning.hasPrefix([114, 35], in: units, at: index) && nameWidth(at: index + 2, continuation: false) > 0 { index += 2 }
                    if nameWidth(at: index, continuation: false) > 0 {
                        try consumeName()
                        kind = .reference
                    }
                } else {
                    index += 1
                }
            } else if SyntaxScanning.hasPrefix([114, 35], in: units, at: index) && nameWidth(at: index + 2, continuation: false) > 0 {
                index += 2
                try consumeName()
            } else if nameWidth(at: index, continuation: false) > 0 {
                try consumeName()
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if ["true", "false"].contains(word) { kind = .literal }
                else if Self.keywords.contains(word) { kind = .keyword }
            } else if SyntaxScanning.isASCIIDigit(units[index]) {
                if try consumeNumber() { kind = .number }
            } else {
                index += 1
            }
            if let kind {
                tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func consumeComment() throws {
        index += 2
        var depth = 1
        while index < units.count {
            try Task.checkCancellation()
            if SyntaxScanning.hasPrefix([47, 42], in: units, at: index) {
                depth += 1
                index += 2
            } else if SyntaxScanning.hasPrefix([42, 47], in: units, at: index) {
                depth -= 1
                index += 2
                if depth == 0 { return }
            } else {
                index += 1
            }
        }
    }

    private func stringOpening() -> (quote: Int, hashes: Int?)? {
        var quote = index
        if units[quote] == 34 { return (quote, nil) }
        if units[quote] == 98 || units[quote] == 99 {
            quote += 1
            if quote < units.count && units[quote] == 34 { return (quote, nil) }
        }
        guard quote < units.count && units[quote] == 114 else { return nil }
        quote += 1
        var hashes = 0
        while quote < units.count && units[quote] == 35 && hashes < 256 {
            hashes += 1
            quote += 1
        }
        guard hashes <= 255 && quote < units.count && units[quote] == 34 else { return nil }
        return (quote, hashes)
    }

    private mutating func consumeString(quote: Int, hashes: Int?) throws {
        index = quote + 1
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 34 {
                if let hashes {
                    var end = index + 1
                    while end < units.count && end < index + 1 + hashes && units[end] == 35 { end += 1 }
                    if end == index + 1 + hashes {
                        index = end
                        return
                    }
                } else {
                    index += 1
                    return
                }
            } else if hashes == nil && units[index] == 92 {
                index += 1
                if index < units.count { index += 1 }
                continue
            }
            index += 1
        }
    }

    private func characterEnd(at quote: Int) throws -> Int? {
        var end = quote + 1
        guard end < units.count else { return nil }
        if units[end] == 92 {
            end += 1
            guard end < units.count else { return nil }
            if units[end] == 120 {
                end += 1
                guard end + 1 < units.count && SyntaxScanning.isASCIIHexDigit(units[end]) && SyntaxScanning.isASCIIHexDigit(units[end + 1]) else { return nil }
                end += 2
            } else if SyntaxScanning.hasPrefix([117, 123], in: units, at: end) {
                end += 2
                var digits = 0
                while end < units.count && (SyntaxScanning.isASCIIHexDigit(units[end]) || units[end] == 95) {
                    try Task.checkCancellation()
                    if units[end] != 95 { digits += 1 }
                    if digits > 6 { return nil }
                    end += 1
                }
                guard digits > 0 && end < units.count && units[end] == 125 else { return nil }
                end += 1
            } else if [110, 114, 116, 92, 48, 39, 34].contains(units[end]) {
                end += 1
            } else { return nil }
        } else {
            guard ![9, 10, 13, 39].contains(units[end]) else { return nil }
            end += SyntaxScanning.scalar(in: units, at: end).width
        }
        return end < units.count && units[end] == 39 ? end + 1 : nil
    }

    private mutating func consumeName() throws {
        guard nameWidth(at: index, continuation: false) > 0 else { return }
        while index < units.count {
            let width = nameWidth(at: index, continuation: true)
            guard width > 0 else { return }
            try Task.checkCancellation()
            index += width
        }
    }

    private mutating func consumeNumber() throws -> Bool {
        var radix = 10
        if SyntaxScanning.hasPrefix([48, 98], in: units, at: index) { radix = 2; index += 2 }
        else if SyntaxScanning.hasPrefix([48, 111], in: units, at: index) { radix = 8; index += 2 }
        else if SyntaxScanning.hasPrefix([48, 120], in: units, at: index) { radix = 16; index += 2 }
        var digits = 0
        var valid = true
        while index < units.count && (SyntaxScanning.isASCIIDigit(units[index]) || units[index] == 95 || (radix == 16 && SyntaxScanning.isASCIIHexDigit(units[index]))) {
            try Task.checkCancellation()
            if units[index] != 95 {
                digits += 1
                if radix < 10 && Int(units[index] - 48) >= radix { valid = false }
            }
            index += 1
        }
        valid = valid && digits > 0
        if index < units.count && units[index] == 46 && !SyntaxScanning.hasPrefix([46, 46], in: units, at: index) && nameWidth(at: index + 1, continuation: false) == 0 {
            index += 1
            if radix != 10 { valid = false }
            while index < units.count && (SyntaxScanning.isASCIIDigit(units[index]) || units[index] == 95) {
                try Task.checkCancellation()
                index += 1
            }
        }
        if index < units.count && [69, 101].contains(units[index]) {
            if radix != 10 { valid = false }
            index += 1
            if index < units.count && [43, 45].contains(units[index]) { index += 1 }
            var exponentDigits = 0
            while index < units.count && (SyntaxScanning.isASCIIDigit(units[index]) || units[index] == 95) {
                try Task.checkCancellation()
                if units[index] != 95 { exponentDigits += 1 }
                index += 1
            }
            valid = valid && exponentDigits > 0
        }
        try consumeName()
        return valid
    }

    private func nameWidth(at position: Int, continuation: Bool) -> Int {
        guard position < units.count else { return 0 }
        let unit = units[position]
        if (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || (continuation && SyntaxScanning.isASCIIDigit(unit)) { return 1 }
        guard unit >= 128 else { return 0 }
        let character = SyntaxScanning.scalar(in: units, at: position)
        guard let value = character.value else { return 0 }
        return (continuation ? value.properties.isXIDContinue : value.properties.isXIDStart) ? character.width : 0
    }

    private static let keywords: Set<String> = [
        "_", "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
        "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
        "self", "Self", "static", "struct", "super", "trait", "type", "unsafe", "use", "where", "while",
        "abstract", "become", "box", "do", "final", "gen", "macro", "override", "priv", "try", "typeof",
        "unsized", "virtual", "yield", "macro_rules", "union"
    ]
}
