import AppKit
import SwiftUI
import PanePeekCore

struct MarkdownPreviewView: NSViewRepresentable {
    let text: NSAttributedString
    let documentID: UUID

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        // Text blocks and tables need TextKit 1 layout.
        let view = NSTextView(usingTextLayoutManager: false)
        view.delegate = context.coordinator
        view.setAccessibilityLabel("Rendered Markdown preview")
        view.setAccessibilityHelp("Rendered from the Markdown source. Images are shown as text. Only web links can be opened.")
        return PreviewTextView.scrollView(for: view)
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let view = scroll.documentView as? NSTextView, let storage = view.textStorage else { return }
        let changedDocument = coordinator.documentID != documentID
        guard changedDocument || coordinator.text !== text else { return }
        if changedDocument { view.hideFindBar() }
        storage.setAttributedString(text)
        coordinator.documentID = documentID
        coordinator.text = text
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        (scroll.documentView as? NSTextView)?.hideFindBar()
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var text: NSAttributedString?
        var documentID: UUID?
        var openLink: (URL) -> Void = { NSWorkspace.shared.open($0) }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:))
            if let url, MarkdownText.isWebLink(url) { openLink(url) }
            // Always consume the event so AppKit cannot choose another handler.
            return true
        }
    }
}

enum MarkdownText {
    private static let listIndent: CGFloat = 22

    @MainActor static var defaultFontSize: CGFloat {
        NSFont.preferredFont(forTextStyle: .body, options: [:]).pointSize
    }

    struct Style: Sendable {
        let fontSize: CGFloat
        let textColour: NSColor
        let fill: NSColor
        let quoteBorder: NSColor
        let separator: NSColor
        let tokenColours: [SyntaxToken.Kind: NSColor]
        let codeFontNames: [CGFloat: String]

        @MainActor init(fontSize: CGFloat) {
            self.fontSize = fontSize
            textColour = .textColor
            fill = .quaternarySystemFill
            quoteBorder = .secondaryLabelColor
            separator = .separatorColor
            tokenColours = Dictionary(uniqueKeysWithValues: SyntaxToken.Kind.allCases.map { ($0, PreviewColours.colour(for: $0)) })
            let code = PreviewFonts.monospaced(size: fontSize * 0.92)
            var names = [fontSize: code.fontName]
            let sizes = (1...3).map { fontSize * MarkdownText.headingScale($0) } + [code.pointSize, 2]
            for size in sizes where names[size] == nil {
                names[size] = PreviewFonts.monospaced(size: size * 0.92).fontName
            }
            codeFontNames = names
        }
    }

    private static func headingScale(_ level: Int) -> CGFloat {
        switch level { case 1: 1.6; case 2: 1.35; case 3: 1.15; default: 1 }
    }

