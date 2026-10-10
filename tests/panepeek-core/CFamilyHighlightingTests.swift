import Foundation
import Testing
@testable import PanePeekCore

struct CFamilyHighlightingTests {
    @Test func escapedNamesAndSplicedWordsKeepTheirWholeBoundaries() async throws {
        let source = #"return\u00e7 \u00e7return return\U00010400 return\u{e7} "# + "ret\\\nurn ret\\\r\nurn true\\\nname 1'000; return"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cpp")
        #expect(cParts(.keyword, tokens, source) == ["ret\\\nurn", "ret\\\r\nurn", "return"])
        #expect(cParts(.literal, tokens, source).isEmpty)
        cRanges(tokens, source)
    }

    @Test func rawDelimiterBoundsAndDirectiveContextsDoNotLeak() async throws {
        let delimiter = "abcdefghijklmnop"
        let raw = "R\"" + delimiter + "(return )other\" \\\ntext)" + delimiter + "\""
        let invalid = "R\"abcdefghijklmnopq(return)abcdefghijklmnopq\""
        let source = raw + "; return " + invalid + "; return\n#include MACRO <return>\n# /* note\n*/ include <return>\n/* note\n*/ #include \"return\\\" trailing\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cpp")
        #expect(cParts(.string, tokens, source) == [raw, String(invalid.dropFirst()), "\"return\\\""])
        #expect(cParts(.keyword, tokens, source) == ["return", "return", "return", "return"])
        cRanges(tokens, source)
        for prefix in ["R\"tag(", "/*", "//", "\""] {
            let text = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let result = try await SyntaxHighlighting.tokens(in: text, fileExtension: "cpp")
            #expect(result.count == 1 && result.first?.range == NSRange(location: 0, length: text.utf16.count))
            cRanges(result, text)
        }
        let word = "return" + String(repeating: "ç", count: 100_000)
        #expect(try await SyntaxHighlighting.tokens(in: word, fileExtension: "cpp").isEmpty)
    }

    @Test func keywordsRespectCaseAndWholeNames() async throws {
        let source = "static const char* name; _Atomic int count; _BitInt(9) bits; template <typename T> constexpr bool ready = true; if (ready) return nullptr; Return returning return_name returnç 👀return false;"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "CPP")
        #expect(cParts(.keyword, tokens, source) == ["static", "const", "char", "_Atomic", "int", "_BitInt", "template", "typename", "constexpr", "bool", "if", "return"])
        #expect(cParts(.literal, tokens, source) == ["true", "nullptr", "false"])
        cRanges(tokens, source)
    }

    @Test func stringsAndCharactersProtectEscapesAndRecoverAtNewlines() async throws {
        let strings = [#""return \"quoted\" // 👀""#, #"u8"Türkçe""#, #"L'\''"#, #"U'本'"#, #""value"_tag"#]
        let incomplete = "\"unfinished\nreturn 'x\r\nreturn"
        let source = strings.joined(separator: ", ") + "; " + incomplete
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "c")
        #expect(cParts(.string, tokens, source) == strings + ["\"unfinished", "'x"])
        #expect(cParts(.keyword, tokens, source) == ["return", "return"])
        #expect(cParts(.comment, tokens, source).isEmpty)
        cRanges(tokens, source)
    }

    @Test func rawStringsRequireExactDelimitersAndKeepPhysicalSplices() async throws {
        let raw = "u8R\"tag(return \"quoted\" // )TAG\" \\\n)ta\\\ng\" still raw)tag\"_value"
        let other = #"R"(raw /* comment */)""#
        let source = raw + "; return " + other + "; return"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cxx")
        #expect(cParts(.string, tokens, source) == [raw, other])
        #expect(cParts(.keyword, tokens, source) == ["return", "return"])
        #expect(cParts(.comment, tokens, source).isEmpty)
        cRanges(tokens, source)
    }

    @Test func commentsAreNonNestedAndSplicingPrecedesTheirBoundaries() async throws {
        let line = "/\\\n/ return \\\r\nstill comment"
        let block = "/\\\r\n* outer /* inner *\\\n/"
        let source = line + "\rreturn " + block + " return // final"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "h")
        #expect(cParts(.comment, tokens, source) == [line, block, "// final"])
        #expect(cParts(.keyword, tokens, source) == ["return", "return"])
        #expect(cParts(.string, tokens, source).isEmpty)
        cRanges(tokens, source)
    }

    @Test func directivesUseLogicalLineStartsAndProtectHeaderNames() async throws {
        let source = " /* lead */ # include <return/*literal*/.h> // tail\n#define JOIN(a,b) a##b \\\n  + 1\nint value; #include <plain.h>\n#if true\n#endif\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "hpp")
        #expect(cParts(.reference, tokens, source) == ["#", "include", "#", "define", "#", "if", "#", "endif"])
        #expect(cParts(.string, tokens, source) == ["<return/*literal*/.h>"])
        #expect(cParts(.comment, tokens, source) == ["/* lead */", "// tail"])
        #expect(cParts(.keyword, tokens, source) == ["int"])
        cRanges(tokens, source)
    }

    @Test @MainActor func sourceAndHeaderAliasesReachTheExistingPreviewPipeline() async throws {
        let source = "#include \"sample.h\"\nint main() { return 0; }\n"
        let expected = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cpp")
        #expect(!expected.isEmpty)
        for ext in ["c", "h", "cc", "cpp", "cxx", "c++", "hh", "hpp", "hxx", "h++", "CPP"] {
            #expect(try await SyntaxHighlighting.tokens(in: source, fileName: "sample." + ext) == expected)
        }
        let state = PreviewState(read: { _ in .text(source) })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview/sample.H"), isDirectory: false), listingRevision: UUID()))
        #expect(state.preview == .text(source) && state.tokens == expected)
        for ext in ["txt", "m", "mm", "csx", "sass"] {
            #expect(try await SyntaxHighlighting.tokens(in: source, fileExtension: ext).isEmpty)
        }
    }

    @Test func largeIncompleteAndDigitSeparatorsKeepSafeRanges() async throws {
        let line = "const char* name = \"text\"; // comment\n"
        let source = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        #expect(source.utf8.count == TextPreview.maximumBytes)
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "cpp")
        #expect(!tokens.isEmpty)
        cRanges(tokens, source)
        let numbers = "1'000 0xFF'AB 1e+2 12return; return \"ok\""
        let numberTokens = try await SyntaxHighlighting.tokens(in: numbers, fileExtension: "cpp")
        #expect(cParts(.string, numberTokens, numbers) == [#""ok""#])
        #expect(cParts(.keyword, numberTokens, numbers) == ["return"])
        for text in ["", "#", "/*", "R\"", "R\"tag(", "u8\"\\", "'", "1'", "#include <", "\"" + String(repeating: "x", count: TextPreview.maximumBytes - 1)] {
            cRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: "cpp"), text)
        }
    }
}

private func cParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func cRanges(_ tokens: [SyntaxToken], _ text: String) {
    let length = text.utf16.count
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
