import Foundation

enum RubyHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = RubyScanner(units: Array(text.utf16))
        try scanner.scanCode(depth: 0)
        try Task.checkCancellation()
        return scanner.tokens
    }
}

private struct RubyScanner {
    private struct Heredoc {
        let label: [UInt16]
        let indented: Bool
        let interpolates: Bool
    }

    let units: [UInt16]
    let origin: Int
    var index: Int
    var tokens: [SyntaxToken] = []
    private var heredocs: [Heredoc] = []
    private var steps = 0

    init(units: [UInt16]) {
        self.units = units
        origin = units.first == 0xfeff ? 1 : 0
        index = origin
    }

    /// Scan code to the end of text, or past the brace that closes an interpolation.
    mutating func scanCode(depth: Int) throws {
        // Ruby decides whether `/`, `%`, `?`, `:` and `<<` open literals from whether an operand may start here.
        var operand = true
        var afterName = false
        var member = false
        var ternaries = 0
        var braces = 0
        while index < units.count {
            try tick()
            let start = index
            let unit = units[index]
            if SyntaxScanning.isCRorLF(unit) {
                consumeNewline()
                if !heredocs.isEmpty { try consumeHeredocBodies(depth: depth) }
                if !operand { ternaries = 0 }
                operand = true
                afterName = false
                member = false
                continue
            }
            if SyntaxScanning.isASCIIHorizontalWhitespace(unit) {
                index += 1
                continue
            }
            if unit == 92 && index + 1 < units.count && SyntaxScanning.isCRorLF(units[index + 1]) {
                index += 1
                consumeNewline()
                continue
            }
            let spaced = index > origin && SyntaxScanning.isASCIIHorizontalWhitespace(units[index - 1])
            var kind: SyntaxToken.Kind?
            var expectsOperand = false
            var bareName = false
            var memberNext = false
            if unit == 35 {
                try consumeLine()
                kind = .comment
                expectsOperand = operand
            } else if unit == 61 && isLineStart(index) && isDirective(Self.documentStart, at: index) {
                try consumeEmbeddedDocument()
                kind = .comment
                expectsOperand = true
            } else if unit == 34 || unit == 39 || unit == 96 {
                index += 1
                try consumeDelimited(from: start, open: unit, close: unit, interpolates: unit != 39, kind: .string, depth: depth)
            } else if SyntaxScanning.hasPrefix([58, 58], in: units, at: index) {
                index += 2
                memberNext = true
            } else if unit == 58 && (operand || ternaries == 0), let end = symbolEnd(at: index + 1) {
                index = end
                kind = .literal
            } else if unit == 58 && (operand || ternaries == 0) && index + 1 < units.count && [34, 39].contains(units[index + 1]) {
                let quote = units[index + 1]
                index += 2
                try consumeDelimited(from: start, open: quote, close: quote, interpolates: quote == 34, kind: .literal, depth: depth)
            } else if unit == 58 {
                index += 1
                if ternaries > 0 { ternaries -= 1 }
                expectsOperand = true
            } else if unit == 63 {
                if operand, let end = characterLiteralEnd() {
                    index = end
                    kind = .string
                } else {
                    index += 1
                    ternaries += 1
                    expectsOperand = true
                }
            } else if (unit == 64 || unit == 36), let end = variableEnd(at: index) {
                index = end
                kind = .reference
            } else if unit == 37, operand || (afterName && spaced && attachesToNextUnit()), let opening = percentOpening(ambiguous: !operand) {
                index = opening.delimiter + 1
                let delimiter = units[opening.delimiter]
                try consumeDelimited(
                    from: start, open: delimiter, close: Self.closingDelimiter(for: delimiter),
                    interpolates: !Self.plainPercentTypes.contains(opening.type),
                    kind: Self.symbolPercentTypes.contains(opening.type) ? .literal : .string,
                    flags: opening.type == 114, depth: depth)
            } else if unit == 47, operand || (afterName && spaced && attachesToNextUnit() && regexClosesOnLine()) {
                index += 1
                try consumeDelimited(from: start, open: 47, close: 47, interpolates: true, kind: .string, flags: true, depth: depth)
            } else if SyntaxScanning.hasPrefix([60, 60], in: units, at: index), let opening = heredocOpening(), operand || (afterName && spaced && opening.explicit) {
                index = opening.end
                heredocs.append(opening.heredoc)
                kind = .string
            } else if isNameStart(unit) {
                try consumeName()
                if index < units.count && [33, 63].contains(units[index]) && !(index + 1 < units.count && units[index + 1] == 61) { index += 1 }
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if ternaries == 0 && index < units.count && units[index] == 58 && !SyntaxScanning.hasPrefix([58, 58], in: units, at: index) {
                    index += 1
                    kind = .key
                    expectsOperand = true
                } else if member && word != "self" {
                    bareName = true
                } else if Self.literals.contains(word) {
                    kind = .literal
                } else if Self.keywords.contains(word) {
                    kind = .keyword
                    expectsOperand = !Self.valueKeywords.contains(word) && word != "def"
                    bareName = word == "super" || word == "yield"
                    memberNext = word == "def"
                } else {
                    bareName = true
                }
            } else if SyntaxScanning.isASCIIDigit(unit) {
                if try consumeNumber() { kind = .number }
            } else if unit == 46 || SyntaxScanning.hasPrefix([38, 46], in: units, at: index) {
                index += unit == 46 ? 1 : 2
                if unit == 46 && index < units.count && units[index] == 46 {
                    while index < units.count && units[index] == 46 { index += 1 }
                    expectsOperand = true
                } else {
                    memberNext = true
                }
            } else if unit == 123 {
                index += 1
                braces += 1
                expectsOperand = true
            } else if unit == 125 {
                index += 1
                if depth > 0 && braces == 0 { return }
                braces = max(0, braces - 1)
            } else {
                index += 1
                expectsOperand = unit != 41 && unit != 93
                if unit == 59 { ternaries = 0 }
            }
            if let kind { append(kind, from: start, to: index) }
            operand = expectsOperand
            afterName = bareName
            member = memberNext
        }
    }

