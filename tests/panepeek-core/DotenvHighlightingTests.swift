import Foundation
import Testing
@testable import PanePeekCore

struct DotenvHighlightingTests {
    @Test(arguments: [".env", ".env.local", ".env.development", ".env.example", "/project/.env.production.local"])
    func dotenvNamesSelectTheDotenvFormat(name: String) {
        #expect(SyntaxDetection.language(forFileName: name) == .dotenv)
    }

    @Test(arguments: [(".env.json", SyntaxLanguage.json), (".env.sh", .shell), (".env.yaml", .yaml),
                      (".ENV", .plainText), (".env.", .plainText), ("app.env", .plainText), (".envrc", .plainText)])
    func knownExtensionsAndLookalikesKeepTheirTreatment(name: String, expected: SyntaxLanguage) {
        #expect(SyntaxDetection.language(forFileName: name) == expected)
    }

    @Test func keysPrefixesValuesAndCommentsKeepTheirBoundaries() async throws {
        let text = "# Settings\r\nexport API_URL = https://example.test/#anchor # trailing\nEMPTY=\n  SPACED_KEY  =  spaced value  \nURL_REF=${API_URL}/v1\nexported=1\nexport\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env")
        #expect(envParts(.comment, tokens, text) == ["# Settings", "#anchor # trailing"])
        #expect(envParts(.keyword, tokens, text) == ["export"])
        #expect(envParts(.key, tokens, text) == ["API_URL", "EMPTY", "SPACED_KEY", "URL_REF", "exported"])
        #expect(envParts(.string, tokens, text) == ["https://example.test/", "spaced value", "${API_URL}/v1", "1"])
        envRanges(tokens, text)
    }

    @Test func quotedValuesKeepHashesAndMaySpanLines() async throws {
        let text = "A=\"# not a comment\" # comment\nB='single # value'\nC=\"line one\nline two\" # after\nD='first\r\nsecond'\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env.local")
        #expect(envParts(.string, tokens, text) == ["\"# not a comment\"", "'single # value'", "\"line one\nline two\"",
                                                     "'first\r\nsecond'"])
        #expect(envParts(.comment, tokens, text) == ["# comment", "# after"])
        #expect(envParts(.key, tokens, text) == ["A", "B", "C", "D"])
        envRanges(tokens, text)
    }

    @Test func keysAreAnyTextBeforeTheSeparatorAsNodeReadsThem() async throws {
        let text = "1DIGIT=one\nmy-var=two\nMY KEY = three\nNO_EQUALS\n=value\nexport\tTAB=four\nexport =five\nexport  SPACED=six\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env")
        #expect(envParts(.key, tokens, text) == ["1DIGIT", "my-var", "MY KEY", "export\tTAB", "export", "SPACED"])
        #expect(envParts(.keyword, tokens, text) == ["export"])
        #expect(envParts(.string, tokens, text) == ["one", "two", "three", "four", "five", "six"])
        envRanges(tokens, text)
    }

    @Test func unterminatedQuotesKeepTheRestOfTheLine() async throws {
        let text = "OPEN=\"unterminated  \nNEXT=still open\nTICK=`draft"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env")
        #expect(envParts(.key, tokens, text) == ["OPEN", "NEXT", "TICK"])
        #expect(envParts(.string, tokens, text) == ["\"unterminated", "still open", "`draft"])
        envRanges(tokens, text)
    }

    @Test func aLaterQuotePairsAcrossLinesAsNodeReadsIt() async throws {
        let text = "A=\"x\nB=\"y # rest\nC='z\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env")
        #expect(envParts(.key, tokens, text) == ["A", "C"])
        #expect(envParts(.string, tokens, text) == ["\"x\nB=\"", "'z"])
        #expect(envParts(.comment, tokens, text).isEmpty)
        envRanges(tokens, text)
    }

    @Test func backtickQuotesKeepHashesAndMaySpanLines() async throws {
        let text = "A=`tick # kept` # comment\nB=`multi\nline`\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env")
        #expect(envParts(.string, tokens, text) == ["`tick # kept`", "`multi\nline`"])
        #expect(envParts(.comment, tokens, text) == ["# comment"])
        envRanges(tokens, text)
    }

    @Test func onlyLineFeedsEndLinesBecauseNodeRemovesCarriageReturns() async throws {
        let text = "A=one\rB=two\nC=x\r#c\r\n\r# comment\r\nD=\r\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env")
        #expect(envParts(.key, tokens, text) == ["A", "C", "D"])
        #expect(envParts(.string, tokens, text) == ["one\rB=two", "x"])
        #expect(envParts(.comment, tokens, text) == ["#c", "# comment"])
        envRanges(tokens, text)
    }


    @Test func unicodeValuesKeepUTF16Ranges() async throws {
        let text = "\u{FEFF}GREETING=héllo 👀 # emoji ✓\nNAME='ünïcode'\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".env")
        #expect(envParts(.string, tokens, text) == ["héllo 👀", "'ünïcode'"])
        #expect(envParts(.comment, tokens, text) == ["# emoji ✓"])
        envRanges(tokens, text)
    }
}

private func envParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func envRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        end = token.range.location + token.range.length
    }
    #expect(end <= (text as NSString).length)
}
