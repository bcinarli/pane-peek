import AppKit
import SwiftUI
import PanePeekCore

struct MarkdownPreviewView: NSViewRepresentable {
    let blocks: [MarkdownBlock]
    @ScaledMetric(relativeTo: .body) private var fontSize = NSFont.preferredFont(forTextStyle: .body, options: [:]).pointSize

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        // Text blocks and tables need TextKit 1 layout.
        let view = NSTextView(usingTextLayoutManager: false)
        view.setAccessibilityLabel("Rendered Markdown preview")
        view.setAccessibilityHelp("Rendered from the Markdown source. Edit shows the source text.")
        return PreviewTextView.scrollView(for: view)
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.blocks != blocks || coordinator.fontSize != fontSize,
              let storage = (scroll.documentView as? NSTextView)?.textStorage else { return }
        storage.setAttributedString(MarkdownText.attributedString(blocks, fontSize: fontSize))
        coordinator.blocks = blocks
        coordinator.fontSize = fontSize
    }

    @MainActor final class Coordinator {
        var blocks: [MarkdownBlock]?
        var fontSize: CGFloat = 0
    }
}

@MainActor enum MarkdownText {
    private static let listIndent: CGFloat = 22
    private static let fill = NSColor.quaternarySystemFill

    static func attributedString(_ blocks: [MarkdownBlock], fontSize: CGFloat) -> NSAttributedString {
        let output = NSMutableAttributedString()
        var fonts = FontCache()
        var quotes: [Int: NSTextBlock] = [:]
        var tables: [Int: NSTextTable] = [:]
        var previousInList = false
        for (index, block) in blocks.enumerated() {
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
                    let quote = quotes[id] ?? opened(quoteBlock(), indent: indent)
                    quotes[id] = quote
                    textBlocks.append(quote)
                    indent = 0
                }
            }
            var font = NSFont.systemFont(ofSize: fontSize)
            switch block.kind {
            case .paragraph: break
            case .heading(let level):
                let scale: CGFloat = switch level { case 1: 1.6; case 2: 1.35; case 3: 1.15; default: 1 }
                font = .systemFont(ofSize: fontSize * scale, weight: .semibold)
                if index > 0 { spacing += 6 }
            case .code:
                font = fonts.code(fontSize)
                textBlocks.append(opened(codeBlock(), indent: indent))
                indent = 0
            case .thematicBreak:
                font = .systemFont(ofSize: 2)
                textBlocks.append(opened(ruleBlock(), indent: indent))
                indent = 0
            case .tableCell(let id, let row, let column, let columns):
                let table = tables[id] ?? opened(textTable(columns), indent: indent)
                tables[id] = table
                textBlocks.append(cellBlock(table, row: row, column: column))
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
            let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: rest]
            let piece = NSMutableAttributedString()
            if let marker = block.marker {
                piece.append(NSAttributedString(string: marker + "\t", attributes: base.merging([.font: NSFont.systemFont(ofSize: fontSize)]) { $1 }))
            }
            let contentStart = piece.length
            for run in block.content.runs {
                var attributes = base
                let intent = run.inlinePresentationIntent ?? []
                let code = intent.contains(.code) || intent.contains(.inlineHTML)
                if code { attributes[.backgroundColor] = fill }
                var traits: NSFontDescriptor.SymbolicTraits = []
                if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if intent.contains(.emphasized) { traits.insert(.italic) }
                attributes[.font] = fonts.styled(code ? fonts.code(font.pointSize) : font, traits)
                if intent.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                // Images are never loaded; their description links to the source.
                if let url = run.link ?? run.imageURL { attributes[.link] = url }
                piece.append(NSAttributedString(string: String(block.content[run.range].characters), attributes: attributes))
            }
            let contentLength = piece.length - contentStart
            for token in block.tokens where token.range.location >= 0 && NSMaxRange(token.range) <= contentLength {
                piece.addAttribute(.foregroundColor, value: PreviewColours.colour(for: token.kind),
                                   range: NSRange(location: contentStart + token.range.location, length: token.range.length))
            }
            piece.append(NSAttributedString(string: "\n", attributes: base))
            piece.addAttribute(.paragraphStyle, value: first, range: (piece.string as NSString).paragraphRange(for: NSRange()))
            output.append(piece)
        }
        // An empty final block, such as a rule, keeps its newline as the character that displays it.
        if output.length > 0, blocks.last?.content.characters.isEmpty == false { output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1)) }
        return output
    }

    /// Reuses derived fonts within one rendering instead of looking them up per run.
    @MainActor private struct FontCache {
        private var code: [CGFloat: NSFont] = [:]
        private var styled: [NSFont: [UInt32: NSFont]] = [:]

        mutating func code(_ size: CGFloat) -> NSFont {
            if let font = code[size] { return font }
            let font = PreviewFonts.monospaced(size: size * 0.92)
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

    private static func quoteBlock() -> NSTextBlock {
        let block = NSTextBlock()
        block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        block.setBorderColor(.secondaryLabelColor, for: .minX)
        block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .minX)
        return block
    }

    private static func codeBlock() -> NSTextBlock {
        let block = FilledTextBlock()
        block.fill = fill
        block.setWidth(8, type: .absoluteValueType, for: .padding)
        return block
    }

    private static func ruleBlock() -> NSTextBlock {
        let block = NSTextBlock()
        block.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
        block.setBorderColor(.separatorColor, for: .maxY)
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

    private static func cellBlock(_ table: NSTextTable, row: Int, column: Int) -> NSTextTableBlock {
        let cell = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: column, columnSpan: 1)
        cell.setWidth(1, type: .absoluteValueType, for: .border)
        cell.setBorderColor(.separatorColor)
        cell.setWidth(5, type: .absoluteValueType, for: .padding)
        if row == 0 { cell.backgroundColor = fill }
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
