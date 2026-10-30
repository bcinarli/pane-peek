import Foundation
import Testing
@testable import PanePeekCore

struct StructuredConfigurationHighlightingTests {
    @Test(arguments: [".prettierrc", ".stylelintrc", ".gemrc"])
    func extensionlessYamlSupportsBlockAndFlowMappings(name: String) async throws {
        let text = "# config\nlabel: \"Türkçe 👀\"\noptions: {enabled: true, count: 4}\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: name)
        #expect(structuredParts(.key, tokens, text) == ["label", "options", "enabled", "count"])
        #expect(structuredParts(.string, tokens, text) == ["\"Türkçe 👀\""])
        #expect(structuredParts(.literal, tokens, text) == ["true"])
        #expect(structuredParts(.number, tokens, text) == ["4"])
        #expect(structuredParts(.comment, tokens, text) == ["# config"])
        #expect(tokens == (try await SyntaxHighlighting.tokens(in: text, fileExtension: "yaml")))
        structuredRanges(tokens, text)
    }

    @Test func jsonCompatibleFlowMappingsDoNotRequireContentGuessing() async throws {
        let text = #"{"semi":false,"overrides":[{"files":"*.js","options":{"tabWidth":4}}]}"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".prettierrc")
        #expect(structuredParts(.key, tokens, text) == [#""semi""#, #""overrides""#, #""files""#, #""options""#, #""tabWidth""#])
        #expect(structuredParts(.literal, tokens, text) == ["false"])
        #expect(structuredParts(.number, tokens, text) == ["4"])
        structuredRanges(tokens, text)
    }

    @Test func rubyGemsSymbolKeysRemainYamlKeys() async throws {
        let text = ":sources:\n- https://rubygems.org/\n:backtrace: true\n:concurrent_downloads: 16\ninstall: --no-document\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".gemrc")
        #expect(structuredParts(.key, tokens, text) == [":sources", ":backtrace", ":concurrent_downloads", "install"])
        #expect(structuredParts(.literal, tokens, text) == ["true"])
        #expect(structuredParts(.number, tokens, text) == ["16"])
        #expect(structuredParts(.string, tokens, text) == ["https://rubygems.org/", "--no-document"])
        structuredRanges(tokens, text)
    }

    @Test func legacyEslintCommentsDoNotLeakIntoValuesOrOtherYaml() async throws {
        let text = "/* config 👀 */\nenv: {browser: true/* inline */}\n# yaml\nlabel: \"https://example.test/* string */\"\n// next\nrules: {eqeqeq: 2}\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".eslintrc")
        #expect(structuredParts(.comment, tokens, text) == ["/* config 👀 */", "/* inline */", "# yaml", "// next"])
        #expect(structuredParts(.key, tokens, text) == ["env", "browser", "label", "rules", "eqeqeq"])
        #expect(structuredParts(.literal, tokens, text) == ["true"])
        #expect(structuredParts(.number, tokens, text) == ["2"])
        #expect(structuredParts(.string, tokens, text) == ["\"https://example.test/* string */\""])
        let yaml = try await SyntaxHighlighting.tokens(in: "url: https://example.test/ // plain scalar", fileExtension: "yaml")
        #expect(structuredParts(.comment, yaml, "url: https://example.test/ // plain scalar").isEmpty)
        structuredRanges(tokens, text)
    }

