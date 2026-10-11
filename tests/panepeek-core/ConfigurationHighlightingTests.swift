import Foundation
import Testing
@testable import PanePeekCore

struct ConfigurationHighlightingTests {
    @Test func yamlKeysStringsLiteralsAndReferencesKeepTheirBoundaries() async throws {
        let text = "---\ndefaults: &base\n  name: \"Türkçe 👀 # value\"\n  enabled: true # comment\nitems: [{name: 'it''s fine', count: -12.5}, *base]\nurl: https://example.test/#anchor\n...\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "yaml")
        #expect(configParts(.key, tokens, text) == ["defaults", "name", "enabled", "items", "name", "count", "url"])
        #expect(configParts(.section, tokens, text) == ["---", "..."])
        #expect(configParts(.reference, tokens, text) == ["&base", "*base"])
        #expect(configParts(.literal, tokens, text) == ["true"])
        #expect(configParts(.number, tokens, text) == ["-12.5"])
        #expect(configParts(.string, tokens, text) == ["\"Türkçe 👀 # value\"", "'it''s fine'", "https://example.test/#anchor"])
        #expect(configParts(.comment, tokens, text) == ["# comment"])
        configRanges(tokens, text)
    }

    @Test func yamlBlockTextDoesNotBecomeKeysLiteralsOrComments() async throws {
        let text = "literal: |-\n  key: true # all string\n\nfolded: >+\n  first\n    nested\nnext: false\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "yml")
        #expect(configParts(.key, tokens, text) == ["literal", "folded", "next"])
        #expect(configParts(.string, tokens, text) == ["|-", "  key: true # all string", ">+", "  first", "    nested"])
        #expect(configParts(.literal, tokens, text) == ["false"])
        #expect(configParts(.comment, tokens, text).isEmpty)
        configRanges(tokens, text)
    }

    @Test func yamlQuotedKeysAndMultilineQuotesRemainWhole() async throws {
        let text = "'👀 key': \"first\nsecond # string\"\r\nempty: null\nflag: TRUE\nnumber: 0x2A\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "YAML")
        #expect(configParts(.key, tokens, text) == ["'👀 key'", "empty", "flag", "number"])
        #expect(configParts(.string, tokens, text) == ["\"first\nsecond # string\""])
        #expect(configParts(.literal, tokens, text) == ["null", "TRUE"])
        #expect(configParts(.number, tokens, text) == ["0x2A"])
        #expect(configParts(.comment, tokens, text).isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "yml") == tokens)
        configRanges(tokens, text)
    }

    @Test func tomlHeadersDottedKeysAndScalarValuesAreDistinct() async throws {
        let text = "# comment\ntitle = \"Türkçe 👀 # text\"\n[server]\nhost.name = 'localhost'\nport = 8080\nenabled = true\nratio = -1.2e+3\nstamp = 1979-05-27T07:32:00Z\n[[products]]\nname = \"other\"\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "toml")
        #expect(configParts(.key, tokens, text) == ["title", "host.name", "port", "enabled", "ratio", "stamp", "name"])
        #expect(configParts(.section, tokens, text) == ["[server]", "[[products]]"])
        #expect(configParts(.string, tokens, text) == ["\"Türkçe 👀 # text\"", "'localhost'", "\"other\""])
        #expect(configParts(.literal, tokens, text) == ["true", "1979-05-27T07:32:00Z"])
        #expect(configParts(.number, tokens, text) == ["8080", "-1.2e+3"])
        #expect(configParts(.comment, tokens, text) == ["# comment"])
        configRanges(tokens, text)
    }

    @Test func tomlMultilineStringsAndNestedArraysDoNotCreateHeaders() async throws {
        let text = "text = \"\"\"first\n# string\n\"\"\"\nraw = '''one\n# literal\n'''\n\"quoted.key\" = [\"#one\", 'two']\narray = [\n  [1, 2],\n  { nested.key = false }\n]\nend = true\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "TOML")
        #expect(configParts(.key, tokens, text) == ["text", "raw", "\"quoted.key\"", "array", "nested.key", "end"])
        #expect(configParts(.section, tokens, text).isEmpty)
        #expect(configParts(.string, tokens, text) == ["\"\"\"first\n# string\n\"\"\"", "'''one\n# literal\n'''", "\"#one\"", "'two'"])
        #expect(configParts(.comment, tokens, text).isEmpty)
        #expect(configParts(.literal, tokens, text) == ["false", "true"])
        configRanges(tokens, text)
    }

    @Test func tomlNumbersDoNotColourPartialOrMalformedValues() async throws {
        let text = "values = [0xDEAD_BEEF, 0o755, 0b1010, 1_000, -2, +3.14, 1e6, +inf, -nan, 01, 1_, 1e, +0xFF, TrUE]\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "toml")
        #expect(configParts(.number, tokens, text) == ["0xDEAD_BEEF", "0o755", "0b1010", "1_000", "-2", "+3.14", "1e6", "+inf", "-nan"])
        #expect(configParts(.literal, tokens, text).isEmpty)
        configRanges(tokens, text)
    }

    @Test func incompleteAndUnsupportedConfigurationTextHasSafeRanges() async throws {
        for language in ["yaml", "toml"] {
            for text in ["", "key: \"unfinished 👀", "key = '''unfinished", "[incomplete", "value: |\n", "# comment\r\n"] {
                let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: language)
                configRanges(tokens, text)
                #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
            }
        }
    }

    @Test func yamlPlainScalarsAndExplicitBlockIndentationStayStrings() async throws {
        let text = "description: true story\ncount: 12 monkeys\nblock: |2-\n  first\n   second\nnext: ~\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "yaml")
        #expect(configParts(.key, tokens, text) == ["description", "count", "block", "next"])
        #expect(configParts(.literal, tokens, text) == ["~"])
        #expect(configParts(.number, tokens, text).isEmpty)
        #expect(configParts(.string, tokens, text) == ["true story", "12 monkeys", "|2-", "  first", "   second"])
        configRanges(tokens, text)
    }

    @Test func tomlTrailingQuotesStayInsideMultilineStrings() async throws {
        let text = "a = \"\"\"one\"\"\"\"\nb = '''two'''''\nnext = true\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "toml")
        #expect(configParts(.key, tokens, text) == ["a", "b", "next"])
        #expect(configParts(.string, tokens, text) == ["\"\"\"one\"\"\"\"", "'''two'''''"])
        #expect(configParts(.literal, tokens, text) == ["true"])
        configRanges(tokens, text)
    }

    @Test func largeConfigurationsAndLongInvalidScalarsHaveSafeRanges() async throws {
        for (language, line) in [("yaml", "name: value\nflag: true\n"), ("toml", "name = 'value'\nflag = true\n")] {
            let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: language)
            #expect(tokens.count > 50_000)
            configRanges(tokens, text)
            let scalar = "value" + (language == "yaml" ? ": " : " = ") + String(repeating: "1", count: 100_000) + "x"
            let scalarTokens = try await SyntaxHighlighting.tokens(in: scalar, fileExtension: language)
            #expect(configParts(.number, scalarTokens, scalar).isEmpty)
            configRanges(scalarTokens, scalar)
        }
    }
}

private func configParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func configRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
