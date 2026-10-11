import Foundation

enum DockerfileHighlighting {
    static func tokens(in text: String) throws -> [SyntaxToken] {
        var scanner = DockerfileScanner(text: text)
        return try scanner.scan()
    }
}

private struct DockerfileScanner {
    let units: [UInt16]
    var index = 0
    var tokens: [SyntaxToken] = []
    var escape: UInt16 = 92
    var directives = true
    var seenDirectives: Set<String> = []
    var instruction = ""
    var quote: UInt16?
    private var heredocs: [Heredoc] = []
    var argumentsStarted = false
    var json = false

    init(text: String) { units = Array(text.utf16) }

    mutating func scan() throws -> [SyntaxToken] {
        var continued = false
        while index < units.count {
            try Task.checkCancellation()
            let end = try lineEnd(at: index)
            while index < end && isSpace(units[index]) { index += 1 }
            if index < end && units[index] == 35 {
                if directives { try readDirective(end: end) }
                append(.comment, from: index, to: end)
            } else if index == end {
                directives = false
            } else {
                directives = false
                if !continued {
                    instruction = try readInstruction(end: end)
                    argumentsStarted = false
                    json = false
                }
                var last = end
                while last > index && isSpace(units[last - 1]) { last -= 1 }
                continued = last > index && units[last - 1] == escape && (last - 1 == index || units[last - 2] != escape)
                if !instruction.isEmpty { try readArguments(end: end) }
                if !continued { quote = nil }
            }
            index = nextLine(after: end)
            if !continued && !heredocs.isEmpty {
                for heredoc in heredocs { try readHeredoc(heredoc) }
                heredocs.removeAll(keepingCapacity: true)
            }
        }
        try Task.checkCancellation()
        return tokens
    }

    private mutating func readDirective(end: Int) throws {
        let text = String(decoding: units[index + 1..<end], as: UTF16.self)
        let parts = text.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { directives = false; return }
        let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        guard ["syntax", "escape", "check"].contains(key), !seenDirectives.contains(key) else { directives = false; return }
        seenDirectives.insert(key)
        if key == "escape" {
            guard value == "\\" || value == "`" else { directives = false; return }
            escape = value == "`" ? 96 : 92
        }
        try Task.checkCancellation()
    }

    private mutating func readInstruction(end: Int) throws -> String {
        let start = index
        var ascii = true
        while index < end && !isSpace(units[index]) {
            try Task.checkCancellation()
            ascii = ascii && units[index] < 128
            index += 1
        }
        guard ascii else { return "" }
        let word = String(decoding: units[start..<index], as: UTF16.self).uppercased()
        guard Self.instructions.contains(word) else { return "" }
        append(.keyword, from: start, to: index)
        return word
    }

    private mutating func readArguments(end: Int) throws {
        while index < end {
            try Task.checkCancellation()
            if quote != nil || units[index] == 34 || units[index] == 39 {
                let start = index
                if quote == nil { quote = units[index]; index += 1 }
                while index < end {
                    try Task.checkCancellation()
                    let unit = units[index]
                    index += 1
                    if unit == quote { quote = nil; break }
                    if unit == valueEscape && quote == 34 && index < end { index += 1 }
                }
                append(.string, from: start, to: index)
                argumentsStarted = true
            } else if isSpace(units[index]) {
                index += 1
            } else if instruction == "ONBUILD" && !argumentsStarted {
                instruction = try readInstruction(end: end)
            } else {
                if !argumentsStarted { json = units[index] == 91; argumentsStarted = true }
                if units[index] == valueEscape {
                    index = min(index + 2, end)
                } else if units[index] == 36 {
                    try readParameter(end: end)
                } else if !json && ["RUN", "COPY", "ADD"].contains(instruction) && index + 1 < end && units[index] == 60 && units[index + 1] == 60 {
                    try readHeredocOpening(end: end)
                } else {
                    index += 1
                }
            }
        }
    }