    @Test func commentedJsonKeepsStrictNumbersAndOrdinaryJsonUnchanged() async throws {
        let text = "{\"enabled\":true/* after literal */,\"count\":2,// comment\n\"invalid\":[01,1.,1e,+1,.1,0x2a,trueValue],\"url\":\"https://example.test/\"}"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".eslintrc.json")
        #expect(structuredParts(.comment, tokens, text) == ["/* after literal */", "// comment"])
        #expect(structuredParts(.number, tokens, text) == ["2"])
        #expect(structuredParts(.literal, tokens, text) == ["true"])
        #expect(structuredParts(.key, tokens, text) == ["\"enabled\"", "\"count\"", "\"invalid\"", "\"url\""])
        #expect(tokens == (try await SyntaxHighlighting.tokens(in: text, fileExtension: "jsonc")))
        let ordinary = try await SyntaxHighlighting.tokens(in: "[01,1.,1e,+1,.1,0x2a,trueValue,2,true]", fileName: "package.json")
        #expect(structuredParts(.number, ordinary, "[01,1.,1e,+1,.1,0x2a,trueValue,2,true]") == ["2"])
        #expect(SyntaxDetection.language(forFileName: "other.babelrc.json") == .json)
        structuredRanges(tokens, text)
    }

    @Test func legacyEslintCommentsBeforeColonsKeepKeysAndCommentsSeparate() async throws {
        let text = "{env /* note 👀 */ : {browser: true}, \"rules\" // note\r\n : {eqeqeq: 2}, after:/* value */false}"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".eslintrc")
        #expect(structuredParts(.key, tokens, text) == ["env", "browser", "\"rules\"", "eqeqeq", "after"])
        #expect(structuredParts(.comment, tokens, text) == ["/* note 👀 */", "// note", "/* value */"])
        #expect(structuredParts(.literal, tokens, text) == ["true", "false"])
        #expect(structuredParts(.number, tokens, text) == ["2"])
        structuredRanges(tokens, text)
    }

    @Test func legacyEslintCommentLookaheadRequiresAColonAndPreservesYamlRules() async throws {
        let text = "name /* incomplete 👀\nnext: true"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".eslintrc")
        #expect(structuredParts(.key, tokens, text).isEmpty)
        #expect(structuredParts(.comment, tokens, text) == ["/* incomplete 👀\nnext: true"])
        structuredRanges(tokens, text)
        let yaml = "env /* literal key */: true\n"
        let ordinary = try await SyntaxHighlighting.tokens(in: yaml, fileExtension: "yaml")
        #expect(structuredParts(.key, ordinary, yaml) == ["env /* literal key */"])
        #expect(structuredParts(.comment, ordinary, yaml).isEmpty)
    }

    @Test(arguments: [".babelrc", ".babelrc.json", "babel.config.json", ".prettierrc.json5", "settings.json5"])
    func json5HighlightsDataWithoutJavascriptInterpretation(name: String) async throws {
        let text = "{// config\n café: '👀 // string', values: [+0x2a, -.5, 1., 2e+3, Infinity, -NaN, true, null], true: false, /* key */ presets: ['env'], expression: function() }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: name)
        #expect(structuredParts(.key, tokens, text) == ["café", "values", "true", "presets", "expression"])
        #expect(structuredParts(.string, tokens, text) == ["'👀 // string'", "'env'"])
        #expect(structuredParts(.number, tokens, text) == ["+0x2a", "-.5", "1.", "2e+3", "Infinity", "-NaN"])
        #expect(structuredParts(.literal, tokens, text) == ["true", "null", "false"])
        #expect(structuredParts(.comment, tokens, text) == ["// config", "/* key */"])
        #expect(structuredParts(.keyword, tokens, text).isEmpty)
        structuredRanges(tokens, text)
    }

    @Test func incompleteStringsCommentsAndNumbersKeepSafeBoundaries() async throws {
        let text = "{line: 'first\\\r\nsecond', broken: [01, 1e, +0x, 12x, trueValue], next: 'unfinished 👀"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".babelrc")
        #expect(structuredParts(.string, tokens, text) == ["'first\\\r\nsecond'", "'unfinished 👀"])
        #expect(structuredParts(.number, tokens, text).isEmpty)
        #expect(structuredParts(.literal, tokens, text).isEmpty)
        structuredRanges(tokens, text)
        for name in [".babelrc", ".eslintrc", ".eslintrc.json"] {
            let comment = "/* unfinished 👀\ntrue"
            let result = try await SyntaxHighlighting.tokens(in: comment, fileName: name)
            #expect(structuredParts(.comment, result, comment) == [comment])
            structuredRanges(result, comment)
        }
        for name in [".customrc", ".BABELRC", ".prettierrc.backup", ".gemrc-local"] {
            #expect(try await SyntaxHighlighting.tokens(in: text, fileName: name).isEmpty)
        }
    }

    @Test func json5UnicodeSeparatorsAndEscapedKeysKeepTheirBoundaries() async throws {
        let text = "{\\u0061 /* key */ : 'first\u{2028}second\u{2029}👀', // end\u{2028}next: true}"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".babelrc")
        #expect(structuredParts(.key, tokens, text) == ["\\u0061", "next"])
        #expect(structuredParts(.string, tokens, text) == ["'first\u{2028}second\u{2029}👀'"])
        #expect(structuredParts(.comment, tokens, text) == ["/* key */", "// end"])
        #expect(structuredParts(.literal, tokens, text) == ["true"])
        structuredRanges(tokens, text)
    }

    @Test(arguments: [".prettierrc", ".eslintrc", ".eslintrc.json", ".babelrc"])
    @MainActor func previewAndDraftUseTheSameFormatWithoutChangingSavedBytes(name: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent(name)
        let yaml = name == ".prettierrc"
        let original = yaml ? "# load\r\nenabled: true\r\n" : "// load\r\n{\"enabled\":true}\r\n"
        let draft = yaml ? "# draft\r\nenabled: false\r\n" : "// draft\r\n{\"enabled\":false}\r\n"
        let bom = Data([0xef, 0xbb, 0xbf])
        try (bom + Data(original.utf8)).write(to: file)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID()))
        #expect(structuredParts(.literal, state.tokens, original) == ["true"])
        let document = state.documentID
        state.setMode(.edit)
        await state.updateText(draft)?.value
        state.setMode(.preview)
        state.setMode(.edit)
        #expect(state.documentID == document && state.isDirty && state.text == draft)
        #expect(structuredParts(.comment, state.tokens, draft) == [yaml ? "# draft" : "// draft"])
        #expect(structuredParts(.literal, state.tokens, draft) == ["false"])
        #expect(try Data(contentsOf: file) == bom + Data(original.utf8))
        await state.save()
        #expect(!state.isDirty && state.errorMessage == nil)
        #expect(try Data(contentsOf: file) == bom + Data(draft.utf8))
    }

    @Test func largeJson5AndLongInvalidScalarsHaveBoundedRanges() async throws {
        let line = "{name: 'value', enabled: true},\n"
        let text = "[" + String(repeating: line, count: 30_000) + "]"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".babelrc")
        #expect(tokens.count > 100_000)
        structuredRanges(tokens, text)
        let invalid = "[" + String(repeating: "1", count: 100_000) + "x]"
        let result = try await SyntaxHighlighting.tokens(in: invalid, fileName: ".babelrc")
        #expect(structuredParts(.number, result, invalid).isEmpty)
    }
}

private func structuredParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func structuredRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
