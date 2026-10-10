import Foundation

enum StyleHighlighting {
    static func tokens(in text: String, scss: Bool) throws -> [SyntaxToken] {
        var scanner = StyleScanner(text: text, scss: scss)
        return try scanner.scan()
    }
}

private struct StyleScanner {
    private struct PendingToken {
        let range: NSRange
        let kind: SyntaxToken.Kind?
    }

    let units: [UInt16]
    let scss: Bool
    var index = 0
    var tokens: [SyntaxToken] = []
    private var pending: [PendingToken] = []
    private var colon: Int?
    private var firstContent: Int?
    private var parentheses = 0
    private var brackets = 0
    private var braces = 0
    private var valueBraces = 0

    init(text: String, scss: Bool) {
        units = Array(text.utf16)
        self.scss = scss
    }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            var kind: SyntaxToken.Kind?
            if isSpace(unit) {
                index += 1
                continue
            } else if has([47, 42]) {
                try consumeComment()
                kind = .comment
            } else if scss && has([47, 47]) {
                while index < units.count && !isNewline(units[index]) { index += 1 }
                kind = .comment
            } else {
                if firstContent == nil { firstContent = index }
                if unit == 34 || unit == 39 {
                    try consumeString()
                    kind = .string
                } else if scss && has([35, 123]) {
                    try consumeInterpolation()
                    kind = .reference
                } else if ([64, 33].contains(unit) || (scss && unit == 36)) && isNameStart(at: index + 1) {
                    index += 1
                    try consumeName()
                    kind = unit == 36 && scss ? .reference : .keyword
                } else if startsNumber() {
                    try consumeNumber()
                    kind = .number
                } else if isNameStart(at: index) || (unit == 35 && index + 1 < units.count && isName(units[index + 1]))
                    || ((unit == 46 || (scss && unit == 37)) && isNameStart(at: index + 1)) {
                    if [46, 35, 37].contains(unit) { index += 1 }
                    try consumeName()
                    let name = String(decoding: units[start..<index], as: UTF16.self)
                    if name.lowercased() == "url" && index < units.count && units[index] == 40 && unquotedURL() {
                        try consumeURL()
                        kind = .string
                    }
                } else if unit == 38 || unit == 42 {
                    index += 1
                } else {
                    if parentheses == 0 && brackets == 0 {
                        if unit == 58 && colon == nil && valueBraces == 0 { colon = index }
                        if unit == 123 && (valueBraces > 0 || isCustomProperty) {
                            valueBraces += 1
                        } else if unit == 125 && valueBraces > 0 {
                            valueBraces -= 1
                        } else if [59, 123, 125].contains(unit) && valueBraces == 0 {
                            flush(ending: unit)
                            if unit == 123 { braces += 1 }
                            if unit == 125 { braces = max(0, braces - 1) }
                        }
                    }
                    if unit == 40 { parentheses += 1 }
                    if unit == 41 { parentheses = max(0, parentheses - 1) }
                    if unit == 91 { brackets += 1 }
                    if unit == 93 { brackets = max(0, brackets - 1) }
                    index += 1
                    continue
                }
            }
            pending.append(PendingToken(range: NSRange(location: start, length: index - start), kind: kind))
        }
        flush(ending: nil)
        try Task.checkCancellation()
        return tokens
    }

    private var isCustomProperty: Bool {
        guard colon != nil, let start = firstContent else { return false }
        return start + 1 < units.count && units[start] == 45 && units[start + 1] == 45
    }

    private mutating func flush(ending: UInt16?) {
        let directive = firstContent.map { units[$0] == 64 } ?? false
        let variable = scss && (firstContent.map { units[$0] == 36 } ?? false)
        let propertyEnd = colon ?? -1
        let property = colon != nil && !directive && (braces > 0 || variable)
            && (ending != 123 || isCustomProperty || (scss && pending.allSatisfy { $0.kind == .comment || NSMaxRange($0.range) <= propertyEnd }))
        let valueKind: SyntaxToken.Kind = property || directive ? .literal : .section
        // Decide once per statement, so a pseudo-selector's colon cannot start a value.
        for item in pending {
            let kind = item.kind ?? (property && NSMaxRange(item.range) <= propertyEnd ? .key : valueKind)
            tokens.append(SyntaxToken(range: item.range, kind: kind))
        }
        pending.removeAll(keepingCapacity: true)
        colon = nil
        firstContent = nil
    }

    private mutating func consumeComment() throws {
        index += 2
        while index < units.count && !has([42, 47]) {
            try Task.checkCancellation()
            index += 1
        }
        if index < units.count { index += 2 }
    }

    private mutating func consumeString(depth: Int = 0) throws {
        guard depth < 32 else { index = units.count; return }
        let quote = units[index]
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == quote {
                index += 1
                return
            } else if units[index] == 92 {
                index += 1
                if index < units.count && units[index] == 13 && index + 1 < units.count && units[index + 1] == 10 { index += 1 }
                if index < units.count { index += 1 }
            } else if scss && has([35, 123]) {
                try consumeInterpolation(depth: depth + 1)
            } else if isNewline(units[index]) {
                return
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeInterpolation(depth: Int = 0) throws {
        guard depth < 32 else { index = units.count; return }
        index += 2
        var nesting = 1
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 34 || units[index] == 39 {
                try consumeString(depth: depth + 1)
            } else if has([47, 42]) {
                try consumeComment()
            } else if has([47, 47]) {
                while index < units.count && !isNewline(units[index]) { index += 1 }
            } else {
                if units[index] == 123 { nesting += 1 }
                if units[index] == 125 { nesting -= 1 }
                index += 1
                if nesting == 0 { return }
            }
        }
    }

    private func unquotedURL() -> Bool {
        var end = index + 1
        while end < units.count && isSpace(units[end]) { end += 1 }
        return end == units.count || ![34, 39].contains(units[end])
    }

    private mutating func consumeURL() throws {
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 41 {
                index += 1
                return
            } else if units[index] == 92 {
                consumeEscape()
            } else if scss && has([35, 123]) {
                try consumeInterpolation()
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeName() throws {
        while index < units.count {
            try Task.checkCancellation()
            if isName(units[index]) {
                index += 1
            } else if units[index] == 92 && index + 1 < units.count && !isNewline(units[index + 1]) {
                consumeEscape()
            } else {
                return
            }
        }
    }

    private mutating func consumeEscape() {
        index += 1
        var count = 0
        while index < units.count && isHex(units[index]) && count < 6 {
            index += 1
            count += 1
        }
        if count == 0 {
            if index < units.count { index += 1 }
        } else if index < units.count && isSpace(units[index]) {
            if units[index] == 13 && index + 1 < units.count && units[index + 1] == 10 { index += 1 }
            index += 1
        }
    }

    private func startsNumber() -> Bool {
        var end = index
        if [43, 45].contains(units[end]) { end += 1 }
        if end < units.count && isDigit(units[end]) { return true }
        return end + 1 < units.count && units[end] == 46 && isDigit(units[end + 1])
    }

    private mutating func consumeNumber() throws {
        if [43, 45].contains(units[index]) { index += 1 }
        while index < units.count && isDigit(units[index]) { index += 1 }
        if index + 1 < units.count && units[index] == 46 && isDigit(units[index + 1]) {
            index += 1
            while index < units.count && isDigit(units[index]) { index += 1 }
        }
        if index < units.count && [69, 101].contains(units[index]) {
            var exponent = index + 1
            if exponent < units.count && [43, 45].contains(units[exponent]) { exponent += 1 }
            if exponent < units.count && isDigit(units[exponent]) {
                index = exponent + 1
                while index < units.count && isDigit(units[index]) { index += 1 }
            }
        }
        if isNameStart(at: index) { try consumeName() }
        if index < units.count && units[index] == 37 { index += 1 }
    }

    private func has(_ prefix: [UInt16]) -> Bool {
        index + prefix.count <= units.count && units[index..<(index + prefix.count)].elementsEqual(prefix)
    }
    private func isDigit(_ unit: UInt16) -> Bool { (48...57).contains(unit) }
    private func isHex(_ unit: UInt16) -> Bool { isDigit(unit) || (65...70).contains(unit) || (97...102).contains(unit) }
    private func isNewline(_ unit: UInt16) -> Bool { [10, 12, 13].contains(unit) }
    private func isSpace(_ unit: UInt16) -> Bool { [9, 10, 12, 13, 32].contains(unit) }
    private func isName(_ unit: UInt16) -> Bool {
        (65...90).contains(unit) || (97...122).contains(unit) || isDigit(unit) || unit == 45 || unit == 95 || unit >= 128
    }
    private func isNameStart(at position: Int) -> Bool {
        guard position < units.count else { return false }
        let unit = units[position]
        return (isName(unit) && !isDigit(unit)) || (unit == 92 && position + 1 < units.count && !isNewline(units[position + 1]))
    }
}
