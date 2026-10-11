import Foundation
import Testing
@testable import PanePeekCore

struct GoHighlightingTests {
    @Test func keywordsRespectCaseAndUnicodeIdentifierBoundaries() async throws {
        let text = "package main; import \"fmt\"; func greet() { if true { return }; go greet(); var x = nil } returning _func Return returnç return२ return𐐀 👀return falsehood false"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "GO")
        #expect(goParts(.keyword, tokens, text) == ["package", "import", "func", "if", "return", "go", "var", "return"])
        #expect(goParts(.literal, tokens, text) == ["true", "nil", "false"])
        #expect(goParts(.string, tokens, text) == ["\"fmt\""])
        goRanges(tokens, text)
    }

    @Test func quotedRawAndRuneLiteralsSuppressInnerCodeAndComments() async throws {
        let quoted = #""hello \"return\" // /* 👀 \u00E7""#
        let raw = "`line\r\nreturn \"quoted\" // /* \\`"
        let runes = ["'本'", "'👀'", #"'\''"#, #"'\U0001F440'"#]
        let text = "var a = " + quoted + "; var b = " + raw + "; var r = []rune{" + runes.joined(separator: ", ") + "}; return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
        #expect(goParts(.string, tokens, text) == [quoted, raw] + runes)
        #expect(goParts(.keyword, tokens, text) == ["var", "var", "var", "return"])
        #expect(goParts(.comment, tokens, text).isEmpty)
        goRanges(tokens, text)
    }

    @Test func commentsEndAtLineFeedOrFirstBlockTerminator() async throws {
        let line = "// return \"fake\"\r\u{2028}var"
        let block = "/* outer /* inner */"
        let text = line + "\n" + block + " return // tail"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
        #expect(goParts(.comment, tokens, text) == [line, block, "// tail"])
        #expect(goParts(.keyword, tokens, text) == ["return"])
        #expect(goParts(.string, tokens, text).isEmpty)
        goRanges(tokens, text)
    }

    @Test func integerFloatAndImaginaryNumbersKeepTheirBoundaries() async throws {
        let values = ["0", "42", "4_2", "0600", "0_600", "0o755", "0b_1010", "0xBad_Face", "0x_67", "072.40", ".25", "1.e+0", "1_5.", "0.15e+0_2", "0x1p-2", "0X.8p-0", "0X_1FFFP-16", "0129i", "0xabci", "1.e+0i", "0x1p-2i"]
        let text = "var n = []complex128{" + values.joined(separator: ", ") + "}; x := 0x15e-2; y := 1e+2+3"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
        #expect(goParts(.number, tokens, text) == values + ["0x15e", "2", "1e+2", "3"])
        goRanges(tokens, text)
    }

    @Test func invalidNumericRunsAndIdentifierPartsStayPlain() async throws {
        let text = "var n = []any{42_, 4__2, 0_xBadFace, 0b2, 0o8, 09, 0x.p1, 1p-2, 0x1.5e-2, 1_.5, 1._5, 1.5_e1, 1.5e_1, 1.5e1_, 12abc, 12ç, _42}; return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
        #expect(goParts(.number, tokens, text) == ["2", "2"])
        #expect(goParts(.keyword, tokens, text) == ["var", "return"])
        goRanges(tokens, text)
    }

    @Test func incompleteStringsResumeAtNewlinesAndFallbackStaysPlain() async throws {
        let text = "var a = \"unfinished\\\nreturn true; var r = 'x\nreturn nil; var raw = `unfinished\nreturn false 👀"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
        #expect(goParts(.string, tokens, text) == ["\"unfinished\\", "'x", "`unfinished\nreturn false 👀"])
        #expect(goParts(.keyword, tokens, text) == ["var", "return", "var", "return", "var"])
        #expect(goParts(.literal, tokens, text) == ["true", "nil"])
        goRanges(tokens, text)
        for source in ["", "/", "/* unfinished 👀", "'", "\"\\", "`", "0x", ".", "var a = \"\r"] {
            goRanges(try await SyntaxHighlighting.tokens(in: source, fileExtension: "go"), source)
        }
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sass").isEmpty)
    }

    @Test func largeAndLongSourceProducesOrderedBoundedRanges() async throws {
        let line = "var name = `value`; // comment\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        #expect(text.utf8.count == TextPreview.maximumBytes)
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
        #expect(tokens.count > 50_000)
        goRanges(tokens, text)
        let long = String(repeating: "1", count: 100_000) + "x; return \"👀\""
        let longTokens = try await SyntaxHighlighting.tokens(in: long, fileExtension: "go")
        #expect(goParts(.number, longTokens, long).isEmpty)
        #expect(goParts(.keyword, longTokens, long) == ["return"])
        goRanges(longTokens, long)
    }

    @Test func selectorsDoNotColourPredeclaredNamesAsConstants() async throws {
        let text = "value.true; value. /* note */ nil; value.\nfalse; value.iota; var a = true; var b = iota"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
        #expect(goParts(.literal, tokens, text) == ["true", "iota"])
        #expect(goParts(.comment, tokens, text) == ["/* note */"])
        goRanges(tokens, text)
    }

    @Test func longSingleTokensRemainWholeAndSourceRangesStaySafe() async throws {
        let number = String(repeating: "1", count: 100_000)
        let tokens = try await SyntaxHighlighting.tokens(in: number, fileExtension: "go")
        #expect(goParts(.number, tokens, number) == [number])
        goRanges(tokens, number)
        for prefix in ["`", "/*", "\""] {
            let text = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "go")
            #expect(tokens.count == 1)
            #expect(tokens.first?.range == NSRange(location: 0, length: text.utf16.count))
            goRanges(tokens, text)
        }
        let identifier = "return" + String(repeating: "𐐀", count: 100_000)
        #expect(try await SyntaxHighlighting.tokens(in: identifier, fileExtension: "go").isEmpty)
    }
}

private func goParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func goRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