    // MARK: Delimited literals

    /// Consume a literal body after its opening delimiter, splitting interpolations out as references.
    private mutating func consumeDelimited(from start: Int, open: UInt16, close: UInt16, interpolates: Bool,
                                           kind: SyntaxToken.Kind, flags: Bool = false, depth: Int) throws {
        var segment = start
        var nesting = 0
        while index < units.count {
            try tick()
            let unit = units[index]
            if unit == 92 {
                index = min(index + 2, units.count)
            } else if unit == close && nesting == 0 {
                index += 1
                if flags {
                    while index < units.count && Self.regexFlags.contains(units[index]) { index += 1 }
                }
                break
            } else if unit == close {
                nesting -= 1
                index += 1
            } else if unit == open && open != close {
                nesting += 1
                index += 1
            } else if interpolates && unit == 35 && interpolationStarts(at: index) {
                append(kind, from: segment, to: index)
                try consumeInterpolation(depth: depth)
                segment = index
            } else {
                index += 1
            }
        }
        append(kind, from: segment, to: index)
    }

    private func interpolationStarts(at position: Int) -> Bool {
        guard position + 2 < units.count || (position + 1 < units.count && units[position + 1] == 123) else { return false }
        switch units[position + 1] {
        case 123: return true
        case 64: return variableEnd(at: position + 1) != nil
        // Short-form globals exclude punctuation names such as `$"`, which would swallow the closing quote.
        case 36: return isNameStart(units[position + 2]) || SyntaxScanning.isASCIIDigit(units[position + 2])
        default: return false
        }
    }

    /// The whole interpolation, braces included, takes one reference colour; nested code is scanned only to find its end.
    private mutating func consumeInterpolation(depth: Int) throws {
        let start = index
        if units[index + 1] == 123 {
            if depth < 32 {
                index += 2
                let mark = tokens.count
                let outer = heredocs
                heredocs = []
                try scanCode(depth: depth + 1)
                tokens.removeSubrange(mark...)
                heredocs = outer
            } else {
                index = units.count
            }
        } else {
            index = variableEnd(at: index + 1) ?? index + 1
        }
        append(.reference, from: start, to: index)
    }

