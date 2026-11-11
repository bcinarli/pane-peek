import Foundation

enum KotlinHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = KotlinScanner(text: text)
        return try scanner.scan()
    }
}

private struct KotlinScanner {
    /// Strings and template expressions nest arbitrarily, so they live on an explicit stack rather than the call stack.
    private enum Mode { case string(raw: Bool), template(depth: Int) }
    /// Soft and modifier keywords read as names after member access or a declaring keyword.
    private enum Context { case other, member, declaration }

    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []
    private var modes: [Mode] = []
    var segment = 0
    private var context = Context.other
    var wordEnd = -1

    init(text: String) {
        units = Array(text.utf16)
    }

    mutating func scan() throws -> [SyntaxToken] {
        if units.first == 0xfeff { index = 1 }
        if SyntaxScanning.hasPrefix([35, 33], in: units, at: index) {
            let start = index
            try consumeLine()
            append(from: start, .comment)
        }
        while index < units.count {
            try Task.checkCancellation()
            if case .string(let raw)? = modes.last { try scanString(raw: raw) } else { try scanCode() }
        }
        if case .string? = modes.last { append(from: segment, .string) }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func scanCode() throws {
        let start = index
        let unit = units[index]
        if SyntaxScanning.isASCIIHorizontalWhitespace(unit) || SyntaxScanning.isCRorLF(unit) {
            index += 1
            return
        }
        if case .template(let depth)? = modes.last, unit == 123 || unit == 125 {
            index += 1
            context = .other
            if unit == 123 {
                modes[modes.count - 1] = .template(depth: depth + 1)
            } else if depth > 0 {
                modes[modes.count - 1] = .template(depth: depth - 1)
            } else {
                modes.removeLast()
                append(from: start, .reference)
                segment = index
            }
            return
        }
        var kind: SyntaxToken.Kind?
        var next = Context.other
        if SyntaxScanning.hasPrefix([47, 47], in: units, at: index) {
            try consumeLine()
            kind = .comment
        } else if SyntaxScanning.hasPrefix([47, 42], in: units, at: index) {
            try consumeBlockComment()
            kind = .comment
        } else if unit == 34 {
            let raw = SyntaxScanning.hasPrefix([34, 34, 34], in: units, at: index)
            segment = index
            index += raw ? 3 : 1
            modes.append(.string(raw: raw))
        } else if unit == 39 {
            try consumeQuoted()
            kind = .string
        } else if unit == 96 {
            // Backticked names are never keywords, whatever they spell.
            index += 1
            try consumeQuoted(until: 96)
        } else if unit == 64 && nameWidth(at: index + 1, continuation: false) > 0 {
            try consumeAnnotation(label: wordEnd == start)
            kind = .reference
        } else if nameWidth(at: index, continuation: false) > 0 {
            try consumeName()
            wordEnd = index
            kind = classify(String(decoding: units[start..<index], as: UTF16.self), next: &next)
        } else if SyntaxScanning.isASCIIDigit(unit) || (unit == 46 && (start == 0 || units[start - 1] != 46) && wordEnd != start
                    && index + 1 < units.count && SyntaxScanning.isASCIIDigit(units[index + 1])) {
            try consumeNumber()
            let word = String(decoding: units[start..<index], as: UTF16.self)
            let range = NSRange(location: 0, length: word.utf16.count)
            if Self.number.rangeOfFirstMatch(in: word, range: range) == range { kind = .number }
        } else if SyntaxScanning.hasPrefix([46, 46], in: units, at: index) {
            index += 2
        } else if unit == 46 || SyntaxScanning.hasPrefix([63, 46], in: units, at: index) || SyntaxScanning.hasPrefix([58, 58], in: units, at: index) {
            index += unit == 46 ? 1 : 2
            next = .member
        } else {
            index += 1
        }
        if kind != .comment { context = next }
        if let kind { append(from: start, kind) }
    }

    private mutating func classify(_ word: String, next: inout Context) -> SyntaxToken.Kind? {
        if ["true", "false", "null"].contains(word) { return .literal }
        let hard = Self.hardKeywords.contains(word)
        guard hard || (context == .other && !memberFollows() && (Self.softKeywords.contains(word) || (word == "value" && classFollows()))) else {
            return nil
        }
        if Self.declaringKeywords.contains(word) { next = .declaration }
        if word == "as" && index < units.count && units[index] == 63 { index += 1 }
        return .keyword
    }

    private mutating func scanString(raw: Bool) throws {
        let unit = units[index]
        if raw ? SyntaxScanning.hasPrefix([34, 34, 34], in: units, at: index) : unit == 34 {
            // A raw string closes on the last quote of a run, so extra quotes stay in the text.
            index += 1
            while raw && index < units.count && units[index] == 34 {
                try Task.checkCancellation()
                index += 1
            }
            closeString()
        } else if !raw && SyntaxScanning.isCRorLF(unit) {
            closeString()
        } else if !raw && unit == 92 {
            index += 1
            if index < units.count && !SyntaxScanning.isCRorLF(units[index]) { index += 1 }
        } else if unit == 36 && index + 1 < units.count && units[index + 1] == 123 {
            append(from: segment, .string)
            tokens.append(SyntaxToken(range: NSRange(location: index, length: 2), kind: .reference))
            index += 2
            modes.append(.template(depth: 0))
            context = .other
        } else if unit == 36 && nameWidth(at: index + 1, continuation: false) > 0 {
            append(from: segment, .string)
            let start = index
            index += 1
            try consumeName()
            append(from: start, .reference)
            segment = index
        } else {
            index += 1
        }
    }

    private mutating func closeString() {
        append(from: segment, .string)
        modes.removeLast()
        context = .other
    }

    private mutating func consumeLine() throws {
        while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
            try Task.checkCancellation()
            index += 1
        }
    }

