import Foundation
import Testing
@testable import PanePeekCore

struct SyntaxHighlightingTests {
    @Test func swiftKeywordsDoNotLeakOutOfStringsCommentsOrEscapedIdentifiers() async throws {
        let text = "let café👀 = \"return // text\"\r\nfunc greet() { /* outer /* let */ var */ return café👀 }\n// func\nlet `class` = 1"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "swift")
        #expect(parts(.keyword, tokens, text) == ["let", "func", "return", "let"])
        #expect(parts(.string, tokens, text) == ["\"return // text\""])
        #expect(parts(.comment, tokens, text) == ["/* outer /* let */ var */", "// func"])
        assertRanges(tokens, text)
    }

    @Test func swiftRawMultilineEscapedAndInterpolatedStringsStayWhole() async throws {
        let strings = [
            #""escaped \" let""#,
            ##"#"a "quote" // let"#"##,
            "\"\"\"\nlet \"quoted\"\r\n// string\n\"\"\"",
            #""value \(format("inside")) tail""#
        ]
        let text = strings.map { "let value = \($0)" }.joined(separator: "\n")
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "SWIFT")
        #expect(parts(.string, tokens, text) == strings)
        #expect(parts(.keyword, tokens, text) == Array(repeating: "let", count: strings.count))
        #expect(parts(.comment, tokens, text).isEmpty)
        assertRanges(tokens, text)
    }

    @Test func jsonStringsNumbersAndLiteralsAreDistinctAndPreserveUnicodeOffsets() async throws {
        let text = #"{"👀":"true \"quoted\"", "é": [-12.5e+2, 0, 1E-3, true, false, null], "number": "42"}"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "json")
        #expect(parts(.string, tokens, text) == [#""👀""#, #""true \"quoted\"""#, #""é""#, #""number""#, #""42""#])
        #expect(parts(.number, tokens, text) == ["-12.5e+2", "0", "1E-3"])
        #expect(parts(.literal, tokens, text) == ["true", "false", "null"])
        assertRanges(tokens, text)
    }

    @Test func jsonPartialOrIdentifierLikeTokensDoNotBecomeValidNumbersOrLiterals() async throws {
        let text = "[01, 1., 1e, +1, .1, trueValue, falsehood, nullish, 12x, 2, true]"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "json")
        #expect(parts(.number, tokens, text) == ["2"])
        #expect(parts(.literal, tokens, text) == ["true"])
        assertRanges(tokens, text)
    }

    @Test func incompleteSourceTerminatesWithSafeRangesAndUnsupportedFilesStayPlain() async throws {
        for text in ["let s = \"unfinished 👀", "let s = #\"unfinished", "let a = 1 /* nested /* comment", "", "\"\"\"\nunfinished"] {
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "swift")
            assertRanges(tokens, text)
            if !text.isEmpty { #expect(!tokens.isEmpty) }
            #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        }
    }

    @Test func cancelledHighlightingDoesNotReturnAResult() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await SyntaxHighlighting.tokens(in: "let value = 1", fileExtension: "swift")
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func largeAndDeeplyNestedSourceHasSafeRanges() async throws {
        let line = "let value = \"text\" // comment\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "swift")
        #expect(tokens.count > 50_000)
        assertRanges(tokens, text)
        let nested = "let value = " + String(repeating: "\"\\(", count: 80) + "value" + String(repeating: ")\"", count: 80)
        let nestedTokens = try await SyntaxHighlighting.tokens(in: nested, fileExtension: "swift")
        #expect(nestedTokens.count == 2)
        assertRanges(nestedTokens, nested)
    }

    @Test func longUnquotedHashRunsDoNotHideFollowingSource() async throws {
        let hashes = String(repeating: "#", count: TextPreview.maximumBytes - 32)
        let text = hashes + "\nlet value"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "swift")
        #expect(parts(.keyword, tokens, text) == ["let"])
        assertRanges(tokens, text)
        let interpolated = "let value = \"\\(" + hashes + ") tail\"\nreturn value"
        let interpolatedTokens = try await SyntaxHighlighting.tokens(in: interpolated, fileExtension: "swift")
        #expect(parts(.keyword, interpolatedTokens, interpolated) == ["let", "return"])
        #expect(parts(.string, interpolatedTokens, interpolated).count == 1)
        assertRanges(interpolatedTokens, interpolated)
    }
}

private func parts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func assertRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
