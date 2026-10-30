import Foundation
import Testing
@testable import PanePeekCore

struct KeyValueConfigurationHighlightingTests {
    @Test(arguments: [".gitconfig", ".editorconfig", ".npmrc", ".yarnrc"])
    func conventionalNamesSelectTheirOwnFormat(name: String) async throws {
        let text = name == ".yarnrc" ? "enabled true\n" : "enabled = true\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: "/project/" + name)
        #expect(SyntaxDetection.language(forFileName: name) != .plainText)
        #expect(keyValueParts(.key, tokens, text) == ["enabled"])
        #expect(keyValueParts(.literal, tokens, text) == ["true"])
    }

    @Test func gitHeadersQuotesAndCommentsKeepTheirBoundaries() async throws {
        let text = "# header\r\n[remote \"origin#;]\"] ; remote\r\n url = \"https://example.test/#fragment\" # inline\r\n bare\r\n autocrlf = FALSE\r\n buffer = -2k\r\n command = prefix\"# quoted\"suffix; tail\r\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".gitconfig")
        #expect(keyValueParts(.section, tokens, text) == ["[remote \"origin#;]\"]"])
        #expect(keyValueParts(.key, tokens, text) == ["url", "bare", "autocrlf", "buffer", "command"])
        #expect(keyValueParts(.string, tokens, text) == ["\"https://example.test/#fragment\"", "prefix\"# quoted\"suffix"])
        #expect(keyValueParts(.literal, tokens, text) == ["FALSE"])
        #expect(keyValueParts(.number, tokens, text) == ["-2k"])
        #expect(keyValueParts(.comment, tokens, text) == ["# header", "; remote", "# inline", "; tail"])
        keyValueRanges(tokens, text)
    }

    @Test func gitContinuationsDoNotTurnValueLinesIntoSettings() async throws {
        let text = "[alias]\n run = first\\\r\n  second \"# value\"\\\n  third # tail\n next = true\n broken = \"unfinished 👀\n after = false\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".gitconfig")
        #expect(keyValueParts(.key, tokens, text) == ["run", "next", "broken", "after"])
        #expect(keyValueParts(.string, tokens, text) == ["first\\\r\n  second \"# value\"\\\n  third", "\"unfinished 👀"])
        #expect(keyValueParts(.literal, tokens, text) == ["true", "false"])
        #expect(keyValueParts(.comment, tokens, text) == ["# tail"])
        keyValueRanges(tokens, text)
    }

    @Test func editorConfigKeepsGlobHeadersAndInlineMarkersWhole() async throws {
        let text = "; header\nroot = TRUE\n[lib/[ab]/*.{swift,md}]\nindent_size = 4\ncustom = value # still ; value\nquoted = \"# ordinary text\"\n[files=name#;.txt]\ntrim_trailing_whitespace = false\nend_of_line = unset\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".editorconfig")
        #expect(keyValueParts(.section, tokens, text) == ["[lib/[ab]/*.{swift,md}]", "[files=name#;.txt]"])
        #expect(keyValueParts(.key, tokens, text) == ["root", "indent_size", "custom", "quoted", "trim_trailing_whitespace", "end_of_line"])
        #expect(keyValueParts(.comment, tokens, text) == ["; header"])
        #expect(keyValueParts(.string, tokens, text) == ["value # still ; value", "\"# ordinary text\""])
        #expect(keyValueParts(.literal, tokens, text) == ["TRUE", "false", "unset"])
        #expect(keyValueParts(.number, tokens, text) == ["4"])
        keyValueRanges(tokens, text)
    }

    @Test func npmScopedKeysArraysQuotesAndEscapesRemainIni() async throws {
        let text = "# header\n; npm\n@scope:registry = \"https://example.test/#part\"\nlist[] = 'a#;b'\ncache = ${CACHE_DIR}/npm\nstrict-ssl = true\ncount = 16\nflag\n//registry.example.test/:always-auth=false\nescaped = a\\#b\\;c ; tail\n[section]\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".npmrc")
        #expect(keyValueParts(.key, tokens, text) == ["@scope:registry", "list[]", "cache", "strict-ssl", "count", "flag", "//registry.example.test/:always-auth", "escaped"])
        #expect(keyValueParts(.section, tokens, text) == ["[section]"])
        #expect(keyValueParts(.string, tokens, text) == ["\"https://example.test/#part\"", "'a#;b'", "${CACHE_DIR}/npm", "a\\#b\\;c"])
        #expect(keyValueParts(.literal, tokens, text) == ["true", "false"])
        #expect(keyValueParts(.number, tokens, text) == ["16"])
        #expect(keyValueParts(.comment, tokens, text) == ["# header", "; npm", "; tail"])
        keyValueRanges(tokens, text)
    }

