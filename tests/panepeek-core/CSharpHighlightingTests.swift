import Foundation
import Testing
@testable import PanePeekCore

struct CSharpHighlightingTests {
    @Test func formatRecoveryAndContextualMembersKeepFollowingSourceVisible() async throws {
        let malformed = [#"$"{value:F2""#, "$\"{value:F2"]
        let source = malformed[0] + "; return\n" + malformed[1] + "\u{2028}return\nvalue. /* note */ record; value::await; value->init; record Item; @record; return"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(csParts(.string, tokens, source) == malformed)
        #expect(csParts(.keyword, tokens, source) == ["return", "return", "value", "value", "value", "record", "return"])
        #expect(csParts(.comment, tokens, source) == ["/* note */"])
        csRanges(tokens, source)
        let formatted = [#"$"{global::Names.Get("}"):F2} tail""#, #"$@"{value:""return""} tail""#, #"$$"""{{value:"return"}} tail""""#]
        let text = formatted.joined(separator: "; return ") + "; return"
        let result = try await SyntaxHighlighting.tokens(in: text, fileExtension: "cs")
        #expect(csParts(.string, result, text) == formatted)
        #expect(csParts(.keyword, result, text) == Array(repeating: "return", count: formatted.count))
        csRanges(result, text)
    }

    @Test func longDelimitersSingleTokensAndNestedFieldsStayBounded() async throws {
        for prefix in ["\"", "@\"", "/*", "//", "\"\"\"\n", "$\"{"] {
            let source = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
            #expect(tokens.count == 1 && tokens.first?.range == NSRange(location: 0, length: source.utf16.count))
            csRanges(tokens, source)
        }
        let quotes = String(repeating: "\"", count: 100_000)
        let dollars = String(repeating: "$", count: 100_000)
        for raw in [quotes + "value" + quotes, dollars + "\"\"\"{value}\"\"\""] {
            let tokens = try await SyntaxHighlighting.tokens(in: raw, fileExtension: "cs")
            #expect(csParts(.string, tokens, raw) == [raw])
            csRanges(tokens, raw)
        }
        for text in [String(repeating: "'", count: 100_000), dollars + "; return", "ret" + String(repeating: "ç", count: 100_000), String(repeating: "$\"{", count: 100) + "👀", "$\"{" + String(repeating: "(", count: 100_000)] {
            csRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: "cs"), text)
        }
        let raw = "\"\"\"\n text\"\"\" inline stays raw\n \"\"\"\" too many stays raw\n \"\"\""
        let source = raw + "; return"
        let result = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(csParts(.string, result, source) == [raw])
        #expect(csParts(.keyword, result, source) == ["return"])
        csRanges(result, source)
    }

