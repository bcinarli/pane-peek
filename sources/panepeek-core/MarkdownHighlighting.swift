import Foundation

enum MarkdownHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = MarkdownScanner(text: text)
        return try scanner.scan()
    }
}

private struct MarkdownScanner {
    let units: [UInt16]
    // Higher roles protect code and links while retaining headings behind inline colours.
    var roles: [UInt8]
    var references: Set<String> = []

    init(text: String) {
        units = Array(text.utf16)
        roles = Array(repeating: 0, count: units.count)
    }

    mutating func scan() throws -> [SyntaxToken] {
        var index = 0
        var paragraph: Int?
        var inlines: [Range<Int>] = []
        var fence: (start: Int, marker: UInt16, length: Int)?
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            while index < units.count && !isNewline(units[index]) { index += 1 }
            let end = index
            if index < units.count {
                index += 1
                if units[end] == 13 && index < units.count && units[index] == 10 { index += 1 }
            }
            var content = start
            while content < end && units[content] == 32 { content += 1 }
            let indented = content - start > 3
            let markerEnd = content < end ? runEnd(at: content, limit: end) : end
            let marker = content < end ? units[content] : 0
            let markerLength = markerEnd - content
            if let open = fence {
                if !indented && marker == open.marker && markerLength >= open.length && units[markerEnd..<end].allSatisfy(isSpace) {
                    paint(4, open.start..<end)
                    fence = nil
                }
                continue
            }
            if !indented && [96, 126].contains(marker) && markerLength >= 3 && (marker == 126 || !units[markerEnd..<end].contains(96)) {
                if let paragraph { inlines.append(paragraph..<start) }
                paragraph = nil
                fence = (content, marker, markerLength)
            } else if units[start..<end].allSatisfy(isSpace) {
                if let paragraph { inlines.append(paragraph..<start) }
                paragraph = nil
            } else if !indented, let label = definitionLabel(in: content..<end) {
                if let paragraph { inlines.append(paragraph..<start) }
                paragraph = nil
                references.insert(label)
                paint(3, content..<end)
            } else if !indented && marker == 35 && markerLength <= 6 && (markerEnd == end || isSpace(units[markerEnd])) {
                if let paragraph { inlines.append(paragraph..<start) }
                paragraph = nil
                paint(2, content..<end)
                inlines.append(content..<end)
            } else if !indented && [61, 45].contains(marker) && units[markerEnd..<end].allSatisfy(isSpace), let previous = paragraph {
                paint(2, previous..<end)
                inlines.append(previous..<end)
                paragraph = nil
            } else if paragraph == nil {
                paragraph = start
            }
        }
        if let open = fence { paint(4, open.start..<units.count) }
        if let paragraph { inlines.append(paragraph..<units.count) }
        for range in inlines { try scanInline(range) }
        var tokens: [SyntaxToken] = []
        let kinds: [SyntaxToken.Kind] = [.keyword, .section, .reference, .string]
        index = 0
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let role = roles[index]
            repeat { index += 1 } while index < units.count && roles[index] == role
            if role > 0 {
                tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kinds[Int(role) - 1]))
            }
        }
        return tokens
    }

    private mutating func scanInline(_ range: Range<Int>) throws {
        var ticks: [Int: [Range<Int>]] = [:]
        var index = range.lowerBound
        while index < range.upperBound {
            try Task.checkCancellation()
            if units[index] == 96 {
                let end = runEnd(at: index, limit: range.upperBound)
                ticks[end - index, default: []].append(index..<end)
                index = end
            } else {
                index += 1
            }
        }
        var brackets: [Int] = []
        index = range.lowerBound
        while index < range.upperBound {
            try Task.checkCancellation()
            if isEscape(at: index, limit: range.upperBound) {
                index += 2
            } else if units[index] == 96 {
                let end = runEnd(at: index, limit: range.upperBound)
                if let candidates = ticks[end - index], let closing = nextTick(in: candidates, after: end) {
                    paint(4, index..<closing.upperBound)
                    index = closing.upperBound
                } else {
                    index = end
                }
            } else if units[index] == 91 {
                if brackets.count < 32 { brackets.append(index) }
                index += 1
            } else if units[index] == 93, let opening = brackets.popLast() {
                if let end = linkEnd(after: index, limit: range.upperBound) ?? (references.contains(referenceLabel(in: (opening + 1)..<index)) ? index + 1 : nil) {
                    let start = opening > range.lowerBound && units[opening - 1] == 33 && !escaped(at: opening - 1, lower: range.lowerBound) ? opening - 1 : opening
                    paint(3, start..<end)
                    brackets.removeAll(keepingCapacity: true)
                    index = end
                } else {
                    index += 1
                }
            } else if units[index] == 60, let end = autolinkEnd(at: index, limit: range.upperBound) {
                paint(3, index..<end)
                index = end
            } else {
                index += 1
            }
        }
        try scanEmphasis(range)
    }

    private struct Delimiter {
        let start: Int
        var length: Int
        let marker: UInt16
        let closes: Bool
    }

    private mutating func scanEmphasis(_ range: Range<Int>) throws {
        var stack: [Delimiter] = []
        var index = range.lowerBound
        while index < range.upperBound {
            try Task.checkCancellation()
            if roles[index] >= 3 {
                let role = roles[index]
                repeat { index += 1 } while index < range.upperBound && roles[index] == role
            } else if isEscape(at: index, limit: range.upperBound) {
                index += 2
            } else if units[index] == 42 || units[index] == 95 {
                let end = runEnd(at: index, limit: range.upperBound)
                let before = characterClass(at: index - 1, range: range)
                let after = characterClass(at: end, range: range)
                let left = !after.space && (!after.punctuation || before.space || before.punctuation)
                let right = !before.space && (!before.punctuation || after.space || after.punctuation)
                let opens = left && (units[index] == 42 || !right || before.punctuation)
                let closes = right && (units[index] == 42 || !left || after.punctuation)
                var position = index
                if closes {
                    while position < end, let matching = stack.lastIndex(where: {
                        $0.marker == units[index] && (!(opens || $0.closes) || ($0.length + end - position) % 3 != 0 || ($0.length % 3 == 0 && (end - position) % 3 == 0))
                    }) {
                        let used = min(stack[matching].length, end - position)
                        let opening = stack[matching].start + stack[matching].length - used
                        paint(1, opening..<(position + used))
                        stack[matching].length -= used
                        stack.removeSubrange((matching + 1)..<stack.count)
                        if stack[matching].length == 0 { stack.removeLast() }
                        position += used
                    }
                }
                if opens && position < end && stack.count < 32 {
                    stack.append(Delimiter(start: position, length: end - position, marker: units[index], closes: closes))
                }
                index = end
            } else {
                index += 1
            }
        }
    }

    private func definitionLabel(in range: Range<Int>) -> String? {
        guard range.lowerBound < range.upperBound && units[range.lowerBound] == 91 else { return nil }
        var end = range.lowerBound + 1
        while end < min(range.upperBound, range.lowerBound + 1001) && units[end] != 93 {
            if units[end] == 91 { return nil }
            end += isEscape(at: end, limit: range.upperBound) ? 2 : 1
        }
        guard end + 1 < range.upperBound && units[end] == 93 && units[end + 1] == 58 else { return nil }
        let label = referenceLabel(in: (range.lowerBound + 1)..<end)
        guard !label.isEmpty && units[(end + 2)..<range.upperBound].contains(where: { !isSpace($0) }) else { return nil }
        return label
    }

    private func referenceLabel(in range: Range<Int>) -> String {
        guard range.count <= 999 else { return "" }
        return String(decoding: units[range], as: UTF16.self).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
    }

    private func linkEnd(after close: Int, limit: Int) -> Int? {
        let start = close + 1
        guard start < limit else { return nil }
        // Bound incomplete destination lookahead and bracket depth in presentation-only input.
        let bound = min(limit, start + 4096)
        if units[start] == 91 {
            var end = start + 1
            while end < bound && !isNewline(units[end]) && units[end] != 91 {
                if units[end] == 93 { return end + 1 }
                end += isEscape(at: end, limit: bound) ? 2 : 1
            }
            return nil
        }
        guard units[start] == 40 else { return nil }
        var end = start + 1
        while end < bound && isSpace(units[end]) { end += 1 }
        if end < bound && units[end] == 60 {
            end += 1
            while end < bound && !isNewline(units[end]) && units[end] != 60 && units[end] != 62 {
                end += isEscape(at: end, limit: bound) ? 2 : 1
            }
            guard end < bound && units[end] == 62 else { return nil }
            end += 1
        } else {
            var depth = 0
            while end < bound && !isSpace(units[end]) && !isNewline(units[end]) {
                if isEscape(at: end, limit: bound) { end += 2; continue }
                if units[end] == 40 { depth += 1 }
                if units[end] == 41 {
                    if depth == 0 { return end + 1 }
                    depth -= 1
                }
                if depth > 32 || units[end] == 60 || units[end] < 32 { return nil }
                end += 1
            }
            guard depth == 0 else { return nil }
        }
        let separated = end < bound && isSpace(units[end])
        while end < bound && isSpace(units[end]) { end += 1 }
        if separated && end < bound && [34, 39, 40].contains(units[end]) {
            let closing: UInt16 = units[end] == 40 ? 41 : units[end]
            end += 1
            while end < bound && !isNewline(units[end]) && units[end] != closing {
                if closing == 41 && units[end] == 40 { return nil }
                end += isEscape(at: end, limit: bound) ? 2 : 1
            }
            guard end < bound && units[end] == closing else { return nil }
            end += 1
            while end < bound && isSpace(units[end]) { end += 1 }
        }
        return end < bound && units[end] == 41 ? end + 1 : nil
    }

    private func autolinkEnd(at start: Int, limit: Int) -> Int? {
        var end = start + 1
        while end < limit && units[end] != 62 && units[end] != 60 && !isNewline(units[end]) && !isSpace(units[end]) {
            end += 1
        }
        guard end < limit && units[end] == 62 else { return nil }
        let value = String(decoding: units[(start + 1)..<end], as: UTF16.self)
        guard value.range(of: #"^[A-Za-z][A-Za-z0-9+.-]{1,31}:[^<>\s]*$|^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$"#, options: .regularExpression) != nil else { return nil }
        return end + 1
    }

    private func nextTick(in candidates: [Range<Int>], after position: Int) -> Range<Int>? {
        var lower = 0
        var upper = candidates.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if candidates[middle].lowerBound < position { lower = middle + 1 } else { upper = middle }
        }
        return lower < candidates.count ? candidates[lower] : nil
    }

    private func characterClass(at position: Int, range: Range<Int>) -> (space: Bool, punctuation: Bool) {
        guard range.contains(position) else { return (true, false) }
        var value = UInt32(units[position])
        if (0xDC00...0xDFFF).contains(value) && position > range.lowerBound && (0xD800...0xDBFF).contains(units[position - 1]) {
            value = 0x10000 + (UInt32(units[position - 1]) - 0xD800) * 1024 + value - 0xDC00
        } else if (0xD800...0xDBFF).contains(value) && position + 1 < range.upperBound && (0xDC00...0xDFFF).contains(units[position + 1]) {
            value = 0x10000 + (value - 0xD800) * 1024 + UInt32(units[position + 1]) - 0xDC00
        }
        guard let scalar = Unicode.Scalar(value) else { return (false, false) }
        return (CharacterSet.whitespacesAndNewlines.contains(scalar), CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar))
    }

    private mutating func paint(_ role: UInt8, _ range: Range<Int>) {
        for index in range where roles[index] < role { roles[index] = role }
    }

    private func runEnd(at start: Int, limit: Int) -> Int {
        var end = start + 1
        while end < limit && units[end] == units[start] { end += 1 }
        return end
    }

    private func escaped(at position: Int, lower: Int) -> Bool {
        var start = position
        while start > lower && units[start - 1] == 92 { start -= 1 }
        return (position - start) % 2 == 1
    }

    private func isEscape(at position: Int, limit: Int) -> Bool {
        guard units[position] == 92 && position + 1 < limit else { return false }
        let next = units[position + 1]
        return (33...47).contains(next) || (58...64).contains(next) || (91...96).contains(next) || (123...126).contains(next)
    }

    private func isSpace(_ unit: UInt16) -> Bool { unit == 32 || unit == 9 }
    private func isNewline(_ unit: UInt16) -> Bool { unit == 10 || unit == 13 }
}