    static func isWebLink(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "") && !(url.host ?? "").isEmpty
    }

    @concurrent static func attributedString(_ blocks: [MarkdownBlock], style: Style) async throws -> sending NSAttributedString {
        let fontSize = style.fontSize
        let output = NSMutableAttributedString()
        var fonts = FontCache()
        var quotes: [Int: NSTextBlock] = [:]
        var tables: [Int: NSTextTable] = [:]
        var previousInList = false
        for (index, block) in blocks.enumerated() {
            try Task.checkCancellation()
            let inList = block.containers.contains { if case .listItem = $0 { true } else { false } }
            var spacing: CGFloat = index == 0 ? 0 : (inList && previousInList ? 4 : 10)
            previousInList = inList
            // A newly opened block takes the gap as its outer margin so borders and fills start at the content.
            func opened<Block: NSTextBlock>(_ textBlock: Block, indent: CGFloat) -> Block {
                if !(textBlock is NSTextTable) { textBlock.setContentWidth(100, type: .percentageValueType) }
                textBlock.setWidth(indent, type: .absoluteValueType, for: .margin, edge: .minX)
                textBlock.setWidth(spacing, type: .absoluteValueType, for: .margin, edge: .minY)
                spacing = 0
                return textBlock
            }
            var indent: CGFloat = 0
            var textBlocks: [NSTextBlock] = []
            for container in block.containers {
                switch container {
                case .listItem: indent += listIndent
                case .quote(let id):
                    let quote = quotes[id] ?? opened(quoteBlock(border: style.quoteBorder), indent: indent)
                    quotes[id] = quote
                    textBlocks.append(quote)
                    indent = 0
                }
            }
            var font = NSFont.systemFont(ofSize: fontSize)
            switch block.kind {
            case .paragraph: break
            case .heading(let level):
                font = .systemFont(ofSize: fontSize * headingScale(level), weight: .semibold)
                if index > 0 { spacing += 6 }
            case .code:
                font = fonts.code(fontSize, using: style)
                textBlocks.append(opened(codeBlock(fill: style.fill), indent: indent))
                indent = 0
            case .thematicBreak:
                font = .systemFont(ofSize: 2)
                textBlocks.append(opened(ruleBlock(border: style.separator), indent: indent))
                indent = 0
            case .tableCell(let id, let row, let column, let columns):
                let table = tables[id] ?? opened(textTable(columns), indent: indent)
                tables[id] = table
                textBlocks.append(cellBlock(table, row: row, column: column, style: style))
                indent = 0
                spacing = 0
                if row == 0 { font = .systemFont(ofSize: fontSize, weight: .semibold) }
            }
            let first = NSMutableParagraphStyle()
            first.textBlocks = textBlocks
            first.headIndent = indent
            first.firstLineHeadIndent = indent
            first.lineSpacing = block.kind == .code ? 0 : 2
            let rest = first.copy() as! NSParagraphStyle
            first.paragraphSpacingBefore = spacing
            if block.marker != nil {
                first.firstLineHeadIndent = indent - listIndent
                first.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
            }
            // Quotes and markers keep full text contrast; borders and indentation convey structure.
            let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: style.textColour, .paragraphStyle: rest]
            let piece = NSMutableAttributedString()
            if let marker = block.marker {
                piece.append(NSAttributedString(string: marker + "\t", attributes: base.merging([.font: NSFont.systemFont(ofSize: fontSize)]) { $1 }))
            }
            let contentStart = piece.length
            for run in block.content.runs {
                try Task.checkCancellation()
                var attributes = base
                let intent = run.inlinePresentationIntent ?? []
                let code = intent.contains(.code) || intent.contains(.inlineHTML)
                if code { attributes[.backgroundColor] = style.fill }
                var traits: NSFontDescriptor.SymbolicTraits = []
                if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if intent.contains(.emphasized) { traits.insert(.italic) }
                let runFont = code ? fonts.code(font.pointSize, using: style) : font
                attributes[.font] = fonts.styled(runFont, traits)
                if intent.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                // Images remain text and follow the same link policy.
                if let url = run.link ?? run.imageURL, isWebLink(url) { attributes[.link] = url }
                piece.append(NSAttributedString(string: String(block.content[run.range].characters), attributes: attributes))
            }
            let contentLength = piece.length - contentStart
            for token in block.tokens where token.range.location >= 0 && NSMaxRange(token.range) <= contentLength {
                try Task.checkCancellation()
                guard let colour = style.tokenColours[token.kind] else { continue }
                piece.addAttribute(.foregroundColor, value: colour,
                                   range: NSRange(location: contentStart + token.range.location, length: token.range.length))
            }
            piece.append(NSAttributedString(string: "\n", attributes: base))
            piece.addAttribute(.paragraphStyle, value: first, range: (piece.string as NSString).paragraphRange(for: NSRange()))
            output.append(piece)
        }
        // An empty final block, such as a rule, keeps its newline as the character that displays it.
        if output.length > 0, blocks.last?.content.characters.isEmpty == false { output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1)) }
        return NSAttributedString(attributedString: output)
    }

    /// Reuses derived fonts within one rendering instead of looking them up per run.
    private struct FontCache {
        private var code: [CGFloat: NSFont] = [:]
        private var styled: [NSFont: [UInt32: NSFont]] = [:]

        mutating func code(_ size: CGFloat, using style: Style) -> NSFont {
            if let cached = code[size] { return cached }
            let pointSize = size * 0.92
            let font = style.codeFontNames[size].flatMap { NSFont(name: $0, size: pointSize) }
                ?? .monospacedSystemFont(ofSize: pointSize, weight: .regular)
            code[size] = font
            return font
        }

        mutating func styled(_ font: NSFont, _ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
            guard !traits.isEmpty else { return font }
            if let cached = styled[font]?[traits.rawValue] { return cached }
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
            let derived = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
            styled[font, default: [:]][traits.rawValue] = derived
            return derived
        }
    }

    private static func quoteBlock(border: NSColor) -> NSTextBlock {
        let block = NSTextBlock()
        block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        block.setBorderColor(border, for: .minX)
        block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .minX)
        return block
    }

    private static func codeBlock(fill: NSColor) -> NSTextBlock {
        let block = FilledTextBlock()
        block.fill = fill
        block.setWidth(8, type: .absoluteValueType, for: .padding)
        return block
    }

    private static func ruleBlock(border: NSColor) -> NSTextBlock {
        let block = NSTextBlock()
        block.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
        block.setBorderColor(border, for: .maxY)
        block.setWidth(4, type: .absoluteValueType, for: .margin, edge: .maxY)
        return block
    }

    private static func textTable(_ columns: Int) -> NSTextTable {
        let table = NSTextTable()
        table.numberOfColumns = columns
        table.collapsesBorders = true
        table.hidesEmptyCells = false
        return table
    }

    private static func cellBlock(_ table: NSTextTable, row: Int, column: Int, style: Style) -> NSTextTableBlock {
        let cell = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: column, columnSpan: 1)
        cell.setWidth(1, type: .absoluteValueType, for: .border)
        cell.setBorderColor(style.separator)
        cell.setWidth(5, type: .absoluteValueType, for: .padding)
        if row == 0 { cell.backgroundColor = style.fill }
        return cell
    }
}

/// TextKit 1 paints a block's background across its margins; fill only the bordered area.
private final class FilledTextBlock: NSTextBlock {
    var fill: NSColor?

    override func drawBackground(withFrame frameRect: NSRect, in controlView: NSView?, characterRange: NSRange, layoutManager: NSLayoutManager) {
        if let fill {
            let left = width(for: .margin, edge: .minX), top = width(for: .margin, edge: .minY)
            fill.setFill()
            NSRect(x: frameRect.minX + left, y: frameRect.minY + top,
                   width: frameRect.width - left - width(for: .margin, edge: .maxX),
                   height: frameRect.height - top - width(for: .margin, edge: .maxY)).fill()
        }
        if let controlView {
            super.drawBackground(withFrame: frameRect, in: controlView, characterRange: characterRange, layoutManager: layoutManager)
        }
    }
}