    private func percentOpening(ambiguous: Bool) -> (type: UInt16, delimiter: Int)? {
        var position = index + 1
        // Untyped literals behave like `%Q`.
        var type: UInt16 = 81
        if position < units.count && Self.percentTypes.contains(units[position]) {
            type = units[position]
            position += 1
        } else if ambiguous {
            // After a bare name, only bracketed untyped literals are clear enough to read as strings.
            guard position < units.count && [40, 60, 91, 123].contains(units[position]) else { return nil }
        }
        guard position < units.count else { return nil }
        let delimiter = units[position]
        guard delimiter > 32 && delimiter < 127 && !isNameUnit(delimiter) else { return nil }
        return (type, position)
    }

    private func regexClosesOnLine() -> Bool {
        var position = index + 1
        while position < units.count && !SyntaxScanning.isCRorLF(units[position]) {
            if units[position] == 92 { position += 2; continue }
            if units[position] == 47 { return true }
            position += 1
        }
        return false
    }

    private func attachesToNextUnit() -> Bool {
        guard index + 1 < units.count else { return false }
        let next = units[index + 1]
        return next != 61 && !SyntaxScanning.isASCIIHorizontalWhitespace(next) && !SyntaxScanning.isCRorLF(next)
    }

    private static func closingDelimiter(for unit: UInt16) -> UInt16 {
        switch unit {
        case 40: 41
        case 60: 62
        case 91: 93
        case 123: 125
        default: unit
        }
    }

    // MARK: Heredocs

    /// `explicit` marks forms that stay heredocs after a bare name: `~`, `-`, quoted or capitalised labels.
    private func heredocOpening() -> (heredoc: Heredoc, end: Int, explicit: Bool)? {
        var position = index + 2
        var indented = false
        if position < units.count && [45, 126].contains(units[position]) {
            indented = true
            position += 1
        }
        guard position < units.count else { return nil }
        let quote = units[position]
        if [34, 39, 96].contains(quote) {
            var close = position + 1
            while close < units.count && units[close] != quote && !SyntaxScanning.isCRorLF(units[close]) { close += 1 }
            guard close < units.count && units[close] == quote && close > position + 1 else { return nil }
            let heredoc = Heredoc(label: Array(units[(position + 1)..<close]), indented: indented, interpolates: quote != 39)
            return (heredoc, close + 1, true)
        }
        guard isNameStart(quote) else { return nil }
        var end = position + 1
        while end < units.count && isNameUnit(units[end]) { end += 1 }
        let heredoc = Heredoc(label: Array(units[position..<end]), indented: indented, interpolates: true)
        return (heredoc, end, indented || (65...90).contains(quote))
    }

    /// Bodies follow the introducing line in order; each ends at a line holding only its label.
    private mutating func consumeHeredocBodies(depth: Int) throws {
        let pending = heredocs
        heredocs = []
        for (offset, heredoc) in pending.enumerated() {
            if offset > 0 { consumeNewline() }
            try consumeHeredocBody(heredoc, depth: depth)
        }
    }

    private mutating func consumeHeredocBody(_ heredoc: Heredoc, depth: Int) throws {
        var segment = index
        while index < units.count {
            try tick()
            if isLineStart(index), let end = terminatorEnd(heredoc, at: index) {
                index = end
                append(.string, from: segment, to: index)
                while index < units.count && SyntaxScanning.isASCIIHorizontalWhitespace(units[index]) { index += 1 }
                return
            }
            let unit = units[index]
            if heredoc.interpolates && unit == 92 && index + 1 < units.count && !SyntaxScanning.isCRorLF(units[index + 1]) {
                index += 2
            } else if heredoc.interpolates && unit == 35 && interpolationStarts(at: index) {
                append(.string, from: segment, to: index)
                try consumeInterpolation(depth: depth)
                segment = index
            } else {
                index += 1
            }
        }
        append(.string, from: segment, to: index)
    }

