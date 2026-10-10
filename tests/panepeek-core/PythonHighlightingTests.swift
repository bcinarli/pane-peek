import Foundation
import Testing
@testable import PanePeekCore

struct PythonHighlightingTests {
    @Test func keywordsLiteralsAndUnicodeNamesKeepTheirBoundaries() async throws {
        let text = "async def greet(name): await run(); if True and name is not None: return False\nmatch name: case _: pass\ntype Alias = str; lazy import sample\nReturn returning returnç returń return२ return𐐀 _return 👀return false true none"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "PY")
        #expect(pythonParts(.keyword, tokens, text) == ["async", "def", "await", "if", "and", "is", "not", "return", "match", "case", "_", "pass", "type", "lazy", "import", "return"])
        #expect(pythonParts(.literal, tokens, text) == ["True", "None", "False"])
        pythonRanges(tokens, text)
    }

    @Test func ordinaryRawAndBytesStringsProtectQuotesAndLineContinuations() async throws {
        let strings = [#""hello \"return\" # 👀""#, #"'it\'s True'"#, #"r"\" # return""#, #"BR'bytes\\path'"#, #"u"legacy""#, "\"line\\\r\ncontinued\""]
        let text = strings.joined(separator: "; ") + "; return \"unfinished\\\rreturn True"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
        #expect(pythonParts(.string, tokens, text) == strings + ["\"unfinished\\\rreturn True"])
        #expect(pythonParts(.keyword, tokens, text) == ["return"])
        #expect(pythonParts(.comment, tokens, text).isEmpty)
        pythonRanges(tokens, text)
        let recovery = "'unfinished\rreturn True\n\"unfinished\nreturn False"
        let recovered = try await SyntaxHighlighting.tokens(in: recovery, fileExtension: "py")
        #expect(pythonParts(.string, recovered, recovery) == ["'unfinished", "\"unfinished"])
        #expect(pythonParts(.keyword, recovered, recovery) == ["return", "return"])
        #expect(pythonParts(.literal, recovered, recovery) == ["True", "False"])
    }

    @Test func tripleQuotedStringsRetainInnerQuotesCommentsAndNewlines() async throws {
        let strings = ["\"\"\"return \"quoted\" # 👀\r\nnext\"\"\"", "'''if 'quoted' # True\nnext'''", "r\"\"\"" + #"escaped \""" protected"# + "\n\"\"\""]
        let incomplete = "b'''\nreturn False 👀"
        let text = strings.joined(separator: "; return ") + "; return " + incomplete
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
        #expect(pythonParts(.string, tokens, text) == strings + [incomplete])
        #expect(pythonParts(.keyword, tokens, text) == ["return", "return", "return"])
        #expect(pythonParts(.comment, tokens, text).isEmpty)
        pythonRanges(tokens, text)
    }

    @Test func formattedAndTemplateStringsKeepNestedExpressionsInsideTheirString() async throws {
        let strings = [
            #"f"hello {data["name"]} {{return}}""#,
            #"RF'{ {"key": "value}"} } {f'{name}'}'"#,
            "f\"value {name # }\\\" return\n + other}\"",
            #"f'{value!r:>{width}.{precision}f}'"#,
            #"t"{data["name"]!s}""#,
            #"Tr"template {name}""#
        ]
        let text = strings.joined(separator: "; return ") + "; return True"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
        #expect(pythonParts(.string, tokens, text) == strings)
        #expect(pythonParts(.keyword, tokens, text) == Array(repeating: "return", count: strings.count))
        #expect(pythonParts(.literal, tokens, text) == ["True"])
        #expect(pythonParts(.comment, tokens, text).isEmpty)
        pythonRanges(tokens, text)
    }

    @Test func commentsEndAtPhysicalNewlinesWithoutContinuingThroughBackslashes() async throws {
        let comments = ["#!/usr/bin/env python3", "# return \"fake\"\\", "# note\u{2028}return", "# tail"]
        let text = comments[0] + "\r\nreturn " + comments[1] + "\rreturn " + comments[2] + "\nreturn " + comments[3]
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
        #expect(pythonParts(.comment, tokens, text) == comments)
        #expect(pythonParts(.keyword, tokens, text) == ["return", "return", "return"])
        #expect(pythonParts(.string, tokens, text).isEmpty)
        pythonRanges(tokens, text)
    }

    @Test func numericFormsDistinguishInvalidRunsAndImaginaryMemberAccess() async throws {
        let values = ["0", "00_0", "42", "4_2", "0b_10_01", "0o_77", "0xCAFE_BABE", ".25", "1.", "01.25", "1e+2", "1e-2", "1_0.2_5E+3", "42j", "01J", ".5j", "1.e2J"]
        let invalid = ["42_", "4__2", "0_x1", "0x__1", "0b2", "09", "1e+", "1._2", "1_.2", "0x1j", "12abc", "12ç"]
        let text = values.joined(separator: ", ") + "; " + invalid.joined(separator: ", ") + "; 1j.real; 0x15e-2; 1e+2+3; return"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
        #expect(pythonParts(.number, tokens, text) == values + ["1j", "0x15e", "2", "1e+2", "3"])
        #expect(pythonParts(.keyword, tokens, text) == ["return"])
        pythonRanges(tokens, text)
    }

    @Test func prefixesEscapedBracesAndFormatTextKeepLocalBoundaries() async throws {
        let strings = [
            #"f"\{data["name"]}""#,
            #"f"\N{LEFT CURLY BRACKET} {name}""#,
            #"rf"\N{data["name"]}""#,
            #"f"{value:'>{width}}""#,
            #"f"{(lambda x: x)(1)}""#,
            #"r"\\""#,
            #"Rt'{value}'"#
        ]
        let text = strings.joined(separator: "; return ") + "; return ur'plain'; bf\"plain\"; f_name'plain'; value.type; value. # comment\ntype; type Alias = str"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
        #expect(pythonParts(.string, tokens, text) == strings + ["'plain'", "\"plain\"", "'plain'"])
        #expect(pythonParts(.keyword, tokens, text) == Array(repeating: "return", count: strings.count) + ["type"])
        #expect(pythonParts(.comment, tokens, text) == ["# comment"])
        pythonRanges(tokens, text)
    }

    @Test func longSingleTokensNamesAndNumericRunsStayBounded() async throws {
        for prefix in ["\"", "#", "'''", "f'{name #"] {
            let text = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
            #expect(tokens.count == 1)
            #expect(tokens.first?.range == NSRange(location: 0, length: text.utf16.count))
            pythonRanges(tokens, text)
        }
        let digits = String(repeating: "1", count: 100_000)
        for number in [digits, "0x" + digits, digits + ".0e+2j"] {
            let tokens = try await SyntaxHighlighting.tokens(in: number, fileExtension: "py")
            #expect(pythonParts(.number, tokens, number) == [number])
            pythonRanges(tokens, number)
        }
        let invalid = digits + "_x; return"
        let invalidTokens = try await SyntaxHighlighting.tokens(in: invalid, fileExtension: "py")
        #expect(pythonParts(.number, invalidTokens, invalid).isEmpty)
        #expect(pythonParts(.keyword, invalidTokens, invalid) == ["return"])
        let identifier = "return" + String(repeating: "𐐀", count: 100_000)
        #expect(try await SyntaxHighlighting.tokens(in: identifier, fileExtension: "py").isEmpty)
        let braces = "f'{" + String(repeating: "(", count: 100_000) + "'return'"
        pythonRanges(try await SyntaxHighlighting.tokens(in: braces, fileExtension: "py"), braces)
    }

    @Test func largeIncompleteAndUnsupportedSourceHasSafeRanges() async throws {
        let line = "if True: return \"value\" # preview note\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        #expect(text.utf8.count == TextPreview.maximumBytes)
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "py")
        #expect(tokens.count > 50_000)
        pythonRanges(tokens, text)
        for source in ["", "#", "'", "\"\\", "'''", "r\"", "f'{", "f'{name # }'", "f'{({", "t'{", "0x", "."] {
            pythonRanges(try await SyntaxHighlighting.tokens(in: source, fileExtension: "py"), source)
        }
        let deep = String(repeating: "f'{", count: 100) + "name" + String(repeating: "}'", count: 100)
        pythonRanges(try await SyntaxHighlighting.tokens(in: deep, fileExtension: "py"), deep)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sass").isEmpty)
    }
}

private func pythonParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func pythonRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
