import Foundation
import Testing
@testable import PanePeekCore

struct RustHighlightingTests {
    @Test func keywordsRespectUnicodeAndRawIdentifierBoundaries() async throws {
        let text = "pub async fn greet() { let mut x = true; if false { return } } impl Self gen returning Return returnç return\u{301} return𐐀 _return r#return r#true 👀return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "RS")
        #expect(rustParts(.keyword, tokens, text) == ["pub", "async", "fn", "let", "mut", "if", "return", "impl", "Self", "gen", "return"])
        #expect(rustParts(.literal, tokens, text) == ["true", "false"])
        rustRanges(tokens, text)
    }

    @Test func quotedRawByteAndCStringLiteralsProtectInnerSyntax() async throws {
        let strings = [#""hello \"return\" // /* 👀""#, "\"line one\nreturn\\\nline two\"", #"r"raw \ return""#, ###"r##"inner "# // /* \ return"##"###, #"b"bytes \x52""#, ##"br#"bytes " \ return"#"##, #"c"C 👀""#, ##"cr#"C \ return"#"##]
        let text = "let values = (" + strings.joined(separator: ", ") + "); return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(rustParts(.string, tokens, text) == strings)
        #expect(rustParts(.keyword, tokens, text) == ["let", "return"])
        #expect(rustParts(.comment, tokens, text).isEmpty)
        rustRanges(tokens, text)
    }

    @Test func charactersAndLifetimesDoNotSwallowFollowingCode() async throws {
        let characters = ["'x'", "'本'", "'👀'", #"'\''"#, #"'\u{1_f440}'"#, #"b'\x52'"#]
        let text = "fn borrow<'a>(x: &'a str) -> &'static str { 'outer: loop { break 'outer; } let c = (" + characters.joined(separator: ", ") + "); return x; } '_ 'r#match"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(rustParts(.string, tokens, text) == characters)
        #expect(rustParts(.reference, tokens, text) == ["'a", "'a", "'static", "'outer", "'outer", "'_", "'r#match"])
        #expect(rustParts(.keyword, tokens, text) == ["fn", "loop", "break", "let", "return"])
        rustRanges(tokens, text)
    }

    @Test func commentsNestAndDocCommentsRemainSource() async throws {
        let line = "/// return \"fake\"\r\u{2028}fn"
        let block = "/*! outer /* inner */ /** doc */ return \"fake\" */"
        let text = line + "\n" + block + " fn real() {} //! tail"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(rustParts(.comment, tokens, text) == [line, block, "//! tail"])
        #expect(rustParts(.keyword, tokens, text) == ["fn"])
        #expect(rustParts(.string, tokens, text).isEmpty)
        rustRanges(tokens, text)
    }

    @Test func numbersPreserveRangesAndMemberAccessBoundaries() async throws {
        let values = ["0", "42__", "123_u32", "0b________1", "0o70_i16", "0x01_f32", "5f32", "1.", "1.25", "1e+2", "1.0e-2f64", "2e__3", "123custom"]
        let text = values.joined(separator: ", ") + "; 1..2; 1..=3; 2.f64(); 2._field; 0x15e-2; return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(rustParts(.number, tokens, text) == values + ["1", "2", "1", "3", "2", "2", "0x15e", "2"])
        #expect(rustParts(.keyword, tokens, text) == ["return"])
        rustRanges(tokens, text)
    }

    @Test func incompleteInputStaysReadableAndFallbackStaysPlain() async throws {
        for text in ["", "/", "'", "b'", "'a", "'\\u{", "r#", "r#\"unfinished 👀\nreturn", "/* outer /* inner */", "\"unfinished\\", "0x", "2e+", "r" + String(repeating: "#", count: 256) + "\"tail\""] {
            rustRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs"), text)
        }
        let text = "fn a() { let x = r##\"unfinished\"#\nreturn 👀"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(rustParts(.keyword, tokens, text) == ["fn", "let"])
        #expect(rustParts(.string, tokens, text) == ["r##\"unfinished\"#\nreturn 👀"])
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sass").isEmpty)
        rustRanges(tokens, text)
    }

    @Test func largeAndDeepInputsHaveSafeWholeTokens() async throws {
        let line = "let name = r#\"value\"#; // comment\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        #expect(text.utf8.count == TextPreview.maximumBytes)
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(tokens.count > 50_000)
        rustRanges(tokens, text)
        let deep = String(repeating: "/*", count: 10_000) + "👀" + String(repeating: "*/", count: 10_000) + " fn"
        let deepTokens = try await SyntaxHighlighting.tokens(in: deep, fileExtension: "rs")
        #expect(rustParts(.comment, deepTokens, deep).count == 1)
        #expect(rustParts(.keyword, deepTokens, deep) == ["fn"])
        rustRanges(deepTokens, deep)
        let hashes = "r" + String(repeating: "#", count: 100_000) + "; return"
        #expect(rustParts(.keyword, try await SyntaxHighlighting.tokens(in: hashes, fileExtension: "rs"), hashes) == ["return"])
    }

    @Test func literalSuffixesAndInvalidNumbersDoNotLeakKeywords() async throws {
        let text = ##""text"return 'x'return b'X'return r#"raw"#return 123return; 0b2 0o8 0x 0x80.0 0b101e 2e+; return"##
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(rustParts(.string, tokens, text) == [#""text"return"#, "'x'return", "b'X'return", ##"r#"raw"#return"##])
        #expect(rustParts(.number, tokens, text) == ["123return"])
        #expect(rustParts(.keyword, tokens, text) == ["return"])
        rustRanges(tokens, text)
    }

    @Test func maximumHashStringsAndLongSingleTokensRemainWhole() async throws {
        let hashes = String(repeating: "#", count: 255)
        let raw = "r" + hashes + "\"👀 \"" + String(repeating: "#", count: 254) + " return \"" + hashes
        let text = raw + "; return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
        #expect(rustParts(.string, tokens, text) == [raw])
        #expect(rustParts(.keyword, tokens, text) == ["return"])
        rustRanges(tokens, text)
        for prefix in ["r#\"", "/*", "\""] {
            let text = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "rs")
            #expect(tokens.count == 1)
            #expect(tokens.first?.range == NSRange(location: 0, length: text.utf16.count))
            rustRanges(tokens, text)
        }
        let identifier = "return" + String(repeating: "𐐀", count: 100_000)
        #expect(try await SyntaxHighlighting.tokens(in: identifier, fileExtension: "rs").isEmpty)
        let number = String(repeating: "1", count: 100_000)
        #expect(rustParts(.number, try await SyntaxHighlighting.tokens(in: number, fileExtension: "rs"), number) == [number])
    }
}

private func rustParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func rustRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
