import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct MarkdownPreviewTests {
    @Test func frontMatterUsesYAMLColoursAndCodePresentationWithoutLinks() async throws {
        let yaml = "---\ntitle: \"**literal** [link](https://example.com)\"\nenabled: true\n---"
        let blocks = try await MarkdownRendering.blocks(in: yaml + "\n\n# Body")
        let text = MarkdownText.attributedString(blocks, fontSize: 13)
        #expect(text.string == yaml + "\nBody")
        let key = (text.string as NSString).range(of: "title")
        try #require(key.location != NSNotFound)
        #expect(text.attribute(.foregroundColor, at: key.location, effectiveRange: nil) as? NSColor == PreviewColours.keyword)
        let style = try #require(text.attribute(.paragraphStyle, at: key.location, effectiveRange: nil) as? NSParagraphStyle)
        #expect(style.textBlocks.first?.width(for: .padding, edge: .minX) ?? 0 > 0)
        let link = (text.string as NSString).range(of: "link")
        #expect(text.attribute(.link, at: link.location, effectiveRange: nil) == nil)
        let body = (text.string as NSString).range(of: "Body")
        let font = try #require(text.attribute(.font, at: body.location, effectiveRange: nil) as? NSFont)
        #expect(font.pointSize > 13)
    }

    @Test func renderedTextStylesBlocksWithoutMarkdownSyntax() async throws {
        let blocks = try await MarkdownRendering.blocks(in: """
        # Title

        Some **bold** and [link](https://example.com)

        - item

        > quote

        ```swift
        let x
        ```

        | A | B |
        |---|---|
        | 1 | 2 |
        """)
        let text = MarkdownText.attributedString(blocks, fontSize: 13)
        #expect(text.string == "Title\nSome bold and link\n•\titem\nquote\nlet x\nA\nB\n1\n2")
        func attribute<Value>(_ key: NSAttributedString.Key, _ substring: String) throws -> Value? {
            let range = (text.string as NSString).range(of: substring)
            try #require(range.location != NSNotFound)
            return text.attribute(key, at: range.location, effectiveRange: nil) as? Value
        }
        let title: NSFont = try #require(try attribute(.font, "Title"))
        let bold: NSFont = try #require(try attribute(.font, "bold"))
        #expect(title.pointSize > 13 && bold.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(try attribute(.link, "link") == URL(string: "https://example.com"))
        let item: NSParagraphStyle = try #require(try attribute(.paragraphStyle, "item"))
        #expect(item.headIndent > 0 && item.firstLineHeadIndent < item.headIndent)
        let quote: NSParagraphStyle = try #require(try attribute(.paragraphStyle, "quote"))
        #expect(quote.textBlocks.count == 1 && quote.textBlocks[0].width(for: .border, edge: .minX) > 0)
        let code: NSParagraphStyle = try #require(try attribute(.paragraphStyle, "let x"))
        #expect(code.textBlocks.first?.width(for: .padding, edge: .minX) ?? 0 > 0)
        #expect(try attribute(.foregroundColor, "let") as NSColor? != NSColor.textColor)
        let cells = try ["A", "B", "1", "2"].map { cell -> NSTextTableBlock in
            let style: NSParagraphStyle = try #require(try attribute(.paragraphStyle, cell))
            return try #require(style.textBlocks.last as? NSTextTableBlock)
        }
        #expect(cells.map { [$0.startingRow, $0.startingColumn] } == [[0, 0], [0, 1], [1, 0], [1, 1]])
        #expect(Set(cells.map { ObjectIdentifier($0.table) }).count == 1)
    }

    @Test func aFinalThematicBreakKeepsItsRule() async throws {
        for source in ["---", "paragraph\n\n---"] {
            let text = MarkdownText.attributedString(try await MarkdownRendering.blocks(in: source), fontSize: 13)
            try #require(text.length > 0)
            let rule = text.attribute(.paragraphStyle, at: text.length - 1, effectiveRange: nil) as? NSParagraphStyle
            #expect(rule?.textBlocks.count == 1)
        }
    }
}
