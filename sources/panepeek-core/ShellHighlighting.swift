import Foundation

enum ShellHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = ShellScanner(text: text)
        return try scanner.scan()
    }
}

private struct ShellScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []
    var heredocs: [(label: [UInt16], tabs: Bool)] = []

    init(text: String) { units = Array(text.utf16) }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            if isNewline(units[index]) {
                consumeNewline()
                try consumeHeredocs()
            } else if isSpace(units[index]) {
                index += 1
            } else if units[index] == 35 {
                while index < units.count && !isNewline(units[index]) {
                    try Task.checkCancellation()
                    index += 1
                }
                append(.comment, from: start)
            } else if has([60, 60], at: index) && !has([60, 60, 60], at: index) {
                try consumeHeredocLabel()
            } else if has([60, 60, 60], at: index) {
                index += 3
            } else if isOperator(units[index]) {
                index += 1
            } else {
                try consumeWord()
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func consumeWord() throws {
        let start = index
        var plain = true
        while index < units.count && !isBoundary(units[index]) {
            try Task.checkCancellation()
            let part = index
            if let quote = quoteStart(at: index) {
                index = try quotedEnd(at: quote.position, ansi: quote.ansi, depth: 0)
                append(.string, from: part)
                plain = false
            } else if units[index] == 36, let end = try parameterEnd(at: index, depth: 0) {
                index = end
                append(.reference, from: part)
                plain = false
            } else if units[index] == 92 {
                index = min(index + 2, units.count)
                plain = false
            } else {
                index += 1
            }
        }
        if plain && Self.keywords.contains(String(decoding: units[start..<index], as: UTF16.self)) {
            append(.keyword, from: start)
        }
    }

    private func quoteStart(at position: Int) -> (position: Int, ansi: Bool)? {
        let unit = units[position]
        if [34, 39, 96].contains(unit) { return (position, false) }
        if unit == 36 && position + 1 < units.count && [34, 39].contains(units[position + 1]) {
            return (position + 1, units[position + 1] == 39)
        }
        return nil
    }

    private func quotedEnd(at start: Int, ansi: Bool, depth: Int) throws -> Int {
        guard depth < 32 else { return units.count }
        let quote = units[start]
        var end = start + 1
        while end < units.count {
            try Task.checkCancellation()
            if units[end] == quote { return end + 1 }
            if units[end] == 92 && (quote != 39 || ansi) {
                end = min(end + 2, units.count)
            } else if quote == 34 && units[end] == 36, let nested = try parameterEnd(at: end, depth: depth + 1) {
                end = nested
            } else if quote == 34 && units[end] == 96 {
                end = try quotedEnd(at: end, ansi: false, depth: depth + 1)
            } else {
                end += 1
            }
        }
        return end
    }

    private func parameterEnd(at start: Int, depth: Int) throws -> Int? {
        guard start + 1 < units.count else { return nil }
        let next = units[start + 1]
        if next == 123 || next == 40 {
            guard depth < 32 else { return units.count }
            let closing: UInt16 = next == 123 ? 125 : 41
            let command = next == 40 && !has([36, 40, 40], at: start)
            var nesting = 1
            var end = start + 2
            while end < units.count {
                try Task.checkCancellation()
                if command && units[end] == 35 && (end == start + 2 || isBoundary(units[end - 1])) {
                    while end < units.count && !isNewline(units[end]) {
                        try Task.checkCancellation()
                        end += 1
                    }
                } else if let quote = quoteStart(at: end) {
                    end = try quotedEnd(at: quote.position, ansi: quote.ansi, depth: depth + 1)
                } else if units[end] == 36, let nested = try parameterEnd(at: end, depth: depth + 1) {
                    end = nested
                } else if units[end] == 92 {
                    end = min(end + 2, units.count)
                } else {
                    if units[end] == next { nesting += 1 }
                    if units[end] == closing { nesting -= 1 }
                    end += 1
                    if nesting == 0 { return end }
                }
            }
            return end
        }
        if (48...57).contains(next) || [33, 35, 36, 42, 45, 63, 64].contains(next) { return start + 2 }
        guard isName(next) else { return nil }
        var end = start + 2
        while end < units.count && (isName(units[end]) || (48...57).contains(units[end])) {
            try Task.checkCancellation()
            end += 1
        }
        return end
    }

    private mutating func consumeHeredocLabel() throws {
        index += 2
        let tabs = index < units.count && units[index] == 45
        if tabs { index += 1 }
        while index < units.count && isSpace(units[index]) { index += 1 }
        let start = index
        var label: [UInt16] = []
        while index < units.count && !isBoundary(units[index]) {
            try Task.checkCancellation()
            if units[index] == 34 || units[index] == 39 {
                let quote = units[index]
                index += 1
                while index < units.count && units[index] != quote {
                    try Task.checkCancellation()
                    if quote == 34 && units[index] == 92 && index + 1 < units.count && [34, 36, 92, 96].contains(units[index + 1]) { index += 1 }
                    label.append(units[index])
                    index += 1
                }
                if index < units.count { index += 1 }
            } else {
                if units[index] == 92 && index + 1 < units.count { index += 1 }
                label.append(units[index])
                index += 1
            }
        }
        if start < index { append(.string, from: start) }
        if start < index { heredocs.append((label, tabs)) }
    }

    private mutating func consumeHeredocs() throws {
        for document in heredocs {
            let start = index
            var end = index
            while index < units.count {
                try Task.checkCancellation()
                var content = index
                while index < units.count && !isNewline(units[index]) {
                    try Task.checkCancellation()
                    index += 1
                }
                end = index
                if document.tabs { while content < end && units[content] == 9 { content += 1 } }
                let closes = units[content..<end].elementsEqual(document.label)
                if index < units.count { consumeNewline() }
                if closes { break }
            }
            if end > start { tokens.append(SyntaxToken(range: NSRange(location: start, length: end - start), kind: .string)) }
        }
        heredocs.removeAll(keepingCapacity: true)
    }

    private mutating func consumeNewline() {
        let unit = units[index]
        index += 1
        if unit == 13 && index < units.count && units[index] == 10 { index += 1 }
    }

    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int) {
        tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
    }
    private func has(_ prefix: [UInt16], at position: Int) -> Bool {
        position + prefix.count <= units.count && units[position..<(position + prefix.count)].elementsEqual(prefix)
    }
    private func isBoundary(_ unit: UInt16) -> Bool { isSpace(unit) || isNewline(unit) || isOperator(unit) }
    private func isSpace(_ unit: UInt16) -> Bool { unit == 32 || unit == 9 }
    private func isNewline(_ unit: UInt16) -> Bool { unit == 10 || unit == 13 }
    private func isOperator(_ unit: UInt16) -> Bool { [38, 40, 41, 59, 60, 62, 124].contains(unit) }
    private func isName(_ unit: UInt16) -> Bool { (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 }
    private static let keywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "in",
        "function", "select", "time", "coproc", "repeat", "foreach", "end", "nocorrect", "!", "[[", "]]"
    ]
}
