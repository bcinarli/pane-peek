import Foundation

enum ConfigurationHighlighting {
    static func tokens(in text: String, yaml: Bool, jsonComments: Bool = false) throws -> [SyntaxToken] {
        var scanner = ConfigurationScanner(text: text, yaml: yaml, jsonComments: jsonComments)
        return try scanner.scan()
    }
}

private struct ConfigurationScanner {
    let units: [UInt16]
    let yaml: Bool
    let jsonComments: Bool
    var index = 0
    var lineStart = 0
    var expectsKey = true
    var arrayDepth = 0
    var block: (parent: Int, content: Int?)?
    var tokens: [SyntaxToken] = []

    init(text: String, yaml: Bool, jsonComments: Bool) {
        units = Array(text.utf16)
        self.yaml = yaml
        self.jsonComments = jsonComments
    }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            if yaml && consumeBlockLine() { continue }
            let start = index
            let unit = units[index]
            if SyntaxScanning.isSpaceOrTab(unit) || SyntaxScanning.isCRorLF(unit) {
                advance(to: index + 1)
            } else if isComment(at: index) {
                let end = commentEnd(at: start)
                append(.comment, from: start, to: end)
                advance(to: end)
            } else if !yaml && unit == 91 && arrayDepth == 0 && isLinePrefix(at: index) {
                let end = headerEnd(at: index)
                append(.section, from: start, to: end)
                advance(to: end)
                expectsKey = false
            } else if yaml && isLinePrefix(at: index) && isDocumentMarker(at: index) {
                append(.section, from: start, to: start + 3)
                advance(to: start + 3)
                expectsKey = false
            } else if yaml && unit == 45 && index + 1 < units.count && SyntaxScanning.isSpaceOrTab(units[index + 1]) {
                advance(to: index + 1)
                expectsKey = true
            } else if expectsKey, let boundary = keyEnd(at: index) {
                var end = boundary
                while end > start && SyntaxScanning.isSpaceOrTab(units[end - 1]) { end -= 1 }
                append(.key, from: start, to: end)
                // Leave comments before the separator for the normal comment scanner.
                advance(to: isComment(at: boundary) ? boundary : boundary + 1)
                expectsKey = false
            } else {
                expectsKey = false
                if unit == 34 || unit == 39 {
                    let end = quotedEnd(at: index)
                    append(.string, from: start, to: end)
                    advance(to: end)
                    expectsKey = false
                } else if yaml && (unit == 38 || unit == 42) {
                    let end = bareEnd(at: index)
                    append(.reference, from: start, to: end)
                    advance(to: end)
                } else if yaml, let end = blockHeaderEnd(at: index) {
                    let digit = units[start..<end].first { (49...57).contains($0) }
                    let indent = indentation(at: lineStart)
                    block = (indent, digit.map { indent + Int($0 - 48) })
                    append(.string, from: start, to: end)
                    advance(to: end)
                } else if [91, 93, 123, 125, 44, 58, 61].contains(unit) {
                    if !yaml && unit == 91 { arrayDepth += 1 }
                    if !yaml && unit == 93 { arrayDepth = max(0, arrayDepth - 1) }
                    advance(to: index + 1)
                    expectsKey = unit == 123 || unit == 44
                } else {
                    let end = yaml ? plainEnd(at: index) : bareEnd(at: index)
                    let word = String(decoding: units[start..<end], as: UTF16.self)
                    let literals = yaml ? Self.yamlLiterals : ["true", "false"]
                    if literals.contains(word) || (!yaml && Self.matches(Self.tomlDate, word)) {
                        append(.literal, from: start, to: end)
                    } else if Self.matches(yaml ? Self.yamlNumber : Self.tomlNumber, word) {
                        append(.number, from: start, to: end)
                    } else if yaml {
                        append(.string, from: start, to: end)
                    }
                    advance(to: end)
                }
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int, to end: Int) {
        guard end > start else { return }
        tokens.append(SyntaxToken(range: NSRange(location: start, length: end - start), kind: kind))
    }

    private mutating func advance(to end: Int) {
        for position in index..<end where SyntaxScanning.isCRorLF(units[position]) {
            lineStart = position + 1
            expectsKey = true
        }
        index = end
    }

