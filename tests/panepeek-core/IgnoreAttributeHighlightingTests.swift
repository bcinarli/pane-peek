import Foundation
import Testing
@testable import PanePeekCore

struct IgnoreAttributeHighlightingTests {
    @Test(arguments: [".gitignore", ".prettierignore", ".eslintignore", ".stylelintignore"])
    func ignoreNamesSharePatternRules(name: String) async throws {
        let text = "# Generated\n/build/\n*.log\n!important.log\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: "/project/" + name)
        #expect(SyntaxDetection.language(forFileName: name) != .plainText)
        #expect(patternParts(.comment, tokens, text) == ["# Generated"])
        #expect(patternParts(.keyword, tokens, text) == ["!"])
        #expect(patternParts(.string, tokens, text) == ["/build/", "*.log", "important.log"])
        #expect(tokens == (try await SyntaxHighlighting.tokens(in: text, fileName: ".gitignore")))
        patternRanges(tokens, text)
    }

    @Test(arguments: [".dockerignore", "Dockerfile.dockerignore", "api.Dockerfile.DOCKERIGNORE"])
    func dockerIgnoreNamesSelectTheDockerDialect(name: String) async throws {
        #expect(SyntaxDetection.language(forFileName: "/project/" + name) == .dockerIgnore)
        let text = "# Generated\n**/node_modules\n!README.md\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: "/project/" + name)
        #expect(patternParts(.comment, tokens, text) == ["# Generated"])
        #expect(patternParts(.keyword, tokens, text) == ["!"])
        #expect(patternParts(.string, tokens, text) == ["**/node_modules", "README.md"])
        patternRanges(tokens, text)
    }

    @Test(arguments: [".DOCKERIGNORE", "dockerignore", ".dockerignore.bak"])
    func dockerIgnoreLookalikesRemainPlain(name: String) {
        #expect(SyntaxDetection.language(forFileName: name) == .plainText)
    }