    private func terminatorEnd(_ heredoc: Heredoc, at position: Int) -> Int? {
        var start = position
        if heredoc.indented {
            while start < units.count && SyntaxScanning.isASCIIHorizontalWhitespace(units[start]) { start += 1 }
        }
        guard SyntaxScanning.hasPrefix(heredoc.label, in: units, at: start) else { return nil }
        let end = start + heredoc.label.count
        var rest = end
        while rest < units.count && SyntaxScanning.isASCIIHorizontalWhitespace(units[rest]) { rest += 1 }
        return rest == units.count || SyntaxScanning.isCRorLF(units[rest]) ? end : nil
    }

    // MARK: Names, symbols and numbers

    private func symbolEnd(at position: Int) -> Int? {
        guard position < units.count else { return nil }
        let unit = units[position]
        if unit == 64 || unit == 36 { return variableEnd(at: position) }
        if isNameStart(unit) {
            var end = position + 1
            while end < units.count && isNameUnit(units[end]) { end += 1 }
            if end < units.count && [33, 63].contains(units[end]) {
                end += 1
            } else if end < units.count && units[end] == 61 && !(end + 1 < units.count && [61, 62, 126].contains(units[end + 1])) {
                end += 1
            }
            return end
        }
        return Self.operatorSymbols.first { SyntaxScanning.hasPrefix($0, in: units, at: position) }.map { position + $0.count }
    }

    /// Instance, class and global variables, including punctuation and numbered globals.
    private func variableEnd(at position: Int) -> Int? {
        var end = position + 1
        if units[position] == 64 {
            if end < units.count && units[end] == 64 { end += 1 }
            guard end < units.count && isNameStart(units[end]) else { return nil }
        } else {
            guard end < units.count else { return nil }
            let unit = units[end]
            if SyntaxScanning.isASCIIDigit(unit) {
                while end < units.count && SyntaxScanning.isASCIIDigit(units[end]) { end += 1 }
                return end
            }
            if unit == 45 {
                guard end + 1 < units.count && isNameUnit(units[end + 1]) && units[end + 1] < 128 else { return nil }
                return end + 2
            }
            if Self.specialGlobals.contains(unit) { return end + 1 }
            guard isNameStart(unit) else { return nil }
        }
        while end < units.count && isNameUnit(units[end]) { end += 1 }
        return end
    }

    private func characterLiteralEnd() -> Int? {
        let position = index + 1
        guard position < units.count else { return nil }
        let unit = units[position]
        guard !SyntaxScanning.isASCIIHorizontalWhitespace(unit) && !SyntaxScanning.isCRorLF(unit) else { return nil }
        let end = unit == 92 ? min(position + 2, units.count) : position + SyntaxScanning.scalar(in: units, at: position).width
        return end == units.count || !isNameUnit(units[end]) ? end : nil
    }

    private mutating func consumeName() throws {
        while index < units.count && isNameUnit(units[index]) {
            try tick()
            index += 1
        }
    }

    /// Consume the whole alphanumeric run so malformed numbers stay plain rather than partly coloured.
    private mutating func consumeNumber() throws -> Bool {
        let start = index
        let hex = SyntaxScanning.hasPrefix([48, 120], in: units, at: index) || SyntaxScanning.hasPrefix([48, 88], in: units, at: index)
        var fraction = false
        index += 1
        while index < units.count {
            try tick()
            let unit = units[index]
            let nextIsDigit = index + 1 < units.count && SyntaxScanning.isASCIIDigit(units[index + 1])
            if isNameUnit(unit) {
                index += 1
            } else if unit == 46 && nextIsDigit && !fraction && !hex {
                fraction = true
                index += 1
            } else if [43, 45].contains(unit) && [69, 101].contains(units[index - 1]) && nextIsDigit && !hex {
                index += 1
            } else {
                break
            }
        }
        let word = String(decoding: units[start..<index], as: UTF16.self)
        let range = NSRange(location: 0, length: word.utf16.count)
        return Self.number.rangeOfFirstMatch(in: word, range: range) == range
    }