    private mutating func consumeBlockLine() -> Bool {
        guard let block, index == lineStart else { return false }
        let end = lineEnd(at: index)
        let blank = units[index..<end].allSatisfy(SyntaxScanning.isSpaceOrTab)
        let indent = indentation(at: index)
        if !blank && (indent <= block.parent || indent < (block.content ?? indent)) {
            self.block = nil
            return false
        }
        if !blank && block.content == nil { self.block?.content = indent }
        append(.string, from: index, to: end)
        var after = end
        while after < units.count && SyntaxScanning.isCRorLF(units[after]) { after += 1 }
        advance(to: after)
        return true
    }

    private func keyEnd(at start: Int) -> Int? {
        var end = start
        while end < units.count && !SyntaxScanning.isCRorLF(units[end]) {
            if isComment(at: end) {
                guard jsonComments && units[end] == 47,
                      let delimiter = delimiterAfterComments(at: end), acceptsKeyDelimiter(at: delimiter, start: start) else { return nil }
                return end > start ? end : nil
            }
            if [91, 93, 123, 125, 44].contains(units[end]) { return nil }
            if units[end] == 34 || units[end] == 39 {
                end = quotedEnd(at: end)
            } else if units[end] == (yaml ? 58 : 61) {
                if acceptsKeyDelimiter(at: end, start: start) {
                    return end > start ? end : nil
                }
                end += 1
            } else {
                end += 1
            }
        }
        return nil
    }

    private func delimiterAfterComments(at start: Int) -> Int? {
        var end = start
        while end < units.count {
            if SyntaxScanning.isSpaceOrTab(units[end]) || SyntaxScanning.isCRorLF(units[end]) { end += 1 }
            else if units[end] == 47 && isComment(at: end) { end = commentEnd(at: end) }
            else { return units[end] == 58 ? end : nil }
        }
        return nil
    }

    private func acceptsKeyDelimiter(at position: Int, start: Int) -> Bool {
        let quoted = units[start] == 34 || units[start] == 39
        return !yaml || quoted || position + 1 == units.count || SyntaxScanning.isSpaceOrTab(units[position + 1]) ||
            SyntaxScanning.isCRorLF(units[position + 1]) || [93, 125, 44].contains(units[position + 1]) ||
            (jsonComments && isComment(at: position + 1))
    }

    private func quotedEnd(at start: Int) -> Int {
        let quote = units[start]
        let count = !yaml && SyntaxScanning.hasPrefix([quote, quote, quote], in: units, at: start) ? 3 : 1
        let closing = Array(repeating: quote, count: count)
        var end = start + count
        while end < units.count {
            if yaml && quote == 39 && SyntaxScanning.hasPrefix([39, 39], in: units, at: end) {
                end += 2
            } else if SyntaxScanning.hasPrefix(closing, in: units, at: end) {
                end += count
                if count == 3 {
                    // TOML permits one or two content quotes next to the closing delimiter.
                    for _ in 0..<2 where end < units.count && units[end] == quote { end += 1 }
                }
                return end
            } else if quote == 34 && units[end] == 92 {
                end = min(end + 2, units.count)
            } else if !yaml && count == 1 && SyntaxScanning.isCRorLF(units[end]) {
                return end
            } else {
                end += 1
            }
        }
        return end
    }

    private func headerEnd(at start: Int) -> Int {
        var end = start + 1
        let doubled = end < units.count && units[end] == 91
        if doubled { end += 1 }
        while end < units.count && !SyntaxScanning.isCRorLF(units[end]) && !isComment(at: end) {
            if units[end] == 34 || units[end] == 39 {
                end = quotedEnd(at: end)
            } else if units[end] == 93 {
                end += 1
                if doubled && end < units.count && units[end] == 93 { end += 1 }
                return end
            } else {
                end += 1
            }
        }
        return end
    }