    @Test func dockerIgnoreTrimsPatternsAndOnlyTreatsColumnOneHashesAsComments() async throws {
        let lines = ["#comment", "  # indented hash is a pattern", "\tbuild/  ", "!  keep.txt ", "  ! spaced", "escaped\\ ", "trailing\\", "   ", "", "!", "#"]
        let text = lines.joined(separator: "\r\n")
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".dockerignore")
        #expect(patternParts(.comment, tokens, text) == ["#comment", "#"])
        #expect(patternParts(.keyword, tokens, text) == ["!", "!", "!"])
        #expect(patternParts(.string, tokens, text) == ["# indented hash is a pattern", "build/", "keep.txt", "spaced", "escaped\\", "trailing\\"])
        patternRanges(tokens, text)
    }

    @Test func dockerIgnoreKeepsUnicodeRangesAndGitIgnoreKeepsItsRules() async throws {
        let text = "\u{FEFF}café/👀*\n  !ünï  \n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".dockerignore")
        #expect(patternParts(.string, tokens, text) == ["café/👀*", "ünï"])
        patternRanges(tokens, text)
        let git = try await SyntaxHighlighting.tokens(in: "  !literal  \n", fileName: ".gitignore")
        #expect(patternParts(.keyword, git, "  !literal  \n").isEmpty)
    }

    @Test func dockerIgnoreTrimsUnicodeWhitespaceAroundPatternsAndExceptionMarkers() async throws {
        let text = "\u{00A0}!keep.txt\n!\u{3000}spaced\u{2003}\n\u{00A0}#pattern\n\u{200A}plain\u{0085}\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".dockerignore")
        #expect(tokens.map(\.range) == [NSRange(location: 1, length: 1), NSRange(location: 2, length: 8),
                                        NSRange(location: 11, length: 1), NSRange(location: 13, length: 6),
                                        NSRange(location: 22, length: 8), NSRange(location: 32, length: 5)])
        #expect(tokens.map(\.kind) == [.keyword, .string, .keyword, .string, .string, .string])
    }

    @Test func dockerIgnoreSplitsLinesOnlyAtLineFeeds() async throws {
        let text = "prefix\r#suffix\r\n#comment\r\n\r#pattern"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".dockerignore")
        #expect(tokens.map(\.range) == [NSRange(location: 0, length: 14), NSRange(location: 16, length: 8),
                                        NSRange(location: 27, length: 8)])
        #expect(tokens.map(\.kind) == [.string, .comment, .string])
        let git = try await SyntaxHighlighting.tokens(in: "prefix\r#suffix\n", fileName: ".gitignore")
        #expect(git.map(\.range) == [NSRange(location: 0, length: 6), NSRange(location: 7, length: 7)])
        #expect(git.map(\.kind) == [.string, .comment])
    }

    @Test func ignoreCommentsNegationAndLeadingSpacesKeepTheirBoundaries() async throws {
        let text = "# comment\r\nfoo#bar\n # literal\n\\#literal\n!important.log\n\\!literal\n !literal\n!/build/**\n!\\#name\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".gitignore")
        #expect(patternParts(.comment, tokens, text) == ["# comment"])
        #expect(patternParts(.keyword, tokens, text) == ["!", "!", "!"])
        #expect(patternParts(.string, tokens, text) == ["foo#bar", " # literal", "\\#literal", "important.log", "\\!literal", " !literal", "/build/**", "\\#name"])
        patternRanges(tokens, text)
    }

    @Test func ignoreTrailingSpacesRespectEscapesWithoutTreatingTabsAsSpaces() async throws {
        let lines = ["plain   ", "escaped\\ ", "paired\\\\   ", "three\\\\\\  ", "tab\t", "   ", "trailing\\", "next"]
        let text = lines.joined(separator: "\n")
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".prettierignore")
        #expect(patternParts(.string, tokens, text) == ["plain", "escaped\\ ", "paired\\\\", "three\\\\\\ ", "tab\t", "trailing\\", "next"])
        patternRanges(tokens, text)
    }

    @Test func ignoreQuotesAndBackslashesDoNotIntroduceStringsOrContinuations() async throws {
        let text = "trailing\\\n# next line\n\"quoted # still a pattern\"\npath with spaces/[ab]?.log\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".eslintignore")
        #expect(patternParts(.comment, tokens, text) == ["# next line"])
        #expect(patternParts(.string, tokens, text) == ["trailing\\", "\"quoted # still a pattern\"", "path with spaces/[ab]?.log"])
        patternRanges(tokens, text)
    }

    @Test func attributesDistinguishPatternsNamesStatesValuesAndMacros() async throws {
        let text = "# header\n  # indented\n*.swift text eol=lf\n*.png -text binary\n*.md diff=markdown !merge\n[attr]binary -diff -merge -text\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".gitattributes")
        #expect(SyntaxDetection.language(forFileName: ".gitattributes") != .plainText)
        #expect(patternParts(.comment, tokens, text) == ["# header", "# indented"])
        #expect(patternParts(.section, tokens, text) == ["[attr]binary"])
        #expect(patternParts(.string, tokens, text) == ["*.swift", "lf", "*.png", "*.md", "markdown"])
        #expect(patternParts(.key, tokens, text) == ["text", "eol", "text", "binary", "diff", "merge", "diff", "merge", "text"])
        #expect(patternParts(.reference, tokens, text) == ["-", "!", "-", "-", "-"])
        patternRanges(tokens, text)
    }

    @Test func attributesQuoteOnlyThePathAndKeepInlineHashesLiteral() async throws {
        let quoted = "\"path with spaces/👀 \\\"name\\\".txt\""
        let text = quoted + " text diff=custom#value\nplain\\ path text\n*.txt note=\"not quoted\" # marker\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".gitattributes")
        #expect(patternParts(.string, tokens, text) == [quoted, "custom#value", "plain\\", "*.txt", "\"not"])
        #expect(patternParts(.key, tokens, text) == ["text", "diff", "path", "text", "note", "marker"])
        #expect(patternParts(.comment, tokens, text).isEmpty)
        patternRanges(tokens, text)
    }

    @Test func attributesDoNotReuseIgnoreNegationAndRecoverAfterUnclosedPaths() async throws {
        let text = "!pattern text\n\\!literal -text\n*.md !diff\n\"unfinished path 👀\n*.swift text eol=lf\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".gitattributes")
        #expect(patternParts(.keyword, tokens, text).isEmpty)
        #expect(patternParts(.string, tokens, text) == ["!pattern", "\\!literal", "*.md", "\"unfinished path 👀", "*.swift", "lf"])
        #expect(patternParts(.reference, tokens, text) == ["-", "!"])
        #expect(patternParts(.key, tokens, text) == ["text", "text", "diff", "text", "eol"])
        patternRanges(tokens, text)
    }

    @Test func incompletePatternsAndLookalikeNamesKeepSafeFallback() async throws {
        for name in [".gitignore", ".gitattributes"] {
            for text in ["", "!", "\\", "[", "#", "\"unfinished\\", "*.txt - ! name= bad:name\nnext text\n"] {
                patternRanges(try await SyntaxHighlighting.tokens(in: text, fileName: name), text)
            }
        }
        for name in [".GITIGNORE", ".GITATTRIBUTES", ".gitignore.local", "other.gitignore", ".customignore", ".stylelintignore-backup"] {
            #expect(try await SyntaxHighlighting.tokens(in: "# comment\n*.log", fileName: name).isEmpty)
        }
        #expect(SyntaxDetection.language(forFileName: ".gitignore.json") == .json)
    }

    @Test(arguments: [".gitignore", ".prettierignore", ".eslintignore", ".stylelintignore", ".gitattributes"])
    @MainActor func previewDraftAndSavePreserveBomAndCrLf(name: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent(name)
        let attributes = name == ".gitattributes"
        let original = attributes ? "# load\r\n*.txt text eol=lf\r\n" : "# load\r\n*.log\r\n"
        let draft = attributes ? "# 👀 draft\r\n*.txt -text eol=crlf\r\n" : "# 👀 draft\r\n!important.log\r\n"
        let bom = Data([0xef, 0xbb, 0xbf])
        try (bom + Data(original.utf8)).write(to: file)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID()))
        #expect(!patternParts(.string, state.tokens, original).isEmpty)
        let document = state.documentID
        state.setMode(.edit)
        await state.updateText(draft)?.value
        state.setMode(.preview)
        state.setMode(.edit)
        #expect(state.documentID == document && state.isDirty && state.text == draft)
        #expect(patternParts(.comment, state.tokens, draft) == ["# 👀 draft"])
        #expect(patternParts(attributes ? .reference : .keyword, state.tokens, draft) == [attributes ? "-" : "!"])
        #expect(try Data(contentsOf: file) == bom + Data(original.utf8))
        await state.save()
        #expect(!state.isDirty && state.errorMessage == nil)
        #expect(try Data(contentsOf: file) == bom + Data(draft.utf8))
    }

    @Test(arguments: [".gitignore", ".gitattributes"])
    func largeAndLongPatternsHaveWholeOrderedRanges(name: String) async throws {
        let line = name == ".gitignore" ? "folder/*.log\n!folder/keep.log\n# comment\n" : "*.txt text eol=lf\n# comment\n"
        let text = String(repeating: line, count: 20_000)
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: name)
        #expect(tokens.count >= 80_000)
        patternRanges(tokens, text)
        let pattern = String(repeating: "x", count: 100_000) + "👀"
        let long = pattern + (name == ".gitattributes" ? " text" : "") + "\n# end\n"
        let result = try await SyntaxHighlighting.tokens(in: long, fileName: name)
        let wholePattern = result.first { $0.kind == .string }
        #expect(wholePattern?.range == NSRange(location: 0, length: 100_002))
        #expect(patternParts(.comment, result, long) == ["# end"])
        patternRanges(result, long)
    }
}

private func patternParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func patternRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
