import Foundation

/// A rendered Markdown block whose inline content keeps Foundation's emphasis, code and link runs.
public struct MarkdownBlock: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case paragraph, code, thematicBreak
        case heading(level: Int)
        case tableCell(table: Int, row: Int, column: Int, columns: Int)
    }

    /// Enclosing quotes and list items, outermost first, identified by their parse identity.
    public enum Container: Sendable, Equatable { case quote(Int), listItem(Int) }

    public let kind: Kind
    public let content: AttributedString
    public let containers: [Container]
    /// Shown before the first block of each list item.
    public let marker: String?
    /// Lexical colours for fenced code in a supported language.
    public let tokens: [SyntaxToken]
}

public enum MarkdownRendering {
    private static let languageExtensions = ["javascript": "js", "typescript": "ts", "python": "py", "shell": "sh", "rust": "rs",
                                             "csharp": "cs", "c#": "cs", "markdown": "md", "golang": "go", "docker": "dockerfile", "make": "makefile"]
    /// Foundation drops table cells without text, so empty cells carry this placeholder through parsing.
    private static let emptyCell: Character = "\u{200B}"
    private static let taskMarkers = [(prefix: "[ ] ", box: "☐"), (prefix: "[x] ", box: "☑"), (prefix: "[X] ", box: "☑")]

    public static func isMarkdown(_ fileName: String) -> Bool {
        (fileName as NSString).pathExtension.lowercased() == "md"
    }

    /// Parse off the UI thread; images and HTML are shown as text and never fetched or executed.
    public static func blocks(in text: String, baseURL: URL? = nil) async throws -> [MarkdownBlock] {
        let worker = Task.detached(priority: .userInitiated) {
            let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
            let document = try AttributedString(markdown: fillingEmptyTableCells(text), options: options, baseURL: baseURL)
            var blocks: [MarkdownBlock] = []
            var markedItems = Set<Int>()
            for (intent, range) in document.runs[\.presentationIntent] {
                try Task.checkCancellation()
                let components = intent?.components ?? []
                var content = AttributedString(document[range])
                var marker: String?
                if let index = components.firstIndex(where: { if case .listItem = $0.kind { true } else { false } }),
                   markedItems.insert(components[index].identity).inserted {
                    marker = listMarker(components, item: index)
                    if let task = taskMarkers.first(where: { content.characters.starts(with: $0.prefix) }) {
                        content.removeSubrange(content.startIndex..<content.characters.index(content.startIndex, offsetBy: task.prefix.count))
                        marker = task.box
                    }
                }
                var kind = MarkdownBlock.Kind.paragraph
                var language: String?
                switch components.first?.kind {
                case .header(let level)?: kind = .heading(level: level)
                case .thematicBreak?: kind = .thematicBreak; content = AttributedString()
                case .tableCell(let column)?:
                    kind = tableCell(components, column: column)
                    if content.characters.elementsEqual([emptyCell]) { content = AttributedString() }
                case .codeBlock(let hint)?: kind = .code; language = hint?.split(separator: " ").first?.lowercased()
                // Raw HTML blocks have no presentation intent.
                case nil: kind = .code
                default: break
                }
                if kind == .code, content.characters.last == "\n" { content.characters.removeLast() }
                var tokens: [SyntaxToken] = []
                if let language {
                    tokens = try await SyntaxHighlighting.tokens(in: String(content.characters), fileExtension: languageExtensions[language] ?? language)
                }
                let containers = components.reversed().compactMap { component -> MarkdownBlock.Container? in
                    switch component.kind {
                    case .blockQuote: .quote(component.identity)
                    case .listItem: .listItem(component.identity)
                    default: nil
                    }
                }
                blocks.append(MarkdownBlock(kind: kind, content: content, containers: containers, marker: marker, tokens: tokens))
            }
            return blocks
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func fillingEmptyTableCells(_ text: String) -> String {
        let delimiterRow = /^[ >]*\|?[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var fence: Substring?
        var inTable = false
        for index in lines.indices {
            let line = lines[index]
            let trimmed = line.drop { $0 == " " }
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if let marker = trimmed.prefixMatch(of: /`{3,}|~{3,}/) {
                fence = marker.output
                inTable = false
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { inTable = false; continue }
            let isDelimiter = line.contains("|") && line.wholeMatch(of: delimiterRow) != nil
            if isDelimiter, index > 0, lines[index - 1].contains("|") {
                inTable = true
                fillEmptyCells(&lines[index - 1])
            } else if inTable {
                fillEmptyCells(&lines[index])
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func fillEmptyCells(_ row: inout String) {
        // Repeated so adjacent empty cells can share their dividing pipe; escaped pipes are not dividers.
        for _ in 0..<2 {
            row.replace(/(^|[^\\])\|([ \t]*)(?=\|)/) { "\($0.output.1)|\($0.output.2)\(emptyCell)" }
        }
    }

    private static func listMarker(_ components: [PresentationIntent.IntentType], item index: Int) -> String {
        guard case .listItem(let ordinal) = components[index].kind else { return "•" }
        if index + 1 < components.count, case .orderedList = components[index + 1].kind { return "\(ordinal)." }
        let depth = components.count(where: { if case .listItem = $0.kind { true } else { false } })
        return ["•", "◦", "▪"][(depth - 1) % 3]
    }

    private static func tableCell(_ components: [PresentationIntent.IntentType], column: Int) -> MarkdownBlock.Kind {
        var row = 0, table = 0, columns = 0
        for component in components {
            switch component.kind {
            case .tableRow(let index): row = index
            case .table(let definitions): table = component.identity; columns = definitions.count
            default: break
            }
        }
        return .tableCell(table: table, row: row, column: column, columns: columns)
    }
}
