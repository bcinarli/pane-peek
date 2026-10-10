import Foundation
import Testing
@testable import PanePeekCore

struct JSXHighlightingTests {
    @Test func markupTextAttributesAndEmbeddedCodeHaveSeparateBoundaries() async throws {
        let text = "const view = <Panel.Header title=\"Türkçe 👀 &amp;\" hidden count={12}>{true ? <span>{'yes'}</span> : null}return // plain</Panel.Header>;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "JSX")
        #expect(jsxParts(.keyword, tokens, text) == ["const", "<Panel.Header", ">", "<span", ">", "</span", ">", "</Panel.Header", ">"])
        #expect(jsxParts(.key, tokens, text) == ["title", "hidden", "count"])
        #expect(jsxParts(.string, tokens, text) == ["\"Türkçe 👀 &amp;\"", "'yes'"])
        #expect(jsxParts(.number, tokens, text) == ["12"])
        #expect(jsxParts(.literal, tokens, text) == ["true", "null"])
        #expect(jsxParts(.comment, tokens, text).isEmpty)
        #expect(jsxParts(.reference, tokens, text).count == 6)
        jsxRanges(tokens, text)
    }

    @Test func fragmentsSpreadsAndNestedExpressionsReuseJavaScriptBoundaries() async throws {
        let text = #"const view = <><Box {...props} value={{text: '}', nested: true}}>{/* } <fake/> */ items.map(item => <Row key={item.id}>{/}/.test(item.text) ? `text ${item.id}` : "}"}</Row>)}</Box></>; return view;"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "jsx")
        #expect(jsxParts(.keyword, tokens, text) == ["const", "<>", "<Box", ">", "<Row", ">", "</Row", ">", "</Box", ">", "</>", "return"])
        #expect(jsxParts(.key, tokens, text) == ["value", "key"])
        #expect(jsxParts(.comment, tokens, text) == ["/* } <fake/> */"])
        #expect(jsxParts(.string, tokens, text) == ["'}'", "/}/", "`text ${item.id}`", #""}""#])
        jsxRanges(tokens, text)
    }

