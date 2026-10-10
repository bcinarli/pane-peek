import Foundation
import Testing
@testable import PanePeekCore

struct MarkdownHighlightingTests {
    @Test func headingsRespectMarkersIndentationAndParagraphBoundaries() async throws {
        let text = "# Title 👀\r\n   ###### Small\n#\n#hashtag\n####### plain\n\\# escaped\n\nSetext title\n===\n\nSecond\n---\n\n---\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "MD")
        #expect(markdownParts(.section, tokens, text) == ["# Title 👀", "###### Small", "#", "Setext title\n===", "Second\n---"])
        markdownRanges(tokens, text)
    }

    @Test func emphasisHandlesNestedRunsEscapesAndIntrawordUnderscores() async throws {
        let text = #"*italic* _other_ **bold** __strong__ ***both*** *outer **inner** end* foo*bar*baz foo_bar_baz \*plain\* * spaced *"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "md")
        #expect(markdownParts(.keyword, tokens, text) == ["*italic*", "_other_", "**bold**", "__strong__", "***both***", "*outer **inner** end*", "*bar*"])
        markdownRanges(tokens, text)
    }

    @Test func codeSpansMatchExactRunsAndProtectInnerSyntax() async throws {
        let spans = ["`*plain* [link](url) 👀`", "``one ` two``", "`line\r\nnext`", #"`escaped\`"#]
        let text = spans.joined(separator: " and ") + " and `unclosed **bold**"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "md")
        #expect(markdownParts(.string, tokens, text) == spans)
        #expect(markdownParts(.keyword, tokens, text) == ["**bold**"])
        #expect(markdownParts(.reference, tokens, text).isEmpty)
        markdownRanges(tokens, text)
    }

    @Test func fencesRequireMatchingMarkersAndProtectAllBodyLines() async throws {
        let first = "````swift\r\n# fake **bold**\r\n```\r\n~~~~\r\n`````"
        let second = "  ~~~ text\n[link](url) `code`\n  ~~~"
        let incomplete = "```\n# still code 👀"
        let text = first + "\n# Heading\n" + second + "\n" + incomplete
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "md")
        #expect(markdownParts(.string, tokens, text) == [first, String(second.dropFirst(2)), incomplete])
        #expect(markdownParts(.section, tokens, text) == ["# Heading"])
        #expect(markdownParts(.keyword, tokens, text).isEmpty)
        #expect(markdownParts(.reference, tokens, text).isEmpty)
        markdownRanges(tokens, text)
    }

    @Test func linksImagesAndAutolinksKeepBalancedEscapedAndQuotedDestinations() async throws {
        let links = [#"[site 👀](https://example.test/a(b(c)) "title )")"#, #"![image](<image file.png> 'title')"#, #"[a \] b](path\(x\))"#, "[text][id]", "<https://example.test/path>", "<hello@example.test>"]
        let text = links.joined(separator: " and ") + #" and [plain] [bad](unterminated \[escaped](url) <div>"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "md")
        #expect(markdownParts(.reference, tokens, text) == links)
        markdownRanges(tokens, text)
    }

    @Test func nestedCodeKeepsItsColourWithoutCrossingBlankOrBlockBoundaries() async throws {
        let text = "# Heading `code`\n\n*emphasis `*literal*` and [link](url)*\n\n*unfinished\n\nend*\n# Other\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "md")
        #expect(markdownParts(.string, tokens, text) == ["`code`", "`*literal*`"])
        #expect(markdownParts(.reference, tokens, text) == ["[link](url)"])
        #expect(markdownParts(.keyword, tokens, text) == ["*emphasis ", " and ", "*"])
        markdownRanges(tokens, text)
    }

    @Test func referenceDefinitionsAndDestinationCodeKeepTheirOwnBoundaries() async throws {
        let links = ["<https://example.test/a`>", "[site](path`tick)", "[Read Me]", "[READ  ME][]", "[label][read me]"]
        let definition = "[Read Me]: /guide.md \"Guide\""
        let text = links.joined(separator: " and ") + " and `code`\n\n" + definition + "\n\n[unknown]\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "md")
        #expect(markdownParts(.reference, tokens, text) == links + [definition])
        #expect(markdownParts(.string, tokens, text) == ["`code`"])
        markdownRanges(tokens, text)
        let escapes = #"\``literal` \*plain\* *a `*` end* foo_𐐀_bar * plain *"#
        let escaped = try await SyntaxHighlighting.tokens(in: escapes, fileExtension: "md")
        #expect(markdownParts(.string, escaped, escapes) == ["`literal`", "`*`"])
        #expect(markdownParts(.keyword, escaped, escapes) == ["*a ", " end*"])
        markdownRanges(escaped, escapes)
    }

    @Test func longSingleTokensAndDeepIncompleteDelimitersStayBounded() async throws {
        let length = TextPreview.maximumBytes
        let sources = [
            "```\n" + String(repeating: "a", count: length - 4),
            "`" + String(repeating: "a", count: length - 2) + "`",
            "*" + String(repeating: "a", count: length - 2) + "*",
            String(repeating: "*", count: 100_000) + "word" + String(repeating: "*", count: 100_000),
            String(repeating: "[", count: 100_000) + "x](" + String(repeating: "(", count: 100_000),
            "text " + String(repeating: "`", count: 100_000),
            String(repeating: "[x](unfinished ", count: 10_000),
            String(repeating: "*a _b ", count: 1000) + "end" + String(repeating: "_ * ", count: 1000)
        ]
        for source in sources {
            let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "md")
            markdownRanges(tokens, source)
            if source.utf8.count == length { #expect(tokens.count == 1) }
        }
    }

    @Test func largeIncompleteAndUnsupportedTextHasSafeRanges() async throws {
        let line = "# Heading\n\n**bold** `code` [link](url)\n\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "md")
        #expect(text.utf8.count == TextPreview.maximumBytes)
        #expect(tokens.count > 50_000)
        markdownRanges(tokens, text)
        for source in ["", "#", "*", "**", "_", "`", "``", "```", "~~~", "[", "[x](", "![x]", "<https:", "👀 *unfinished"] {
            markdownRanges(try await SyntaxHighlighting.tokens(in: source, fileExtension: "md"), source)
        }
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sass").isEmpty)
    }
}

private func markdownParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func markdownRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
