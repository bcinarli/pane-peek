import Foundation
import Testing
@testable import PanePeekCore

struct JavaScriptHighlightingTests {
    @Test func keywordsStayOutsideStringsCommentsAndIdentifierParts() async throws {
        let text = "const café👀 = 'return // text'; let $returning = \"if \\\"quoted\\\"\";\r\n/* let /* inner */ return café👀; // const\nobj.default; constValue;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(jsParts(.keyword, tokens, text) == ["const", "let", "return"])
        #expect(jsParts(.string, tokens, text) == ["'return // text'", "\"if \\\"quoted\\\"\""])
        #expect(jsParts(.comment, tokens, text) == ["/* let /* inner */", "// const"])
        jsRanges(tokens, text)
    }

    @Test func templateStringsKeepNestedExpressionsAndEscapesInsideTheirBoundary() async throws {
        let template = #"`Türkçe 👀 \` ${format({value: `nested ${"}"}`}) /* } */} ${/[}/*]/.test('}')} tail`"#
        let text = "const message = " + template + ";\nreturn message;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(jsParts(.keyword, tokens, text) == ["const", "return"])
        #expect(jsParts(.string, tokens, text) == [template])
        #expect(jsParts(.comment, tokens, text).isEmpty)
        jsRanges(tokens, text)
    }

    @Test func regexClassesEscapesAndControlConditionsDoNotBecomeCommentsOrDivision() async throws {
        let text = #"const pattern = /[/*]let\/return/g; if (ready) /a\/b/.test(value); const ratio = total / count / scale; function f() { return /true/.test(value); } /after/.test(value); const object = {} / divisor; // real"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(jsParts(.string, tokens, text) == [#"/[/*]let\/return/g"#, #"/a\/b/"#, "/true/", "/after/"])
        #expect(jsParts(.comment, tokens, text) == ["// real"])
        #expect(jsParts(.keyword, tokens, text) == ["const", "if", "const", "function", "return", "const"])
        jsRanges(tokens, text)
    }

    @Test func typeScriptAddsTypeWordsWithoutChangingJavaScriptBoundaries() async throws {
        let text = "export interface Person { readonly name: string; count: number }\ntype Keys<T> = keyof T; const person = null satisfies Person; let value: unknown = true;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "TS")
        #expect(jsParts(.keyword, tokens, text) == ["export", "interface", "readonly", "string", "number", "type", "keyof", "const", "satisfies", "let", "unknown"])
        #expect(jsParts(.literal, tokens, text) == ["null", "true"])
        let js = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(!jsParts(.keyword, js, text).contains("interface"))
        for ext in ["mts", "cts"] {
            #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: ext) == tokens)
        }
        for ext in ["mjs", "cjs"] {
            #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: ext) == js)
        }
        jsRanges(tokens, text)
    }

    @Test func hashbangUnicodeLineEndsAndIncompleteStringsRemainReadable() async throws {
        let text = "#!/usr/bin/env node\n// comment\u{2028}const value = 'unfinished\u{2029}return value; /* unfinished"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(jsParts(.keyword, tokens, text) == ["const", "return"])
        #expect(jsParts(.string, tokens, text) == ["'unfinished"])
        #expect(jsParts(.comment, tokens, text) == ["#!/usr/bin/env node", "// comment", "/* unfinished"])
        for source in ["", "const x = `unfinished ${", "const x = /[unfinished", "\"unfinished 👀"] {
            jsRanges(try await SyntaxHighlighting.tokens(in: source, fileExtension: "js"), source)
            #expect(try await SyntaxHighlighting.tokens(in: source, fileExtension: "txt").isEmpty)
            #expect(try await SyntaxHighlighting.tokens(in: source, fileExtension: "sass").isEmpty)
        }
        jsRanges(tokens, text)
    }

    @Test func numericLiteralsDoNotSplitIdentifierLikeOrMalformedValues() async throws {
        let text = "const values = [0xFFn, 0b1010, 0o755, 1_000n, .5, 1.2e+3, 1., 12abc, 1__0, 1e];"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(jsParts(.number, tokens, text) == ["0xFFn", "0b1010", "0o755", "1_000n", ".5", "1.2e+3", "1."])
        jsRanges(tokens, text)
    }

    @Test func largeAndDeepTemplateSourceTerminatesWithSafeRanges() async throws {
        let line = "const value = `text ${name}`; // comment\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "ts")
        #expect(tokens.count > 50_000)
        jsRanges(tokens, text)
        let deep = "const value = " + String(repeating: "`${", count: 80) + "name" + String(repeating: "}`", count: 80)
        let deepTokens = try await SyntaxHighlighting.tokens(in: deep, fileExtension: "js")
        #expect(deepTokens.count == 2)
        jsRanges(deepTokens, deep)
        let invalidNumber = "const value = " + String(repeating: "1", count: 100_000) + "x; return value"
        let invalidTokens = try await SyntaxHighlighting.tokens(in: invalidNumber, fileExtension: "js")
        #expect(jsParts(.number, invalidTokens, invalidNumber).isEmpty)
        #expect(jsParts(.keyword, invalidTokens, invalidNumber) == ["const", "return"])
        jsRanges(invalidTokens, invalidNumber)
    }

    @Test func unaryPlusDoesNotSkipTheFollowingString() async throws {
        let text = "const value = +\"text\"; const ratio = count++ / scale;"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(jsParts(.string, tokens, text) == ["\"text\""])
        #expect(jsParts(.keyword, tokens, text) == ["const", "const"])
        jsRanges(tokens, text)
        for source in ["+", "-", "++", "--", "const x = +", "const x = -"] {
            jsRanges(try await SyntaxHighlighting.tokens(in: source, fileExtension: "js"), source)
        }
    }

    @Test func escapedAndPrivateIdentifiersAndPropertyWordsRemainPlain() async throws {
        let text = #"let \u0069f = 1; obj.return / divisor; obj?.class; const $true = null; class Example { #return = true }"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "js")
        #expect(jsParts(.keyword, tokens, text) == ["let", "const", "class"])
        #expect(jsParts(.literal, tokens, text) == ["null", "true"])
        #expect(jsParts(.string, tokens, text).isEmpty)
        jsRanges(tokens, text)
    }
}

private func jsParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func jsRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
