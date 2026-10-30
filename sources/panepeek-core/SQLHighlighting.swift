import Foundation

enum SQLHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = SQLScanner(text: text)
        return try scanner.scan()
    }
}

private struct SQLScanner {
    let units: [UInt16]
    let source: NSString
    var index = 0
    var tokens: [SyntaxToken] = []

    init(text: String) {
        units = Array(text.utf16)
        source = text as NSString
    }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            if [9, 10, 13, 32].contains(unit) {
                index += 1
                continue
            }
            var kind: SyntaxToken.Kind?
            if SyntaxScanning.hasPrefix([45, 45], in: units, at: index) {
                while index < units.count && !SyntaxScanning.isCRorLF(units[index]) {
                    try Task.checkCancellation()
                    index += 1
                }
                kind = .comment
            } else if SyntaxScanning.hasPrefix([47, 42], in: units, at: index) {
                try consumeComment()
                kind = .comment
            } else if [39, 34, 96, 91].contains(unit) {
                try consumeQuote(escaping: false)
                kind = unit == 39 ? .string : .reference
            } else if index + 1 < units.count && [69, 101, 78, 110, 66, 98, 88, 120].contains(unit) && units[index + 1] == 39 {
                index += 1
                try consumeQuote(escaping: unit == 69 || unit == 101)
                kind = .string
            } else if index + 2 < units.count && [85, 117].contains(unit) && units[index + 1] == 38 && [39, 34].contains(units[index + 2]) {
                index += 2
                let quote = units[index]
                try consumeQuote(escaping: false)
                kind = quote == 39 ? .string : .reference
            } else if unit == 36, let delimiterEnd = try dollarDelimiterEnd() {
                let delimiter = source.substring(with: NSRange(location: index, length: delimiterEnd - index))
                let closing = source.range(of: delimiter, options: .literal, range: NSRange(location: delimiterEnd, length: units.count - delimiterEnd))
                try Task.checkCancellation()
                index = closing.location == NSNotFound ? units.count : NSMaxRange(closing)
                kind = .string
            } else if isParameterStart() {
                index += 1
                try consumeNameTail()
                kind = .reference
            } else if isName(unit) || SyntaxScanning.isASCIIDigit(unit) || unit == 35 {
                index += 1
                try consumeNameTail()
                if units[start..<index].allSatisfy({ $0 < 128 }) {
                    let word = String(decoding: units[start..<index], as: UTF16.self).uppercased()
                    if Self.literals.contains(word) { kind = .literal }
                    else if Self.keywords.contains(word) { kind = .keyword }
                }
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

    private func isParameterStart() -> Bool {
        guard [36, 58, 64].contains(units[index]), index + 1 < units.count else { return false }
        if units[index] == 58 && index > 0 && units[index - 1] == 58 { return false }
        let next = units[index + 1]
        return isName(next) || SyntaxScanning.isASCIIDigit(next) || next == 64
    }

    private mutating func consumeNameTail() throws {
        while index < units.count && (isName(units[index]) || SyntaxScanning.isASCIIDigit(units[index]) || [35, 36, 64].contains(units[index])) {
            try Task.checkCancellation()
            index += 1
        }
    }

    private mutating func consumeQuote(escaping: Bool) throws {
        let quote = units[index]
        let closing: UInt16 = quote == 91 ? 93 : quote
        index += 1
        while index < units.count {
            try Task.checkCancellation()
            if units[index] == closing {
                index += 1
                if index < units.count && units[index] == closing { index += 1 }
                else { return }
            } else if escaping && units[index] == 92 {
                index = min(index + 2, units.count)
            } else {
                index += 1
            }
        }
    }

    private mutating func consumeComment() throws {
        index += 2
        var depth = 1
        while index < units.count && depth > 0 {
            try Task.checkCancellation()
            if SyntaxScanning.hasPrefix([47, 42], in: units, at: index) {
                depth += 1
                index += 2
            } else if SyntaxScanning.hasPrefix([42, 47], in: units, at: index) {
                depth -= 1
                index += 2
            } else {
                index += 1
            }
        }
    }

    private func dollarDelimiterEnd() throws -> Int? {
        var end = index + 1
        if end < units.count && units[end] == 36 { return end + 1 }
        guard end < units.count && isName(units[end]) else { return nil }
        while end < units.count && (isName(units[end]) || SyntaxScanning.isASCIIDigit(units[end])) {
            try Task.checkCancellation()
            end += 1
        }
        return end < units.count && units[end] == 36 ? end + 1 : nil
    }

    private func isName(_ unit: UInt16) -> Bool { (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || unit >= 128 }
    private static let literals: Set<String> = ["NULL", "TRUE", "FALSE"]
    private static let keywords: Set<String> = [
        "ADD", "ALL", "ALTER", "ANALYZE", "AND", "AS", "ASC", "BEGIN", "BETWEEN", "BY", "CASCADE",
        "CASE", "CAST", "CHECK", "COLLATE", "COLUMN", "COMMIT", "CONFLICT", "CONSTRAINT", "CREATE",
        "CROSS", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP", "DATABASE", "DEFAULT", "DELETE",
        "DESC", "DISTINCT", "DO", "DROP", "ELSE", "END", "ESCAPE", "EXCEPT", "EXISTS", "EXPLAIN",
        "FILTER", "FOR", "FOREIGN", "FROM", "FULL", "GROUP", "HAVING", "IF", "ILIKE", "IN", "INDEX",
        "INNER", "INSERT", "INTERSECT", "INTO", "IS", "JOIN", "KEY", "LEFT", "LIKE", "LIMIT", "MATERIALIZED",
        "NATURAL", "NOT", "NOTHING", "NULLS", "OFFSET", "ON", "OR", "ORDER", "OUTER", "OVER", "PARTITION",
        "PRIMARY", "RECURSIVE", "REFERENCES", "RELEASE", "RENAME", "REPLACE", "RETURN", "RETURNING", "RIGHT",
        "ROLLBACK", "ROW", "ROWS", "SAVEPOINT", "SELECT", "SET", "TABLE", "THEN", "TRANSACTION", "TRIGGER",
        "TRUNCATE", "UNION", "UNIQUE", "UPDATE", "USING", "VALUES", "VIEW", "WHEN", "WHERE", "WINDOW", "WITH"
    ]
}
