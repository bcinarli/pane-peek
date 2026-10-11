import Foundation
import Testing
@testable import PanePeekCore

struct MarkupHighlightingTests {
    @Test func htmlTagsAttributesAndQuotedValuesKeepTheirBoundaries() async throws {
        let text = "Türkçe 👀 <main data-title=\"a > b &amp; c\" hidden><input value='<!-- text -->' disabled/></main> 2 < 3"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "HTML")
        #expect(markupParts(.keyword, tokens, text) == ["<main", ">", "<input", "/>", "</main", ">"])
        #expect(markupParts(.key, tokens, text) == ["data-title", "hidden", "value", "disabled"])
        #expect(markupParts(.string, tokens, text) == ["\"a > b &amp; c\"", "'<!-- text -->'"])
        #expect(markupParts(.comment, tokens, text).isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "htm") == tokens)
        markupRanges(tokens, text)
    }

    @Test func commentsAndCdataSuppressTagLikeText() async throws {
        let text = "<!-- <fake attr='value'> -->\r\n<root><![CDATA[<fake> & text 👀]]><child/></root>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "xml")
        #expect(markupParts(.comment, tokens, text) == ["<!-- <fake attr='value'> -->"])
        #expect(markupParts(.string, tokens, text) == ["<![CDATA[<fake> & text 👀]]>"])
        #expect(markupParts(.keyword, tokens, text) == ["<root", ">", "<child", "/>", "</root", ">"])
        markupRanges(tokens, text)
    }

    @Test func xmlNamespacesInstructionsAndInternalDeclarationsRemainBounded() async throws {
        let declaration = "<!DOCTYPE ns:root [<!ENTITY example \"a > b\"><!-- ] > -->]>"
        let text = "<?xml version=\"1.0\"?>\n" + declaration + "\n<ns:root xmlns:ns='urn:demo' xml:lang=\"tr\"><çocuk/></ns:root>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "XML")
        #expect(markupParts(.section, tokens, text) == ["<?xml", "?>", declaration])
        #expect(markupParts(.key, tokens, text) == ["version", "xmlns:ns", "xml:lang"])
        #expect(markupParts(.string, tokens, text) == ["\"1.0\"", "'urn:demo'", "\"tr\""])
        #expect(markupParts(.keyword, tokens, text) == ["<ns:root", ">", "<çocuk", "/>", "</ns:root", ">"])
        markupRanges(tokens, text)
    }

    @Test func htmlRawTextOnlyEndsAtItsOwnCaseInsensitiveClosingTag() async throws {
        let text = "<SCRIPT>const text = '<fake>'; </scripture> <!-- ignored --></sCrIpT><style>a::before {content: '<fake>'}</style><textarea><fake></textarea><p title=ok>end</p>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "html")
        #expect(markupParts(.keyword, tokens, text) == ["<SCRIPT", ">", "</sCrIpT", ">", "<style", ">", "</style", ">", "<textarea", ">", "</textarea", ">", "<p", ">", "</p", ">"])
        #expect(markupParts(.key, tokens, text) == ["title"])
        #expect(markupParts(.string, tokens, text) == ["ok"])
        #expect(markupParts(.comment, tokens, text).isEmpty)
        let xml = "<script><child/></script>"
        let xmlTokens = try await SyntaxHighlighting.tokens(in: xml, fileExtension: "xml")
        #expect(markupParts(.keyword, xmlTokens, xml).contains("<child"))
        markupRanges(tokens, text)
    }

    @Test func attributeQuotesUseMarkupRulesRatherThanBackslashEscapes() async throws {
        let text = #"<item path="folder\" next='value' link=http://example.test/a/ >"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "html")
        #expect(markupParts(.key, tokens, text) == ["path", "next", "link"])
        #expect(markupParts(.string, tokens, text) == [#""folder\""#, "'value'", "http://example.test/a/"])
        markupRanges(tokens, text)
    }

    @Test func incompleteAndUnsupportedMarkupRemainsReadable() async throws {
        for language in ["html", "xml"] {
            for text in ["", "<", "</", "<item attr=\"unfinished 👀", "<!-- unfinished", "<![CDATA[unfinished", "<?xml version='1.0'", "<!DOCTYPE root [", "<script>unfinished <tag>"] {
                markupRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: language), text)
                #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
                #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sass").isEmpty)
            }
        }
        let text = "<!-- unfinished <tag>"
        #expect(markupParts(.comment, try await SyntaxHighlighting.tokens(in: text, fileExtension: "html"), text) == [text])
    }

    @Test func largeMarkupAndRepeatedLessThanSignsHaveSafeRanges() async throws {
        let line = "<item name=\"text\">value</item>\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        for language in ["html", "xml"] {
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: language)
            #expect(tokens.count > 50_000)
            markupRanges(tokens, text)
            let invalid = String(repeating: "<", count: 100_000) + "<item/>"
            let invalidTokens = try await SyntaxHighlighting.tokens(in: invalid, fileExtension: language)
            #expect(markupParts(.keyword, invalidTokens, invalid) == ["<item", "/>"])
            markupRanges(invalidTokens, invalid)
        }
    }

    @Test func htmlUnicodeNamesAndTextElementSelfClosingFlagsKeepBoundaries() async throws {
        let text = "<résumé data-name='👀'/><script/><fake></SCRIPT><plaintext><fake></plaintext>"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "html")
        #expect(markupParts(.keyword, tokens, text) == ["<résumé", "/>", "<script", "/>", "</SCRIPT", ">", "<plaintext", ">"])
        #expect(markupParts(.key, tokens, text) == ["data-name"])
        markupRanges(tokens, text)
    }

    @Test func xmlProcessingInstructionDataEndsWithoutAttributeQuoteRules() async throws {
        let text = #"<?demo data="?>"?><root/>"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "xml")
        #expect(markupParts(.section, tokens, text) == ["<?demo", #" data="?>"#])
        #expect(markupParts(.string, tokens, text).isEmpty)
        #expect(markupParts(.keyword, tokens, text) == ["<root", "/>"])
        markupRanges(tokens, text)
    }
}

private func markupParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func markupRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
