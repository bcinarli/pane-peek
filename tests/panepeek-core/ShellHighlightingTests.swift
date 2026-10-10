import Foundation
import Testing
@testable import PanePeekCore

struct ShellHighlightingTests {
    @Test func commandSubstitutionCommentsCannotCloseTheOuterQuote() async throws {
        let string = "\"before $(printf x # ) \"hidden\"\n) after\""
        let source = string + " fi"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sh")
        #expect(shellParts(.string, tokens, source) == [string])
        #expect(shellParts(.keyword, tokens, source) == ["fi"])
        #expect(shellParts(.comment, tokens, source).isEmpty)
        let arithmetic = "$((16#ff << 2))"
        #expect(shellParts(.reference, try await SyntaxHighlighting.tokens(in: arithmetic, fileExtension: "sh"), arithmetic) == [arithmetic])
        shellRanges(tokens, source)
    }

    @Test func emptyMixedAndEscapedHeredocLabelsRespectQuoteRemoval() async throws {
        let source = "cat <<'' <<E'ND' <<\\OTHER\nif # literal\n\nthen\nEND\nfi\nOTHER\nelse\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sh")
        #expect(shellParts(.string, tokens, source) == ["''", "E'ND'", "\\OTHER", "if # literal\n", "then\nEND", "fi\nOTHER"])
        #expect(shellParts(.keyword, tokens, source) == ["else"])
        shellRanges(tokens, source)
    }

    @Test func reservedWordsRespectWholeWordBoundaries() async throws {
        let text = "if true; then for item in list; do echo /tmp/if endif if=value; done; else while false; do break; done; fi\nrepeat 2; function name { }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "SH")
        #expect(shellParts(.keyword, tokens, text) == ["if", "then", "for", "in", "do", "done", "else", "while", "do", "done", "fi", "repeat", "function"])
        shellRanges(tokens, text)
    }

    @Test func commentsStartWordsAndQuotedOrEscapedHashesStayLiteral() async throws {
        let text = "#!/bin/bash\necho foo#bar \\#literal '# quoted' \"# quoted\";# after operator\n# final 👀"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "bash")
        #expect(shellParts(.comment, tokens, text) == ["#!/bin/bash", "# after operator", "# final 👀"])
        #expect(shellParts(.string, tokens, text) == ["'# quoted'", "\"# quoted\""])
        shellRanges(tokens, text)
    }

    @Test func quotesProtectSubstitutionsAndKeepMultilineSource() async throws {
        let strings = ["'literal $name\n# comment'", #""outer $(printf '%s' ")") ${value:-"inner"} end""#, #"$'it\'s\ntext'"#, #"$"locale""#, "`printf 'if # text'`"]
        let text = strings.joined(separator: " ") + " fi"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "zsh")
        #expect(shellParts(.string, tokens, text) == strings)
        #expect(shellParts(.keyword, tokens, text) == ["fi"])
        #expect(shellParts(.comment, tokens, text).isEmpty)
        shellRanges(tokens, text)
    }

    @Test func parametersAndSubstitutionsKeepNestedQuoteBoundaries() async throws {
        let references = ["$name", "$1", "$@", "$?", "$$", #"${value:-"${other}"}"#, #"$(printf '%s' ')')"#, "$((1 + (2 * 3)))"]
        let text = references.joined(separator: " ") + " \\$escaped $- $"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "sh")
        #expect(shellParts(.reference, tokens, text) == references + ["$-"])
        shellRanges(tokens, text)
    }

    @Test func heredocsQueueInOrderAndDistinguishHereStringsAndShift() async throws {
        let text = "cat <<'END' <<-SECOND\nif # $name 👀\nEND\n\tthen \"quote\"\n\tSECOND\nfi\ncat <<<\"value\"\necho $((1 << 2))\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "bash")
        #expect(shellParts(.string, tokens, text) == ["'END'", "SECOND", "if # $name 👀\nEND", "\tthen \"quote\"\n\tSECOND", "\"value\""])
        #expect(shellParts(.keyword, tokens, text) == ["fi"])
        #expect(shellParts(.comment, tokens, text).isEmpty)
        shellRanges(tokens, text)
    }

    @Test @MainActor func startupNamesReachTheNativePreviewPipeline() async throws {
        let source = "if true; then echo 'ok'; fi\n"
        let expected = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sh")
        #expect(!expected.isEmpty)
        for name in ["sample.sh", "sample.BASH", "sample.zsh", ".bashrc", ".bash_profile", ".bash_login", ".bash_logout", ".zshrc", ".zshenv", ".zprofile", ".zlogin", ".zlogout", ".profile"] {
            #expect(try await SyntaxHighlighting.tokens(in: source, fileName: name) == expected)
        }
        let state = PreviewState(read: { _ in .text(source) })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview/.zshrc"), isDirectory: false), listingRevision: UUID()))
        #expect(state.preview == .text(source) && state.tokens == expected)
        #expect(try await SyntaxHighlighting.tokens(in: source, fileName: "notes.txt").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: "let value", fileName: "code.swift").first?.kind == .keyword)
    }

    @Test func largeIncompleteAndDeepShellSourceKeepsSafeRanges() async throws {
        let line = "if true; then echo \"$name\"; fi # text\n"
        let limit = TextPreview.maximumBytes
        let source = String(String(repeating: line, count: limit / line.utf8.count + 1).prefix(limit))
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sh")
        #expect(source.utf8.count == limit && !tokens.isEmpty)
        shellRanges(tokens, source)
        for text in ["", "'", "\"", "$", "${", "$(", "cat <<END\nno end", String(repeating: "$(", count: 1000) + "x", "'" + String(repeating: "a", count: limit - 1), "echo " + String(repeating: "a", count: 100_000)] {
            shellRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: "zsh"), text)
        }
        #expect(try await SyntaxHighlighting.tokens(in: source, fileExtension: "txt").isEmpty)
    }
}

private func shellParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func shellRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= text.utf16.count)
        end = NSMaxRange(token.range)
    }
}