    private func bareEnd(at start: Int) -> Int {
        var end = start
        while end < units.count && !SyntaxScanning.isSpaceOrTab(units[end]) && !SyntaxScanning.isCRorLF(units[end]) && ![91, 93, 123, 125, 44].contains(units[end]) && !isComment(at: end) {
            if !yaml && units[end] == 61 { break }
            end += 1
        }
        return max(start + 1, end)
    }

    private func plainEnd(at start: Int) -> Int {
        var end = start
        while end < units.count && !SyntaxScanning.isCRorLF(units[end]) && ![91, 93, 123, 125, 44].contains(units[end]) && !isComment(at: end) { end += 1 }
        while end > start && SyntaxScanning.isSpaceOrTab(units[end - 1]) { end -= 1 }
        return max(start + 1, end)
    }

    private func blockHeaderEnd(at start: Int) -> Int? {
        guard units[start] == 124 || units[start] == 62 else { return nil }
        var end = start + 1
        while end < units.count && ([43, 45].contains(units[end]) || (49...57).contains(units[end])) { end += 1 }
        guard end == units.count || SyntaxScanning.isSpaceOrTab(units[end]) || SyntaxScanning.isCRorLF(units[end]) || isComment(at: end) else { return nil }
        return end
    }

    private func lineEnd(at start: Int) -> Int {
        var end = start
        while end < units.count && !SyntaxScanning.isCRorLF(units[end]) { end += 1 }
        return end
    }

    private func indentation(at start: Int) -> Int {
        var end = start
        while end < units.count && units[end] == 32 { end += 1 }
        return end - start
    }

    private func isLinePrefix(at position: Int) -> Bool { units[lineStart..<position].allSatisfy(SyntaxScanning.isSpaceOrTab) }
    private func isDocumentMarker(at position: Int) -> Bool {
        (SyntaxScanning.hasPrefix([45, 45, 45], in: units, at: position) || SyntaxScanning.hasPrefix([46, 46, 46], in: units, at: position)) &&
        (position + 3 == units.count || SyntaxScanning.isSpaceOrTab(units[position + 3]) || SyntaxScanning.isCRorLF(units[position + 3]))
    }
    private func isComment(at position: Int) -> Bool {
        (units[position] == 35 && (!yaml || position == lineStart || SyntaxScanning.isSpaceOrTab(units[position - 1]))) ||
        (jsonComments && (SyntaxScanning.hasPrefix([47, 47], in: units, at: position) || SyntaxScanning.hasPrefix([47, 42], in: units, at: position)))
    }

    private func commentEnd(at start: Int) -> Int {
        guard jsonComments && SyntaxScanning.hasPrefix([47, 42], in: units, at: start) else { return lineEnd(at: start) }
        var end = start + 2
        while end < units.count {
            if SyntaxScanning.hasPrefix([42, 47], in: units, at: end) { return end + 2 }
            end += 1
        }
        return end
    }

    private static func matches(_ expression: NSRegularExpression, _ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        return expression.rangeOfFirstMatch(in: word, range: range) == range
    }

    private static let yamlLiterals: Set<String> = ["true", "True", "TRUE", "false", "False", "FALSE", "null", "Null", "NULL", "~"]
    private static let yamlNumber = try! NSRegularExpression(pattern: #"^(?:[+-]?(?:[0-9]+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?|\.[0-9]+(?:[eE][+-]?[0-9]+)?|\.(?:inf|Inf|INF|nan|NaN|NAN))|0x[0-9a-fA-F]+|0o[0-7]+)$"#)
    private static let tomlNumber = try! NSRegularExpression(pattern: #"^(?:0x[0-9a-fA-F]+(?:_[0-9a-fA-F]+)*|0o[0-7]+(?:_[0-7]+)*|0b[01]+(?:_[01]+)*|[+-]?(?:(?:0|[1-9][0-9]*(?:_[0-9]+)*)(?:\.[0-9]+(?:_[0-9]+)*)?(?:[eE][+-]?[0-9]+(?:_[0-9]+)*)?|inf|nan))$"#)
    private static let tomlDate = try! NSRegularExpression(pattern: #"^(?:[0-9]{4}-[0-9]{2}-[0-9]{2}(?:[Tt][0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:[Zz]|[+-][0-9]{2}:[0-9]{2})?)?|[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?)$"#)
}
