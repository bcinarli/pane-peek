import Foundation

enum MakefileHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = MakefileScanner(text: text)
        return try scanner.scan()
    }
}

private struct MakefileScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []
    var ruleContext = false
    var recipePrefix: UInt16 = 9
    var defineDepth = 0

    init(text: String) { units = Array(text.utf16) }

    mutating func scan() throws -> [SyntaxToken] {
        while index < units.count {
            try Task.checkCancellation()
            let start = index
            let end = try logicalEnd(at: index)
            if defineDepth > 0 {
                if units[start] != recipePrefix {
                    skipSpace(end: end)
                    let word = word(at: index, end: end)
                    if word == "endef" {
                        append(.keyword, from: index, to: index + word.utf16.count)
                        index += word.utf16.count
                        defineDepth -= 1
                        try readBody(end: end)
                    } else if isDefinition(word: word, end: end) {
                        _ = try readDirectives(end: end)
                        try readDefinition(end: end)
                    } else {
                        append(.string, from: start, to: end)
                    }
                } else {
                    append(.string, from: start, to: end)
                }
            } else if ruleContext && units[start] == recipePrefix {
                index += 1
                try readBody(end: end, recipe: true)
            } else {
                skipSpace(end: end)
                if index < end && units[index] != 35 {
                    let directive = try readDirectives(end: end)
                    if directive == "define" { try readDefinition(end: end) }
                    else if directive.isEmpty || Self.modifiers.contains(directive) { try readStatement(end: end) }
                    else { try readBody(end: end) }
                } else {
                    try readBody(end: end)
                }
            }
            index = nextLine(after: end)
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func readDirectives(end: Int) throws -> String {
        var last = ""
        while index < end {
            try Task.checkCancellation()
            let word = word(at: index, end: end)
            guard Self.directives.contains(word) else { break }
            append(.keyword, from: index, to: index + word.utf16.count)
            index += word.utf16.count
            skipSpace(end: end)
            last = word
            if !Self.modifiers.contains(word) && word != "else" { break }
        }
        return last
    }

    private mutating func readDefinition(end: Int) throws {
        defineDepth += 1
        ruleContext = false
        let separator = try separator(end: end)
        let nameEnd = separator?.start ?? end
        try readBody(end: nameEnd, plainKind: .key)
        index = separator?.end ?? index
        try readBody(end: end)
    }

    private mutating func readStatement(end: Int) throws {
        let start = index
        guard let separator = try separator(end: end) else {
            ruleContext = false
            try readBody(end: end)
            return
        }
        try readBody(end: separator.start, plainKind: separator.assignment ? .key : .section)
        index = separator.end
        if separator.assignment {
            ruleContext = false
            let name = String(decoding: units[start..<separator.start], as: UTF16.self).trimmingCharacters(in: .whitespaces)
            if name == ".RECIPEPREFIX" {
                skipSpace(end: end)
                if index == end || units[index] == 35 { recipePrefix = 9 }
                else if units[index] != 36 { recipePrefix = units[index] }
            }
            try readBody(end: end)
        } else {
            ruleContext = true
            skipSpace(end: end)
            if let assignment = try self.separator(end: end), assignment.assignment {
                _ = try readDirectives(end: assignment.start)
                try readBody(end: assignment.start, plainKind: .key)
                index = assignment.end
                try readBody(end: end)
            } else {
                try readBody(end: end, inlineRecipe: true)
            }
        }
    }

    private func separator(end: Int) throws -> (start: Int, end: Int, assignment: Bool)? {
        var position = index
        while position < end {
            try Task.checkCancellation()
            let unit = units[position]
            if unit == 35 || unit == 59 { return nil }
            if unit == 92 { position = min(position + 2, end); continue }
            if unit == 36 { position = try referenceEnd(at: position, end: end); continue }
            if unit == 61 {
                let start = position > index && [43, 63, 33].contains(units[position - 1]) ? position - 1 : position
                return (start, position + 1, true)
            }
            if unit == 58 {
                var last = position + 1
                while last < end && units[last] == 58 { last += 1 }
                if last < end && units[last] == 61 { return (position, last + 1, true) }
                let start = position > index && units[position - 1] == 38 ? position - 1 : position
                return (start, last, false)
            }
            position += 1
        }
        return nil
    }

    private mutating func readBody(end: Int, recipe: Bool = false, inlineRecipe: Bool = false, plainKind: SyntaxToken.Kind? = nil) throws {
        var recipe = recipe
        while index < end {
            try Task.checkCancellation()
            let start = index
            let unit = units[index]
            if isSpace(unit) || unit == 10 || unit == 13 {
                index += 1
            } else if unit == 35 && (!recipe || start == 0 || isShellBoundary(units[start - 1]) || units[start - 1] == recipePrefix) {
                if recipe {
                    while index < end && units[index] != 10 && units[index] != 13 { index += 1 }
                } else { index = end }
                append(.comment, from: start, to: index)
            } else if unit == 34 || unit == 39 || (recipe && unit == 96) {
                index = try quotedEnd(at: index, end: end, recipe: recipe)
                append(.string, from: start, to: index)
            } else if unit == 36 {
                index = try referenceEnd(at: index, end: end)
                if start + 1 < end && units[start + 1] != 36 { append(.reference, from: start, to: index) }
            } else if inlineRecipe && unit == 59 {
                recipe = true
                index += 1
            } else if let plainKind {
                repeat {
                    if units[index] == 92 { index = min(index + 2, end) }
                    else { index += 1 }
                    try Task.checkCancellation()
                } while index < end && !isSpace(units[index]) && ![10, 13, 35, 36, 34, 39].contains(units[index])
                append(plainKind, from: start, to: index)
            } else if unit == 92 {
                index = min(index + 2, end)
            } else {
                index += 1
            }
        }
    }

    private func quotedEnd(at start: Int, end: Int, recipe: Bool) throws -> Int {
        let quote = units[start]
        var position = start + 1
        while position < end {
            try Task.checkCancellation()
            let unit = units[position]
            if unit == quote { return position + 1 }
            if !recipe && unit == 35 { return position }
            if unit == 36 { position = try referenceEnd(at: position, end: end) }
            else if unit == 92 && (!recipe || quote != 39) { position = min(position + 2, end) }
            else { position += 1 }
        }
        return end
    }

    private func referenceEnd(at start: Int, end: Int) throws -> Int {
        guard start + 1 < end else { return end }
        let opening = units[start + 1]
        guard opening == 40 || opening == 123 else { return min(start + 2, end) }
        var closing: [UInt16] = [opening == 40 ? 41 : 125]
        var position = start + 2
        while position < end && !closing.isEmpty {
            try Task.checkCancellation()
            let unit = units[position]
            if unit == 36 && position + 1 < end && (units[position + 1] == 40 || units[position + 1] == 123) {
                closing.append(units[position + 1] == 40 ? 41 : 125)
                position += 2
            } else {
                if (unit == 40 && closing.last == 41) || (unit == 123 && closing.last == 125) { closing.append(closing.last!) }
                else if unit == closing.last { closing.removeLast() }
                position += 1
            }
        }
        return position
    }

    private func logicalEnd(at start: Int) throws -> Int {
        var end = start
        while end < units.count {
            try Task.checkCancellation()
            if units[end] == 10 || units[end] == 13 {
                var backslash = end
                while backslash > start && units[backslash - 1] == 92 { backslash -= 1 }
                if (end - backslash) % 2 == 0 { return end }
                end = nextLine(after: end)
            } else { end += 1 }
        }
        return end
    }

    private func nextLine(after end: Int) -> Int {
        guard end < units.count else { return end }
        return units[end] == 13 && end + 1 < units.count && units[end + 1] == 10 ? end + 2 : end + 1
    }

    private func word(at start: Int, end: Int) -> String {
        var last = start
        while last < end && !isSpace(units[last]) && ![10, 13, 35].contains(units[last]) { last += 1 }
        return String(decoding: units[start..<last], as: UTF16.self)
    }

    private func isDefinition(word: String, end: Int) -> Bool {
        if word == "define" { return true }
        guard word == "override" else { return false }
        var position = index + word.utf16.count
        while position < end && isSpace(units[position]) { position += 1 }
        return self.word(at: position, end: end) == "define"
    }

    private mutating func skipSpace(end: Int) { while index < end && isSpace(units[index]) { index += 1 } }
    private func isSpace(_ unit: UInt16) -> Bool { [9, 11, 12, 32].contains(unit) }
    private func isShellBoundary(_ unit: UInt16) -> Bool { isSpace(unit) || [10, 13, 59, 124, 38, 40, 41].contains(unit) }
    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int, to end: Int) {
        if end > start { tokens.append(SyntaxToken(range: NSRange(location: start, length: end - start), kind: kind)) }
    }

    private static let modifiers: Set<String> = ["override", "export", "unexport", "private"]
    private static let directives: Set<String> = ["define", "endef", "undefine", "ifdef", "ifndef", "ifeq", "ifneq", "else", "endif", "include", "-include", "sinclude", "override", "export", "unexport", "private", "vpath"]
}