    private mutating func consumeBlockComment() throws {
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

    /// Character literals and backticked names stop at their closing mark or, as drafts, at the line end.
    private mutating func consumeQuoted(until closing: UInt16 = 39) throws {
        if closing == 39 { index += 1 }
        while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
            try Task.checkCancellation()
            if units[index] == closing {
                index += 1
                return
            }
            index += closing == 39 && units[index] == 92 && index + 1 < units.count && !SyntaxScanning.isCRorLF(units[index + 1]) ? 2 : 1
        }
    }

    /// Labels such as `return@forEach` take a single name; annotations may add a use-site target and a qualified path.
    private mutating func consumeAnnotation(label: Bool) throws {
        index += 1
        let nameStart = index
        try consumeName()
        guard !label else { return }
        if index < units.count && units[index] == 58 && nameWidth(at: index + 1, continuation: false) > 0
            && Self.useSiteTargets.contains(String(decoding: units[nameStart..<index], as: UTF16.self)) {
            index += 1
            try consumeName()
        }
        while index < units.count && units[index] == 46 && nameWidth(at: index + 1, continuation: false) > 0 {
            try Task.checkCancellation()
            index += 1
            try consumeName()
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

    /// Take the whole alphanumeric run so malformed literals such as `12abc` stay plain rather than splitting.
    private mutating func consumeNumber() throws {
        let hexadecimal = SyntaxScanning.hasPrefix([48, 120], in: units, at: index) || SyntaxScanning.hasPrefix([48, 88], in: units, at: index)
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            let width = nameWidth(at: index, continuation: true)
            if width > 0 {
                index += width
            } else if units[index] == 46 && index + 1 < units.count && SyntaxScanning.isASCIIDigit(units[index + 1]) {
                index += 1
            } else if !hexadecimal && [43, 45].contains(units[index]) && [69, 101].contains(units[index - 1]) {
                index += 1
            } else {
                return
            }
        }
    }

    private func memberFollows() -> Bool {
        (index < units.count && units[index] == 46 && !SyntaxScanning.hasPrefix([46, 46], in: units, at: index))
            || SyntaxScanning.hasPrefix([63, 46], in: units, at: index) || SyntaxScanning.hasPrefix([58, 58], in: units, at: index)
    }

    /// `value` is only a modifier in `value class`; elsewhere it is an ordinary, very common name.
    private func classFollows() -> Bool {
        var position = index
        while position < units.count && SyntaxScanning.isASCIIHorizontalWhitespace(units[position]) { position += 1 }
        return position > index && SyntaxScanning.hasPrefix(Self.classWord, in: units, at: position)
            && nameWidth(at: position + Self.classWord.count, continuation: true) == 0
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

    private mutating func append(from start: Int, _ kind: SyntaxToken.Kind) {
        guard index > start else { return }
        tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
    }

    private static let classWord = Array("class".utf16)
    private static let hardKeywords: Set<String> = [
        "as", "break", "class", "continue", "do", "else", "for", "fun", "if", "in", "interface", "is",
        "object", "package", "return", "super", "this", "throw", "try", "typealias", "typeof", "val",
        "var", "when", "while"
    ]
    private static let softKeywords: Set<String> = [
        "by", "catch", "constructor", "field", "finally", "get", "import", "init", "set", "where",
        "abstract", "actual", "annotation", "companion", "const", "crossinline", "data", "enum", "expect",
        "external", "final", "infix", "inline", "inner", "internal", "lateinit", "noinline", "open",
        "operator", "out", "override", "private", "protected", "public", "reified", "sealed", "suspend",
        "tailrec", "vararg"
    ]
    private static let declaringKeywords: Set<String> = [
        "class", "fun", "import", "interface", "object", "package", "typealias", "val", "var"
    ]
    private static let useSiteTargets: Set<String> = [
        "delegate", "field", "file", "get", "param", "property", "receiver", "set", "setparam"
    ]
    private static let number: NSRegularExpression = {
        let digits = #"[0-9](?:[0-9_]*[0-9])?"#
        let hex = #"0[xX][0-9a-fA-F](?:[0-9a-fA-F_]*[0-9a-fA-F])?"#
        let binary = #"0[bB][01](?:[01_]*[01])?"#
        let integer = #"(?:0|[1-9](?:[0-9_]*[0-9])?|\#(hex)|\#(binary))(?:[uU]L?|L)?"#
        let exponent = #"[eE][+-]?\#(digits)"#
        let real = #"(?:(?:\#(digits))?\.\#(digits)(?:\#(exponent))?|\#(digits)\#(exponent))[fF]?|\#(digits)[fF]"#
        return try! NSRegularExpression(pattern: #"^(?:\#(integer)|\#(real))$"#)
    }()
}
