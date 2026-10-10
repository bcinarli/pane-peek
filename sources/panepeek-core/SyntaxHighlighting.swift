import Foundation

/// A presentation-only UTF-16 range for native attributed text.
public struct SyntaxToken: Sendable, Equatable {
    public enum Kind: Sendable { case keyword, string, comment, number, literal }
    public let range: NSRange
    public let kind: Kind
}

public enum SyntaxHighlighting {
    /// Return ordered, non-overlapping tokens for supported extensions, leaving other text plain.
    public static func tokens(in text: String, fileExtension: String) async throws -> [SyntaxToken] {
        try Task.checkCancellation()
        guard ["swift", "json"].contains(fileExtension.lowercased()) else { return [] }
        let worker = Task.detached(priority: .userInitiated) {
            var scanner = Scanner(text: text, swift: fileExtension.lowercased() == "swift")
            return try scanner.scan()
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

private struct Scanner {
    let units: [UInt16]
    let swift: Bool
    var index = 0
    var tokens: [SyntaxToken] = []

    init(text: String, swift: Bool) {
        units = Array(text.utf16)
        self.swift = swift
    }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            if swift, let end = commentEnd(at: index) {
                index = end
                append(.comment, from: start)
            } else if let end = stringEnd(at: index) {
                index = end
                append(.string, from: start)
            } else if swift && units[index] == 96 {
                index += 1
                while index < units.count && units[index] != 96 && !isNewline(units[index]) { index += 1 }
                if index < units.count && units[index] == 96 { index += 1 }
            } else if isIdentifier(units[index]) && !isDigit(units[index]) {
                index += 1
                while index < units.count && isIdentifier(units[index]) { index += 1 }
                let word = String(decoding: units[start..<index], as: UTF16.self)
                if swift && Self.keywords.contains(word) {
                    append(.keyword, from: start)
                } else if !swift && ["true", "false", "null"].contains(word) && jsonBoundary(at: start - 1) && jsonBoundary(at: index) {
                    append(.literal, from: start)
                }
            } else if !swift && (isDigit(units[index]) || units[index] == 45) {
                let number = jsonNumber(at: index)
                index = max(index + 1, number.end)
                if number.valid && jsonBoundary(at: start - 1) && jsonBoundary(at: index) {
                    append(.number, from: start)
                }
            } else {
                index += 1
                // Skip an unquoted hash run once instead of rescanning each suffix.
                if swift && units[start] == 35 {
                    while index < units.count && units[index] == 35 { index += 1 }
                }
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int) {
        tokens.append(SyntaxToken(range: NSRange(location: start, length: index - start), kind: kind))
    }

    private func commentEnd(at start: Int) -> Int? {
        if has([47, 47], at: start) {
            var end = start + 2
            while end < units.count && !isNewline(units[end]) { end += 1 }
            return end
        }
        guard has([47, 42], at: start) else { return nil }
        var end = start + 2
        var nesting = 1
        while end < units.count {
            if has([47, 42], at: end) {
                nesting += 1
                end += 2
            } else if has([42, 47], at: end) {
                nesting -= 1
                end += 2
                if nesting == 0 { return end }
            } else {
                end += 1
            }
        }
        return end
    }

    private func stringEnd(at start: Int, depth: Int = 0) -> Int? {
        var quote = start
        if swift {
            while quote < units.count && units[quote] == 35 { quote += 1 }
        }
        guard quote < units.count && units[quote] == 34 else { return nil }
        // Pathological nested interpolation must not exhaust the call stack.
        guard depth < 32 else { return units.count }
        let hashes = Array(repeating: UInt16(35), count: quote - start)
        let quoteCount = swift && has([34, 34, 34], at: quote) ? 3 : 1
        let closing = Array(repeating: UInt16(34), count: quoteCount) + hashes
        let escape = [UInt16(92)] + hashes
        var end = quote + quoteCount
        while end < units.count {
            if has(closing, at: end) { return end + closing.count }
            if has(escape, at: end) {
                end += escape.count
                if swift && end < units.count && units[end] == 40 {
                    end = interpolationEnd(at: end, depth: depth + 1)
                } else {
                    end = min(end + 1, units.count)
                }
            } else if quoteCount == 1 && isNewline(units[end]) {
                return end
            } else {
                end += 1
            }
        }
        return end
    }

    private func interpolationEnd(at start: Int, depth: Int) -> Int {
        var end = start + 1
        var parentheses = 1
        while end < units.count {
            if let comment = commentEnd(at: end) {
                end = comment
            } else if let string = stringEnd(at: end, depth: depth) {
                end = string
            } else {
                let unquotedHashes = units[end] == 35
                if units[end] == 40 { parentheses += 1 }
                if units[end] == 41 { parentheses -= 1 }
                end += 1
                if unquotedHashes {
                    while end < units.count && units[end] == 35 { end += 1 }
                }
                if parentheses == 0 { return end }
            }
        }
        return end
    }

    private func jsonNumber(at start: Int) -> (end: Int, valid: Bool) {
        var end = start
        if units[end] == 45 { end += 1 }
        guard end < units.count && isDigit(units[end]) else { return (end, false) }
        if units[end] == 48 {
            end += 1
        } else {
            while end < units.count && isDigit(units[end]) { end += 1 }
        }
        if end < units.count && units[end] == 46 {
            end += 1
            let fraction = end
            while end < units.count && isDigit(units[end]) { end += 1 }
            if fraction == end { return (end, false) }
        }
        if end < units.count && (units[end] == 69 || units[end] == 101) {
            end += 1
            if end < units.count && (units[end] == 43 || units[end] == 45) { end += 1 }
            let exponent = end
            while end < units.count && isDigit(units[end]) { end += 1 }
            if exponent == end { return (end, false) }
        }
        return (end, true)
    }

    private func has(_ prefix: [UInt16], at start: Int) -> Bool {
        guard start + prefix.count <= units.count else { return false }
        return units[start..<(start + prefix.count)].elementsEqual(prefix)
    }

    private func jsonBoundary(at position: Int) -> Bool {
        position < 0 || position >= units.count || [9, 10, 13, 32, 44, 58, 91, 93, 123, 125].contains(units[position])
    }

    private func isDigit(_ unit: UInt16) -> Bool { (48...57).contains(unit) }
    private func isNewline(_ unit: UInt16) -> Bool { unit == 10 || unit == 13 }
    private func isIdentifier(_ unit: UInt16) -> Bool {
        (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 || unit >= 128 || isDigit(unit)
    }

    private static let keywords: Set<String> = [
        "actor", "Any", "as", "associatedtype", "async", "await", "borrowing", "break", "case", "catch", "class",
        "consuming", "continue", "convenience", "default", "defer", "deinit", "didSet", "do", "dynamic",
        "else", "enum", "extension", "fallthrough", "false", "fileprivate", "final", "for", "func", "get",
        "guard", "if", "import", "in", "indirect", "infix", "init", "inout", "internal", "is", "isolated",
        "lazy", "let", "macro", "mutating", "nil", "nonisolated", "nonmutating", "open", "operator",
        "optional", "override", "package", "postfix", "precedencegroup", "prefix", "private", "protocol",
        "public", "repeat", "required", "rethrows", "return", "self", "Self", "set", "some", "static",
        "struct", "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "unowned",
        "var", "weak", "where", "while", "willSet"
    ]
}
