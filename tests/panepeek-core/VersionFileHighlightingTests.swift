import Foundation
import Testing
@testable import PanePeekCore

struct VersionFileHighlightingTests {
    @Test(arguments: [(".ruby-version", SyntaxLanguage.rubyVersion), (".python-version", .pythonVersion),
                      (".tool-versions", .toolVersions)])
    func exactNamesSelectTheirOwnFormat(name: String, expected: SyntaxLanguage) {
        #expect(SyntaxDetection.language(forFileName: "/project/" + name) == expected)
    }

    @Test(arguments: [".RUBY-VERSION", ".python-version.bak", "tool-versions", ".node-version", ".nvmrc.txt"])
    func lookalikesKeepTheirExistingTreatment(name: String) {
        #expect(![SyntaxLanguage.rubyVersion, .pythonVersion, .toolVersions].contains(SyntaxDetection.language(forFileName: name)))
    }

    @Test func rubyVersionHighlightsOnlyTheFirstWordOfTheFile() async throws {
        let text = "\u{FEFF}\r\n  3.3.0  extra words\n# not a comment\n3.2.0\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".ruby-version")
        #expect(versionParts(.literal, tokens, text) == ["3.3.0"])
        #expect(versionParts(.comment, tokens, text).isEmpty)
        versionRanges(tokens, text)
    }

    @Test func pythonVersionHighlightsEachLinesFirstWordAndCommentLines() async throws {
        let text = "3.12.1 trailing ignored\r\n  # pinned for CI\n#comment\n\n\tpypy3.10-7.3.15\nsystem#not-comment\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".python-version")
        #expect(versionParts(.literal, tokens, text) == ["3.12.1", "pypy3.10-7.3.15", "system#not-comment"])
        #expect(versionParts(.comment, tokens, text) == ["# pinned for CI", "#comment"])
        versionRanges(tokens, text)
    }

    @Test func toolVersionsHighlightToolsVersionsAndComments() async throws {
        let text = "ruby 3.3.0 # current\r\n# shared\npython 3.12.1 2.7.18 system\nelixir ref:v1.16.0\nlocal path:~/src/tool#1\nnodejs\n  \n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".tool-versions")
        #expect(versionParts(.key, tokens, text) == ["ruby", "python", "elixir", "local", "nodejs"])
        #expect(versionParts(.literal, tokens, text) == ["3.3.0", "3.12.1", "2.7.18", "system", "ref:v1.16.0", "path:~/src/tool#1"])
        #expect(versionParts(.comment, tokens, text) == ["# current", "# shared"])
        versionRanges(tokens, text)
    }

    @Test(arguments: [".ruby-version", ".python-version", ".tool-versions"])
    func unicodeAndIncompleteDraftsKeepOrderedRanges(name: String) async throws {
        let text = "ünïcode 👀 3.0\n#\n" + String(repeating: "x", count: 3000) + " tail"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: name)
        #expect(!tokens.isEmpty)
        versionRanges(tokens, text)
    }
}

private func versionParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func versionRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        end = token.range.location + token.range.length
    }
    #expect(end <= (text as NSString).length)
}
