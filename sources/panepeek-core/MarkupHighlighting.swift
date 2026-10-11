import Foundation

enum MarkupHighlighting {
    static func tokens(in text: String, html: Bool) throws -> [SyntaxToken] {
        var scanner = MarkupScanner(text: text, html: html)
        return try scanner.scan()
    }
}

private struct MarkupScanner {
    let units: [UInt16]
    let html: Bool
    var index = 0
    var tokens: [SyntaxToken] = []
    var rawEnd: [UInt16]?

    init(text: String, html: Bool) {
        units = Array(text.utf16)
        self.html = html
    }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            if let end = rawEnd {
                // HTML text elements suppress markup until their own closing tag.
                let boundary = index + end.count
                if !end.isEmpty && units[index] == 60 && has(end, foldingCase: true)
                    && boundary < units.count && (isSpace(units[boundary]) || [47, 62].contains(units[boundary])) {
                    rawEnd = nil
                } else {
                    index += 1
                    continue
                }
            }
            guard units[index] == 60 else { index += 1; continue }
            let start = index
            if has([60, 33, 45, 45]) {
                index += 4
                try consume(until: [45, 45, 62])
                append(from: start, kind: .comment)
            } else if has([60, 33, 91, 67, 68, 65, 84, 65, 91]) {
                index += 9
                try consume(until: [93, 93, 62])
                append(from: start, kind: .string)
            } else if has([60, 33]) {
                try consumeDeclaration()
                append(from: start, kind: .section)
            } else {
                try consumeTag()
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func consumeTag() throws {
        let start = index
        index += 1
        let instruction = index < units.count && units[index] == 63
        let closing = index < units.count && units[index] == 47
        if instruction || closing { index += 1 }
        guard index < units.count && isNameStart(units[index]) else { return }
        let nameStart = index
        while index < units.count && isNamePart(units[index]) { index += 1 }
        let name = String(decoding: units[nameStart..<index], as: UTF16.self).lowercased()
        let kind: SyntaxToken.Kind = instruction ? .section : .keyword
        append(from: start, kind: kind)
        if instruction && name != "xml" {
            // Processing instruction data ends at ?> even inside quote characters.
            let dataStart = index
            try consume(until: [63, 62])
            append(from: dataStart, kind: .section)
            return
        }
        while index < units.count {
            try Task.checkCancellation()
            skipSpaces()
            guard index < units.count else { return }
            let end = index
            if (instruction && has([63, 62])) || (!instruction && has([47, 62])) {
                index += 2
                append(from: end, kind: kind)
                setRawElement(name, closing: closing, instruction: instruction)
                return
            } else if !instruction && units[index] == 62 {
                index += 1
                append(from: end, kind: kind)
                setRawElement(name, closing: closing, instruction: instruction)
                return
            } else if units[index] == 60 {
                return
            }
            if units[index] == 34 || units[index] == 39 {
                try consumeQuoted()
                append(from: end, kind: .string)
                continue
            }
            while index < units.count && !isSpace(units[index]) && ![34, 39, 47, 60, 61, 62, 63].contains(units[index]) {
                index += 1
            }
            append(from: end, kind: .key)
            skipSpaces()
            if index < units.count && units[index] == 61 {
                index += 1
                skipSpaces()
                let valueStart = index
                if index < units.count && (units[index] == 34 || units[index] == 39) {
                    try consumeQuoted()
                } else {
                    while index < units.count && !isSpace(units[index]) && units[index] != 62
                        && !(instruction && has([63, 62])) && !(!html && has([47, 62])) {
                        index += 1
                    }
                }
                append(from: valueStart, kind: .string)
            } else if index == end {
                index += 1
            }
        }
    }

    private mutating func setRawElement(_ name: String, closing: Bool, instruction: Bool) {
        guard html && !closing && !instruction else { return }
        if name == "plaintext" {
            rawEnd = []
        } else if Self.textElements.contains(name) {
            rawEnd = Array("</\(name)".utf16)
        }
    }

    private mutating func consumeDeclaration() throws {
        index += 2
        var brackets = 0
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 34 || units[index] == 39 {
                try consumeQuoted()
            } else if has([60, 33, 45, 45]) {
                index += 4
                try consume(until: [45, 45, 62])
            } else {
                let unit = units[index]
                index += 1
                if unit == 91 { brackets += 1 }
                if unit == 93 { brackets = max(0, brackets - 1) }
                if unit == 62 && brackets == 0 { return }
            }
        }
    }

    private mutating func consumeQuoted() throws {
        let quote = units[index]
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            let unit = units[index]
            index += 1
            if unit == quote { return }
        }
    }

    private mutating func consume(until end: [UInt16]) throws {
        while index < units.count {
            try Task.checkCancellation()
            if has(end) { index += end.count; return }
            index += 1
        }
    }

    private mutating func append(from start: Int, kind: SyntaxToken.Kind) {
        if index > start {
            tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
        }
    }

    private mutating func skipSpaces() {
        while index < units.count && isSpace(units[index]) { index += 1 }
    }

    private func has(_ prefix: [UInt16], foldingCase: Bool = false) -> Bool {
        guard index + prefix.count <= units.count else { return false }
        for offset in prefix.indices {
            let unit = units[index + offset]
            let compared = foldingCase && (65...90).contains(unit) ? unit + 32 : unit
            if compared != prefix[offset] { return false }
        }
        return true
    }

    private func isSpace(_ unit: UInt16) -> Bool { [9, 10, 12, 13, 32].contains(unit) }
    private func isNameStart(_ unit: UInt16) -> Bool {
        (65...90).contains(unit) || (97...122).contains(unit) || (!html && (unit == 58 || unit == 95 || unit >= 128))
    }
    private func isNamePart(_ unit: UInt16) -> Bool {
        isNameStart(unit) || unit >= 128 || (48...57).contains(unit) || [45, 46, 58, 95].contains(unit)
    }
    private static let textElements: Set<String> = ["script", "style", "textarea", "title", "xmp", "iframe", "noembed", "noframes"]
}
