import Foundation
import Testing
@testable import PanePeekCore

struct JavaHighlightingTests {
    @Test func keywordsRespectCaseAndJavaIdentifierBoundaries() async throws {
        let text = "package sample; import java.util.List; public sealed class Example permits Child { private final boolean enabled = true; void run() { if (enabled) return; } } record Pair(int left, int right) {} var x = null; non-sealed class Child {} _ Return returning $return return$ returnç returń return२ return𐐀 return\u{200C}name 👀return falsehood false"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "JAVA")
        #expect(javaParts(.keyword, tokens, text) == ["package", "import", "public", "sealed", "class", "permits", "private", "final", "boolean", "void", "if", "return", "record", "int", "int", "var", "non-sealed", "class", "_", "return"])
        #expect(javaParts(.literal, tokens, text) == ["true", "null", "false"])
        javaRanges(tokens, text)
    }

    @Test func quotedStringsAndCharactersSuppressInnerTokensAndRecoverAtNewlines() async throws {
        let quoted = #""hello \"return\" // /* 👀 \u00E7""#
        let characters = ["'本'", #"'\\'"#, #"'\''"#, #"'\141'"#]
        let text = "return " + quoted + "; char[] x = {" + characters.joined(separator: ", ") + "}; \"unfinished\\\rreturn true; 'x\nreturn null;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
        #expect(javaParts(.string, tokens, text) == [quoted] + characters + ["\"unfinished\\", "'x"])
        #expect(javaParts(.keyword, tokens, text) == ["return", "char", "return", "return"])
        #expect(javaParts(.literal, tokens, text) == ["true", "null"])
        #expect(javaParts(.comment, tokens, text).isEmpty)
        javaRanges(tokens, text)
    }

    @Test func textBlocksRequireAnOpeningNewlineAndProtectEscapedClosingQuotes() async throws {
        let block = "\"\"\" \t\u{C}\r\n" + #"return "quoted" // /* \""" still text"# + "\n\"\"\""
        let incomplete = "\"\"\"\nreturn false 👀"
        let text = "return " + block + "; return \"\"\"same line\rreturn true; " + incomplete
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
        #expect(javaParts(.string, tokens, text) == [block, "\"\"", "\"same line", incomplete])
        #expect(javaParts(.keyword, tokens, text) == ["return", "return", "return"])
        #expect(javaParts(.literal, tokens, text) == ["true"])
        #expect(javaParts(.comment, tokens, text).isEmpty)
        javaRanges(tokens, text)
    }

    @Test func commentsEndAtCrLfOrTheFirstBlockTerminator() async throws {
        let line = "// return \"fake\"\u{2028}class"
        let block = "/* outer /* inner */"
        let doc = "/** return \"fake\" */"
        let text = line + "\rreturn\n" + block + " return " + doc + " return // tail"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
        #expect(javaParts(.comment, tokens, text) == [line, block, doc, "// tail"])
        #expect(javaParts(.keyword, tokens, text) == ["return", "return", "return"])
        #expect(javaParts(.string, tokens, text).isEmpty)
        javaRanges(tokens, text)
    }

    @Test func unicodeEscapesChangeLexicalBoundariesWithoutChangingSourceRanges() async throws {
        let keyword = #"ret\uuuu0075rn"#
        let comment = #"\u002f\u002f return "fake""#
        let quote = #"\u0022return // \u0022"#
        let block = #"\u002f* return *\u002f"#
        let text = "👀 " + keyword + " " + comment + #"\u000dreturn "# + quote + " " + block + " true"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
        #expect(javaParts(.keyword, tokens, text) == [keyword, "return"])
        #expect(javaParts(.comment, tokens, text) == [comment, block])
        #expect(javaParts(.string, tokens, text) == [quote])
        #expect(javaParts(.literal, tokens, text) == ["true"])
        javaRanges(tokens, text)
        let eligibility = #"// \\u000areturn \u000dreturn // \u005cu005areturn"#
        let eligibleTokens = try await SyntaxHighlighting.tokens(in: eligibility, fileExtension: "java")
        #expect(javaParts(.comment, eligibleTokens, eligibility) == [#"// \\u000areturn "#, #"// \u005cu005areturn"#])
        #expect(javaParts(.keyword, eligibleTokens, eligibility) == ["return"])
        javaRanges(eligibleTokens, eligibility)
    }

    @Test func integerAndFloatFormsKeepValidAndInvalidRunsWhole() async throws {
        let values = ["0", "42L", "4__2", "0777", "0__7L", "0b10__01", "0xCAFE_BABEL", ".25", "1.", "01.25", "1e+2", "1e-2F", "42d", "0x1p-2", "0X.8P+2D", "0x1.fp3", "0x1.p1"]
        let invalid = ["42_", "0_x1", "0x_1", "0b_1", "0b2", "09", "1e+", "1._2", "1_.2", "0x1.2", "0x.p1", "1f2", "12abc", "12ç"]
        let text = values.joined(separator: ", ") + "; " + invalid.joined(separator: ", ") + "; 0x15e-2; 1e+2+3; return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
        #expect(javaParts(.number, tokens, text) == values + ["0x15e", "2", "1e+2", "3"])
        #expect(javaParts(.keyword, tokens, text) == ["return"])
        javaRanges(tokens, text)
    }

    @Test func largeIncompleteAndUnsupportedSourceRemainsReadableWithSafeRanges() async throws {
        let line = "var name = \"value\"; // comment\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        #expect(text.utf8.count == TextPreview.maximumBytes)
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
        #expect(tokens.count > 50_000)
        javaRanges(tokens, text)
        let long = String(repeating: "1", count: 100_000) + "x; return \"👀\""
        let longTokens = try await SyntaxHighlighting.tokens(in: long, fileExtension: "java")
        #expect(javaParts(.number, longTokens, long).isEmpty)
        #expect(javaParts(.keyword, longTokens, long) == ["return"])
        javaRanges(longTokens, long)
        for source in ["", "/", "/* unfinished 👀", "'", "\"\\", "\"\"\"", "\"\"\"\n", #"ret\u"#, #"ret\u00xzrn"#, #"\uD800"#, "0x", "."] {
            javaRanges(try await SyntaxHighlighting.tokens(in: source, fileExtension: "java"), source)
        }
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sass").isEmpty)
    }
    @Test func contextualMembersAndEscapedIdentifiersKeepTheirBoundaries() async throws {
        let text = #"value.record; value. /* note */ yield; value."# + "\n" + #"var; record Item() {} return\u0024 ret\u0000urn return\uD801\uDC00 \uD801\uDC00return non-sealed\uD801\uDC00 non-sealedclass non-sealed; return"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
        #expect(javaParts(.keyword, tokens, text) == ["record", "non-sealed", "return"])
        #expect(javaParts(.comment, tokens, text) == ["/* note */"])
        javaRanges(tokens, text)
        let escapes = [
            (#"// \\\u000areturn"#, #"// \\"#),
            (#"// \u005c\u000areturn"#, #"// \u005c"#),
            (#"// \u005c\\u000areturn"#, #"// \u005c\"#)
        ]
        for (source, comment) in escapes {
            let result = try await SyntaxHighlighting.tokens(in: source, fileExtension: "java")
            #expect(javaParts(.comment, result, source) == [comment])
            #expect(javaParts(.keyword, result, source) == ["return"])
            javaRanges(result, source)
        }
        let quoted = #""\u005c\u0022 return // " return"#
        let quotedTokens = try await SyntaxHighlighting.tokens(in: quoted, fileExtension: "java")
        #expect(javaParts(.string, quotedTokens, quoted) == [#""\u005c\u0022 return // ""#])
        #expect(javaParts(.keyword, quotedTokens, quoted) == ["return"])
        javaRanges(quotedTokens, quoted)
    }

    @Test func longSingleTokensAndUnicodeMarkersStayBounded() async throws {
        for prefix in ["\"", "/*", "//", "\"\"\"\n"] {
            let text = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "java")
            #expect(tokens.count == 1)
            #expect(tokens.first?.range == NSRange(location: 0, length: text.utf16.count))
            javaRanges(tokens, text)
        }
        let digits = String(repeating: "1", count: 100_000)
        for number in [digits, "0x" + digits + "p2", digits + ".0e+2F"] {
            let tokens = try await SyntaxHighlighting.tokens(in: number, fileExtension: "java")
            #expect(javaParts(.number, tokens, number) == [number])
            javaRanges(tokens, number)
        }
        let keyword = "ret\\" + String(repeating: "u", count: 100_000) + "0075rn"
        let keywordTokens = try await SyntaxHighlighting.tokens(in: keyword, fileExtension: "java")
        #expect(javaParts(.keyword, keywordTokens, keyword) == [keyword])
        javaRanges(keywordTokens, keyword)
        let malformed = "\\" + String(repeating: "u", count: 100_000) + "00xz; return"
        let malformedTokens = try await SyntaxHighlighting.tokens(in: malformed, fileExtension: "java")
        #expect(javaParts(.keyword, malformedTokens, malformed) == ["return"])
        javaRanges(malformedTokens, malformed)
        let identifier = "return" + String(repeating: "𐐀", count: 100_000)
        #expect(try await SyntaxHighlighting.tokens(in: identifier, fileExtension: "java").isEmpty)
    }
}

private func javaParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func javaRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