    @Test func keywordsRespectWholeEscapedAndUnicodeNames() async throws {
        let source = #"namespace Example; public sealed record Item { required string Name { get; init; } async void Run() { if (true) return null; } } @return @true Return returning returnç returń return२ return𐐀 return\u00e7 \u0072eturn ret\u0075rn false"#
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "CS")
        #expect(csParts(.keyword, tokens, source) == ["namespace", "public", "sealed", "record", "required", "string", "get", "init", "async", "void", "if", "return"])
        #expect(csParts(.literal, tokens, source) == ["true", "null", "false"])
        csRanges(tokens, source)
    }

    @Test func ordinaryStringsAndCharactersProtectEscapesAndRecoverAtLineBreaks() async throws {
        let quoted = #""return \"quoted\" // 👀""#
        let characters = [#"'\''"#, #"'\\'"#, "'本'"]
        let utf8 = #""Türkçe"u8"#
        let source = quoted + " " + characters.joined(separator: " ") + " " + utf8 + "; \"unfinished\\\r\nreturn 'x\u{85}return \"x\u{2028}return"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(csParts(.string, tokens, source) == [quoted] + characters + [utf8, "\"unfinished\\", "'x", "\"x"])
        #expect(csParts(.keyword, tokens, source) == ["return", "return", "return"])
        #expect(csParts(.comment, tokens, source).isEmpty)
        csRanges(tokens, source)
    }

    @Test func verbatimStringsKeepDoubledQuotesAndPhysicalNewlines() async throws {
        let verbatim = "@\"C:\\return\\\n\"\"quoted\"\" // literal 👀\"U8"
        let source = verbatim + "; return @\"unfinished\n// literal"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(csParts(.string, tokens, source) == [verbatim, "@\"unfinished\n// literal"])
        #expect(csParts(.keyword, tokens, source) == ["return"])
        #expect(csParts(.comment, tokens, source).isEmpty)
        csRanges(tokens, source)
    }

    @Test func rawStringsUseMatchingQuoteRunsAndMultilineClosingLines() async throws {
        let single = #"""""return "quoted" // """ still raw""""u8"#
        let multiline = "\"\"\" \t\r\n  return \"quoted\" // literal\n  \"\" near delimiter\n  \"\"\""
        let source = single + "; return " + multiline + "; return \"\"\"bad line\nreturn"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(csParts(.string, tokens, source) == [single, multiline, "\"\"\"bad line"])
        #expect(csParts(.keyword, tokens, source) == ["return", "return", "return"])
        #expect(csParts(.comment, tokens, source).isEmpty)
        csRanges(tokens, source)
    }

    @Test func interpolationProtectsNestedSourceAndVariableBraceCounts() async throws {
        let regular = #"$"{{literal}} {new Item { Name = "}" }} {($"{name}")} {value:F2} // literal""#
        let verbatim = "$@\"text {Get(\"}\", @\"\"\"\")}\n\"\"tail\"\"\""
        let alternate = #"@$"{Get("return")} tail""#
        let raw = #"$$"""{"value": {{{Get("}", "return")}}}, "literal": {return}}""""#
        let comment = "$\"{ /* } \" */ Get(\"return\") // } \"\n} tail\""
        let strings = [regular, verbatim, alternate, raw, comment]
        let source = strings.joined(separator: "; return ") + "; return"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(csParts(.string, tokens, source) == strings)
        #expect(csParts(.keyword, tokens, source) == Array(repeating: "return", count: strings.count))
        #expect(csParts(.comment, tokens, source).isEmpty)
        csRanges(tokens, source)
    }

    @Test func commentsAreNonNestedAndUseUnicodeLineTerminators() async throws {
        let source = "/// return \"fake\"\u{2028}return /* outer /* inner */ return // tail\\\nreturn // last\u{2029}return"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(csParts(.comment, tokens, source) == ["/// return \"fake\"", "/* outer /* inner */", "// tail\\", "// last"])
        #expect(csParts(.keyword, tokens, source) == Array(repeating: "return", count: 4))
        #expect(csParts(.string, tokens, source).isEmpty)
        csRanges(tokens, source)
    }

    @Test @MainActor func largeIncompleteSourceReachesThePreviewPipelineWithSafeRanges() async throws {
        let line = "var name = \"value\"; // comment\n"
        let source = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        #expect(source.utf8.count == TextPreview.maximumBytes)
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cs")
        #expect(!tokens.isEmpty)
        csRanges(tokens, source)
        let sample = "public string Name = \"👀\"; // note\n"
        let state = PreviewState(read: { _ in .text(sample) })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview/sample.CS"), isDirectory: false), listingRevision: UUID()))
        #expect(state.preview == .text(sample))
        #expect(state.tokens == (try await SyntaxHighlighting.tokens(in: sample, fileExtension: "cs")))
        #expect(!state.tokens.isEmpty)
        for text in ["", "$", "@", "/*", "\"\\", "'", "\"\"\"", "$$\"\"\"\n", "$\"{", #"ret\u"#] {
            csRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: "cs"), text)
        }
        for ext in ["txt", "csx", "sass"] {
            #expect(try await SyntaxHighlighting.tokens(in: sample, fileExtension: ext).isEmpty)
        }
    }
}

private func csParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func csRanges(_ tokens: [SyntaxToken], _ text: String) {
    let length = text.utf16.count
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
