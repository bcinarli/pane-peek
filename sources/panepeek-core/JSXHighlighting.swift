import Foundation

extension JavaScriptScanner {
    func isJSXStart() -> Bool {
        if has([60, 62]) { return true }
        guard index + 1 < units.count && isIdentifierStart(units[index + 1]) else { return false }
        var end = index + 1
        while end < units.count && isJSXNamePart(units[end]) { end += 1 }
        while end < units.count && isSpace(units[end]) { end += 1 }
        if typescript {
            // Common generic arrow functions are code, not opening JSX tags.
            if end < units.count && [44, 61].contains(units[end]) { return false }
            let constraint: [UInt16] = [101, 120, 116, 101, 110, 100, 115]
            if end + constraint.count < units.count && units[end..<(end + constraint.count)].elementsEqual(constraint)
                && isSpace(units[end + constraint.count]) { return false }
        }
        return true
    }

    mutating func consumeJSX(collectTokens: Bool, depth: Int) throws {
        // Bound mixed element/expression recursion; the remaining source stays readable.
        guard depth < 32 else { index = units.count; return }
        if try consumeJSXTag(collectTokens: collectTokens, depth: depth) { return }
        while index < units.count {
            try Task.checkCancellation()
            if has([60, 47]) {
                _ = try consumeJSXTag(collectTokens: collectTokens, depth: depth)
                return
            } else if units[index] == 60 && isJSXStart() {
                try consumeJSX(collectTokens: collectTokens, depth: depth + 1)
            } else if units[index] == 123 {
                try consumeJSXExpression(collectTokens: collectTokens, depth: depth)
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeJSXTag(collectTokens: Bool, depth: Int) throws -> Bool {
        let start = index
        let closing = has([60, 47])
        index += closing ? 2 : 1
        if index < units.count && units[index] == 62 {
            index += 1
            appendJSX(from: start, kind: .keyword, collectTokens: collectTokens)
            return closing
        }
        while index < units.count && isJSXNamePart(units[index]) { index += 1 }
        appendJSX(from: start, kind: .keyword, collectTokens: collectTokens)
        if typescript && index < units.count && units[index] == 60 {
            try consumeJSXTypeArguments(depth: depth)
        }
        while index < units.count {
            try Task.checkCancellation()
            let attribute = index
            if isSpace(units[index]) {
                index += 1
            } else if has([47, 62]) || units[index] == 62 {
                let selfClosing = has([47, 62])
                index += selfClosing ? 2 : 1
                appendJSX(from: attribute, kind: .keyword, collectTokens: collectTokens)
                return closing || selfClosing
            } else if units[index] == 123 {
                try consumeJSXExpression(collectTokens: collectTokens, depth: depth)
            } else if units[index] == 34 || units[index] == 39 {
                let quote = units[index]
                index += 1
                while index < units.count && units[index] != quote {
                    try Task.checkCancellation()
                    index += 1
                }
                if index < units.count { index += 1 }
                appendJSX(from: attribute, kind: .string, collectTokens: collectTokens)
            } else if isJSXNamePart(units[index]) {
                while index < units.count && isJSXNamePart(units[index]) { index += 1 }
                appendJSX(from: attribute, kind: .key, collectTokens: collectTokens)
            } else if units[index] == 60 && isJSXStart() {
                try consumeJSX(collectTokens: collectTokens, depth: depth + 1)
            } else if units[index] == 60 {
                return true
            } else {
                index += 1
            }
        }
        return true
    }

    private mutating func consumeJSXExpression(collectTokens: Bool, depth: Int) throws {
        let start = index
        index += 1
        appendJSX(from: start, kind: .reference, collectTokens: collectTokens)
        if try scanCode(collectTokens: collectTokens, interpolation: true, depth: depth + 1) {
            appendJSX(from: index - 1, kind: .reference, collectTokens: collectTokens)
        }
    }

    private mutating func consumeJSXTypeArguments(depth: Int) throws {
        var brackets = 0
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == 34 || units[index] == 39 {
                consumeQuoted()
            } else if units[index] == 96 {
                try consumeTemplate(depth: depth)
            } else if has([47, 42]) {
                index += 2
                while index < units.count && !has([42, 47]) {
                    try Task.checkCancellation()
                    index += 1
                }
                if index < units.count { index += 2 }
            } else if has([47, 47]) {
                while index < units.count && ![10, 13, 0x2028, 0x2029].contains(units[index]) { index += 1 }
            } else if has([61, 62]) {
                index += 2
            } else {
                let unit = units[index]
                index += 1
                if unit == 60 { brackets += 1 }
                if unit == 62 { brackets -= 1 }
                if brackets == 0 { return }
            }
        }
    }

    private mutating func appendJSX(from start: Int, kind: SyntaxToken.Kind, collectTokens: Bool) {
        if collectTokens && index > start {
            tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
        }
    }

    private func isJSXNamePart(_ unit: UInt16) -> Bool {
        isIdentifierStart(unit) || (48...57).contains(unit) || [45, 46, 58].contains(unit)
    }
}
