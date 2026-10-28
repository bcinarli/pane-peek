import AppKit
import SwiftUI
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct MarkdownPreviewTests {
    @Test func renderedFindUsesVisibleTextAndKeepsItsBarOwnership() async throws {
        _ = NSApplication.shared
        let blocks = try await MarkdownRendering.blocks(in: "# Visible **needle**\n\n[Label](https://example.invalid/markup-only)")
        let host = NSHostingView(rootView: MarkdownPreviewView(blocks: blocks))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        func textView(in view: NSView) -> NSTextView? {
            (view as? NSTextView) ?? view.subviews.lazy.compactMap { textView(in: $0) }.first
        }
        let view = try #require(textView(in: host))
        defer { view.hideFindBar(); window.orderOut(nil) }
        try #require(view.usesFindBar)
        let browser = BrowserState()
        let find = BrowserFind()
        find.window = window
        find.browser = browser
        window.makeFirstResponder(view)
        let request = find.folderRequest
        find.find(in: window)
        let scroll = try #require(view.enclosingScrollView)
        #expect(scroll.isFindBarVisible && !view.isEditable)
        #expect(view.string == "Visible needle\nLabel")
        #expect(!view.string.contains("markup-only") && !view.string.contains("**"))
        find.find(in: window)
        #expect(scroll.isFindBarVisible && find.folderRequest == request)
        window.orderOut(nil)
    }

    @Test(arguments: [
        ("https://example.com/document?q=1#section", true),
        ("http://example.com/image.png", true),
        ("HTTPS://example.com/document", true),
        ("notes/document.md", false),
        ("file:///documents/document.md", false),
        ("sample-app://document", false),
        ("mailto:reader@example.com", false),
        ("javascript:void(0)", false),
        ("data:text/plain,document", false),
        ("#section", false),
        ("//example.com/document", false),
        ("https:document", false),
        ("https:///document", false)
    ], ["", "!"])
    func onlyWebTargetsBecomeLinks(target: (String, Bool), prefix: String) async throws {
        let blocks = try await MarkdownRendering.blocks(in: "\(prefix)[Description](\(target.0))",
                                                       baseURL: URL(fileURLWithPath: "/documents/", isDirectory: true))
        let text = MarkdownText.attributedString(blocks, fontSize: 13)
        #expect(text.string == "Description")
        let link = text.attribute(.link, at: 0, effectiveRange: nil) as? URL
        #expect(link == (target.1 ? URL(string: target.0) : nil))
        #expect(text.attribute(.attachment, at: 0, effectiveRange: nil) == nil)
    }

    @Test func nativeLinkActivationUsesThePolicyAndConsumesOtherTargets() async throws {
        _ = NSApplication.shared
        let blocks = try await MarkdownRendering.blocks(in: "[Web](https://example.com) [Local](notes.md)")
        let host = NSHostingView(rootView: MarkdownPreviewView(blocks: blocks))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        func textView(in view: NSView) -> NSTextView? {
            (view as? NSTextView) ?? view.subviews.lazy.compactMap { textView(in: $0) }.first
        }
        let view = try #require(textView(in: host))
        let coordinator = try #require(view.delegate as? MarkdownPreviewView.Coordinator)
        var opened: [URL] = []
        coordinator.openLink = { opened.append($0) }
        #expect(!view.isEditable && view.isSelectable && opened.isEmpty)
        let web = try #require(view.textStorage?.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        view.clicked(onLink: web, at: 0)
        view.clicked(onLink: "HTTP://example.com/second", at: 0)
        #expect(opened == [web, URL(string: "HTTP://example.com/second")!])
        for target: Any in [URL(fileURLWithPath: "/documents/notes.md"), "sample-app://document",
                            "https:document", "https:///document", 42] {
            #expect(coordinator.textView(view, clickedOnLink: target, at: 0))
        }
        #expect(opened.count == 2)
        #expect(view.string == "Web Local")
        view.setSelectedRange(NSRange(location: 0, length: view.string.utf16.count))
        #expect(view.selectedRange().length == 9)
    }

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