    private mutating func readParameter(end: Int) throws {
        let start = index
        index += 1
        if index < end && units[index] == 123 {
            var quotes: [UInt16?] = [nil]
            index += 1
            while index < end && !quotes.isEmpty {
                try Task.checkCancellation()
                let unit = units[index]
                let quoted = quotes[quotes.count - 1]
                if unit == valueEscape && quoted != 39 { index = min(index + 2, end); continue }
                if quoted != 39 && unit == 36 && index + 1 < end && units[index + 1] == 123 {
                    quotes.append(nil)
                    index += 2
                    continue
                }
                if unit == quoted { quotes[quotes.count - 1] = nil }
                else if quoted == nil && (unit == 34 || unit == 39) { quotes[quotes.count - 1] = unit }
                else if quoted == nil && unit == 123 { quotes.append(nil) }
                else if quoted == nil && unit == 125 { quotes.removeLast() }
                index += 1
            }
        } else if index < end && isNameStart(units[index]) {
            index += 1
            while index < end && (isNameStart(units[index]) || (48...57).contains(units[index])) {
                try Task.checkCancellation()
                index += 1
            }
        } else {
            if index < end && (units[index] == 36 || (48...57).contains(units[index])) { index += 1 }
            return
        }
        append(.reference, from: start, to: index)
    }

    private struct Heredoc {
        let label: [UInt16]
        let stripTabs: Bool
    }

    private mutating func readHeredocOpening(end: Int) throws {
        index += 2
        let stripTabs = index < end && units[index] == 45
        if stripTabs { index += 1 }
        if index < end && units[index] == 60 { index += 1; return }
        while index < end && isSpace(units[index]) { index += 1 }
        let start = index
        var label: [UInt16] = []
        var quoted: UInt16?
        while index < end {
            try Task.checkCancellation()
            let unit = units[index]
            if quoted == nil && (isSpace(unit) || [59, 38, 124, 60, 62, 40, 41].contains(unit)) { break }
            index += 1
            if unit == quoted { quoted = nil }
            else if quoted == nil && (unit == 34 || unit == 39) { quoted = unit }
            else if unit == 92 && quoted != 39 && index < end { label.append(units[index]); index += 1 }
            else { label.append(unit) }
        }
        if index > start { append(.string, from: start, to: index) }
        if index > start && quoted == nil { heredocs.append(Heredoc(label: label, stripTabs: stripTabs)) }
    }

    private mutating func readHeredoc(_ heredoc: Heredoc) throws {
        let start = index
        while index < units.count {
            let end = try lineEnd(at: index)
            var labelStart = index
            if heredoc.stripTabs {
                while labelStart < end && units[labelStart] == 9 { labelStart += 1 }
            }
            let closes = end - labelStart == heredoc.label.count && units[labelStart..<end].elementsEqual(heredoc.label)
            index = nextLine(after: end)
            if closes { append(.string, from: start, to: end); return }
        }
        if index > start { append(.string, from: start, to: index) }
    }

    private func lineEnd(at start: Int) throws -> Int {
        var end = start
        while end < units.count && units[end] != 10 && units[end] != 13 {
            try Task.checkCancellation()
            end += 1
        }
        return end
    }

    private func nextLine(after end: Int) -> Int {
        guard end < units.count else { return end }
        return units[end] == 13 && end + 1 < units.count && units[end + 1] == 10 ? end + 2 : end + 1
    }

    private mutating func append(_ kind: SyntaxToken.Kind, from start: Int, to end: Int) {
        if end > start { tokens.append(SyntaxToken(range: NSRange(location: start, length: end - start), kind: kind)) }
    }

    private func isSpace(_ unit: UInt16) -> Bool { [9, 11, 12, 32].contains(unit) }
    private var valueEscape: UInt16 { json || instruction == "RUN" ? 92 : escape }
    private func isNameStart(_ unit: UInt16) -> Bool { (65...90).contains(unit) || (97...122).contains(unit) || unit == 95 }
    private static let instructions: Set<String> = [
        "ADD", "ARG", "CMD", "COPY", "ENTRYPOINT", "ENV", "EXPOSE", "FROM", "HEALTHCHECK", "LABEL",
        "MAINTAINER", "ONBUILD", "RUN", "SHELL", "STOPSIGNAL", "USER", "VOLUME", "WORKDIR"
    ]
}