    // MARK: Lines and comments

    private mutating func consumeEmbeddedDocument() throws {
        index += Self.documentStart.count
        while index < units.count {
            try tick()
            if isLineStart(index) && isDirective(Self.documentEnd, at: index) {
                try consumeLine()
                return
            }
            index += 1
        }
    }

    private func isDirective(_ word: [UInt16], at position: Int) -> Bool {
        guard SyntaxScanning.hasPrefix(word, in: units, at: position) else { return false }
        let end = position + word.count
        return end == units.count || SyntaxScanning.isASCIIHorizontalWhitespace(units[end]) || SyntaxScanning.isCRorLF(units[end])
    }

    private mutating func consumeLine() throws {
        while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
            try tick()
            index += 1
        }
    }

    private mutating func consumeNewline() {
        if SyntaxScanning.hasPrefix([13, 10], in: units, at: index) { index += 2 }
        else if index < units.count && SyntaxScanning.isCRorLF(units[index]) { index += 1 }
    }

    private func isLineStart(_ position: Int) -> Bool {
        guard position > origin else { return true }
        let previous = units[position - 1]
        return previous == 10 || (previous == 13 && (position == units.count || units[position] != 10))
    }

    private mutating func tick() throws {
        steps &+= 1
        if steps & 1023 == 0 { try Task.checkCancellation() }
    }

    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int, to end: Int) {
        guard end > start else { return }
        tokens.append(SyntaxToken(range: NSRange(location: start, length: end - start), kind: kind))
    }

    private func isNameStart(_ unit: UInt16) -> Bool {
        (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || unit >= 128
    }
    private func isNameUnit(_ unit: UInt16) -> Bool { isNameStart(unit) || SyntaxScanning.isASCIIDigit(unit) }

    private static let keywords: Set<String> = [
        "BEGIN", "END", "__ENCODING__", "__FILE__", "__LINE__", "__method__", "alias", "and", "begin", "break", "case",
        "class", "def", "defined?", "do", "else", "elsif", "end", "ensure", "for", "if", "in", "module", "next", "not",
        "or", "redo", "rescue", "retry", "return", "super", "then", "undef", "unless", "until", "when", "while", "yield"
    ]
    /// Keywords that complete an operand, so a following `/` or `%` is an operator.
    private static let valueKeywords: Set<String> = ["__ENCODING__", "__FILE__", "__LINE__", "__method__", "end", "redo", "retry", "super", "yield"]
    private static let literals: Set<String> = ["nil", "true", "false", "self"]
    private static let documentStart = Array("=begin".utf16)
    private static let documentEnd = Array("=end".utf16)
    private static let percentTypes = Set("qQwWiIrsx".utf16)
    private static let plainPercentTypes = Set("qwis".utf16)
    private static let symbolPercentTypes = Set("iIs".utf16)
    private static let regexFlags = Set("imxounse".utf16)
    private static let specialGlobals = Set("!@&`'+~=/\\,;.<>*$?:\"".utf16)
    // Longest operator names first so `:[]=` and `:<=>` are not cut short.
    private static let operatorSymbols = ["[]=", "[]", "<=>", "===", "==", "=~", "!=", "!~", "**", "+@", "-@", "<<", ">>", "<=", ">=",
                                          "<", ">", "+", "-", "*", "/", "%", "~", "&", "|", "^", "!"].map { Array($0.utf16) }
    private static let number = try! NSRegularExpression(pattern: #"^(?:0[xX][0-9a-fA-F]+(?:_[0-9a-fA-F]+)*|0[bB][01]+(?:_[01]+)*|0[oO_]?[0-7]+(?:_[0-7]+)*|0[dD][0-9]+(?:_[0-9]+)*|[0-9]+(?:_[0-9]+)*(?:\.[0-9]+(?:_[0-9]+)*)?(?:[eE][+-]?[0-9]+(?:_[0-9]+)*)?)(?:ri|r|i)?$"#)
}