    @Test func npmQuotedWholeValuesAndUnquotedCommentRecoveryAreDistinct() async throws {
        let text = "whole = \"a#b\"\ntrailing = \"a#b\" # tail\nnext = false\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".npmrc")
        #expect(keyValueParts(.string, tokens, text) == ["\"a#b\"", "\"a"])
        #expect(keyValueParts(.comment, tokens, text) == ["#b\" # tail"])
        #expect(keyValueParts(.literal, tokens, text) == ["false"])
    }

    @Test func yarnClassicKeepsOptionsQuotedKeysAndBareHashesDistinct() async throws {
        let text = "# header\n\"--cache-folder\" \"./Türkçe 👀/#cache\"\n--install.check-files true\nchild-concurrency 4\nmirror cache#literal # tail\nsemicolon plain;value\npartial trueValue\ninvalid-number 12abc\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".yarnrc")
        #expect(keyValueParts(.key, tokens, text) == ["\"--cache-folder\"", "--install.check-files", "child-concurrency", "mirror", "semicolon", "partial", "invalid-number"])
        #expect(keyValueParts(.string, tokens, text) == ["\"./Türkçe 👀/#cache\"", "cache#literal", "plain;value", "trueValue", "12abc"])
        #expect(keyValueParts(.literal, tokens, text) == ["true"])
        #expect(keyValueParts(.number, tokens, text) == ["4"])
        #expect(keyValueParts(.comment, tokens, text) == ["# header", "# tail"])
        keyValueRanges(tokens, text)
    }

    @Test func incompleteHeadersQuotesAndLookalikeNamesRemainReadable() async throws {
        for name in [".gitconfig", ".editorconfig", ".npmrc", ".yarnrc"] {
            for text in ["", "[", "enabled", "=", "#", "name = \"unfinished 👀\nnext = false\n", "name \"unfinished\\\nnext true\n"] {
                keyValueRanges(try await SyntaxHighlighting.tokens(in: text, fileName: name), text)
            }
        }
        for name in [".GITCONFIG", ".EDITORCONFIG", ".NPMRC", ".YARNRC", ".gitconfig.local", ".customrc", "settings.conf", "other.npmrc"] {
            #expect(try await SyntaxHighlighting.tokens(in: "enabled=true", fileName: name).isEmpty)
        }
        #expect(SyntaxDetection.language(forFileName: ".yarnrc.yml") == .yaml)
    }

    @Test(arguments: [".gitconfig", ".editorconfig", ".npmrc", ".yarnrc"])
    @MainActor func previewDraftAndSavePreserveBomAndCrLf(name: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent(name)
        let separator = name == ".yarnrc" ? " " : " = "
        let original = "# load\r\nenabled" + separator + "true\r\n"
        let draft = "# 👀 draft\r\nenabled" + separator + "false\r\n"
        let bom = Data([0xef, 0xbb, 0xbf])
        try (bom + Data(original.utf8)).write(to: file)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID()))
        #expect(keyValueParts(.literal, state.tokens, original) == ["true"])
        let document = state.documentID
        state.setMode(.edit)
        await state.updateText(draft)?.value
        state.setMode(.preview)
        state.setMode(.edit)
        #expect(state.documentID == document && state.isDirty && state.text == draft)
        #expect(keyValueParts(.literal, state.tokens, draft) == ["false"])
        #expect(keyValueParts(.comment, state.tokens, draft) == ["# 👀 draft"])
        #expect(try Data(contentsOf: file) == bom + Data(original.utf8))
        await state.save()
        #expect(!state.isDirty && state.errorMessage == nil)
        #expect(try Data(contentsOf: file) == bom + Data(draft.utf8))
    }

    @Test func longValuesAndManySettingsHaveOrderedBoundedRanges() async throws {
        for name in [".gitconfig", ".editorconfig", ".npmrc", ".yarnrc"] {
            let separator = name == ".yarnrc" ? " " : " = "
            let line = "value" + separator + "\"Türkçe 👀\"\n# comment\n"
            let text = String(repeating: line, count: 20_000)
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: name)
            #expect(tokens.count >= 60_000)
            keyValueRanges(tokens, text)
            let long = "value" + separator + "\"" + String(repeating: "x", count: 100_000) + "👀\"\nnext" + separator + "true\n"
            let result = try await SyntaxHighlighting.tokens(in: long, fileName: name)
            #expect(keyValueParts(.string, result, long).first?.utf16.count == 100_004)
            #expect(keyValueParts(.literal, result, long) == ["true"])
            keyValueRanges(result, long)
        }
    }
}

private func keyValueParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func keyValueRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