    @Test func jsxQuotesAndTextDoNotUseJavaScriptOrHtmlRawTextRules() async throws {
        let text = #"""
        const view = <script path="folder\" next='value' data-name="line
        text"><child/> // plain "quoted" &lt;tag&gt; {/* comment */}</script>; return view;
        """#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "jsx")
        #expect(jsxParts(.string, tokens, text) == [#""folder\""#, "'value'", "\"line\ntext\""])
        #expect(jsxParts(.key, tokens, text) == ["path", "next", "data-name"])
        #expect(jsxParts(.keyword, tokens, text).contains("<child"))
        #expect(jsxParts(.comment, tokens, text) == ["/* comment */"])
        #expect(jsxParts(.keyword, tokens, text).last == "return")
        jsxRanges(tokens, text)
    }

    @Test func tsxTypesGenericsAndComparisonsStayInCode() async throws {
        let text = "interface Props { readonly title: string } const identity = <T,>(value: T): T => value; const other = <T extends object>(value: T) => value; const less = a < b; const names: Array<Props> = []; const view = <Box<Props> title={null as unknown}/>;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "TSX")
        #expect(jsxParts(.keyword, tokens, text).filter { $0.hasPrefix("<") } == ["<Box"])
        #expect(jsxParts(.keyword, tokens, text).contains("extends"))
        #expect(jsxParts(.keyword, tokens, text).contains("unknown"))
        #expect(jsxParts(.key, tokens, text) == ["title"])
        #expect(jsxParts(.literal, tokens, text) == ["null"])
        jsxRanges(tokens, text)
    }

    @Test func codeStringsCommentsAndUnsupportedFilesCannotLeakMarkupColours() async throws {
        let text = #"const sample = '<Fake attr="text"/>'; /* <Fake/> */ const value = `text ${"<Fake/>"}`; const view = <real/>;"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "jsx")
        #expect(jsxParts(.keyword, tokens, text).filter { $0.hasPrefix("<") } == ["<real"])
        #expect(jsxParts(.key, tokens, text).isEmpty)
        #expect(jsxParts(.comment, tokens, text) == ["/* <Fake/> */"])
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        let code = "const n = true; // comment\nreturn 'text';"
        #expect(try await SyntaxHighlighting.tokens(in: code, fileExtension: "jsx") == SyntaxHighlighting.tokens(in: code, fileExtension: "js"))
        #expect(try await SyntaxHighlighting.tokens(in: code, fileExtension: "tsx") == SyntaxHighlighting.tokens(in: code, fileExtension: "ts"))
        jsxRanges(tokens, text)
    }

    @Test func incompleteUnicodeMarkupAndExpressionsRemainReadable() async throws {
        for language in ["jsx", "tsx"] {
            for text in ["", "<", "<>", "<Panel title=\"unfinished 👀", "<Panel>{/* unfinished", "<Panel value={{text: '}'}}>", "<Panel>{items.map(item => <Row>", "<ns:çocuk data-id='👀'/>;", "<Panel>{ /[}]/", "<Panel>{`unfinished ${"] {
                jsxRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: language), text)
            }
        }
        let text = "<ns:çocuk data-id='👀'/>;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "jsx")
        #expect(jsxParts(.keyword, tokens, text) == ["<ns:çocuk", "/>"])
        #expect(jsxParts(.string, tokens, text) == ["'👀'"])
    }

    @Test func directElementAttributeValuesAndTemplatesKeepTheirOuterBoundary() async throws {
        let text = #"const view = <Panel icon=<Icon name='yes'/> child=<><Row/></>>text</Panel>; const message = `nested ${<Box>{`text ${true}`}</Box>}`; return view;"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "jsx")
        #expect(jsxParts(.keyword, tokens, text) == ["const", "<Panel", "<Icon", "/>", "<>", "<Row", "/>", "</>", ">", "</Panel", ">", "const", "return"])
        #expect(jsxParts(.key, tokens, text) == ["icon", "name", "child"])
        #expect(jsxParts(.string, tokens, text) == ["'yes'", "`nested ${<Box>{`text ${true}`}</Box>}`"])
        jsxRanges(tokens, text)
    }

    @Test func incompleteExpressionCommentsDoNotProduceOverlappingBraceTokens() async throws {
        for text in ["<Box>{/* unfinished }", "<Box>{// unfinished }", "<Box>{'unfinished }", "<Box>{`unfinished }"] {
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "jsx")
            #expect(jsxParts(.reference, tokens, text) == ["{"])
            jsxRanges(tokens, text)
        }
    }

    @Test func quotedAndFunctionTypeArgumentsCannotEndTheOpeningTag() async throws {
        let text = #"const view = <Box<"a > b", (x: number) => string, /* > */ Array<Item>> title='yes'/>; return view;"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "tsx")
        #expect(jsxParts(.key, tokens, text) == ["title"])
        #expect(jsxParts(.keyword, tokens, text).filter { $0.hasPrefix("<") } == ["<Box"])
        #expect(jsxParts(.keyword, tokens, text).last == "return")
        #expect(jsxParts(.string, tokens, text) == ["'yes'"])
        jsxRanges(tokens, text)
    }

    @Test func largeAndDeepJsxHasOrderedSafeRanges() async throws {
        let line = "const view = <Box title='text'>{true ? <Row/> : null}</Box>;\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        for language in ["jsx", "tsx"] {
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: language)
            #expect(tokens.count > 50_000)
            jsxRanges(tokens, text)
            let deep = String(repeating: "<Box>{", count: 200) + "true" + String(repeating: "}</Box>", count: 200)
            jsxRanges(try await SyntaxHighlighting.tokens(in: deep, fileExtension: language), deep)
        }
    }
}

private func jsxParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func jsxRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
