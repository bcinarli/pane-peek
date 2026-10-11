import Foundation
import Testing
@testable import PanePeekCore

struct StyleHighlightingTests {
    @Test func selectorsDeclarationsAndValuesHaveSeparateBoundaries() async throws {
        let text = "#app, .card:hover > a[data-title='Türkçe 👀'] { --accent: #abc; color: var(--accent); margin: -1.5rem 20%; display: grid !important; }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "CSS")
        #expect(styleParts(.section, tokens, text).contains("#app"))
        #expect(styleParts(.section, tokens, text).contains(".card"))
        #expect(styleParts(.key, tokens, text) == ["--accent", "color", "margin", "display"])
        #expect(styleParts(.literal, tokens, text) == ["#abc", "var", "--accent", "grid"])
        #expect(styleParts(.number, tokens, text) == ["-1.5rem", "20%"])
        #expect(styleParts(.keyword, tokens, text) == ["!important"])
        #expect(styleParts(.string, tokens, text) == ["'Türkçe 👀'"])
        styleRanges(tokens, text)
    }

    @Test func nestedRulesAndAtRulesDoNotTurnPseudoSelectorsIntoProperties() async throws {
        let text = "@media (min-width: 40rem) { a:hover { color: red; &:focus { color: blue } } } @font-face { font-family: 'Demo'; src: url(font.woff2) } @keyframes fade { from { opacity: 0 } 100% { opacity: 1 } }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "css")
        #expect(styleParts(.keyword, tokens, text) == ["@media", "@font-face", "@keyframes"])
        #expect(styleParts(.key, tokens, text) == ["color", "color", "font-family", "src", "opacity", "opacity"])
        #expect(styleParts(.section, tokens, text).contains("hover"))
        #expect(styleParts(.section, tokens, text).contains("focus"))
        #expect(styleParts(.literal, tokens, text).contains("red"))
        styleRanges(tokens, text)
    }

    @Test func commentsStringsAndUrlsSuppressStructuralDelimiters() async throws {
        let text = #"/* .fake { color: red } */ .real { content: '/* text */ } ;'; background: url(https://example.test/a\)b/*literal*/.png); color: blue; /* non /* nested */ width: 2px }"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "css")
        #expect(styleParts(.comment, tokens, text) == ["/* .fake { color: red } */", "/* non /* nested */"])
        #expect(styleParts(.key, tokens, text) == ["content", "background", "color", "width"])
        #expect(styleParts(.string, tokens, text) == ["'/* text */ } ;'", #"url(https://example.test/a\)b/*literal*/.png)"#])
        styleRanges(tokens, text)
    }

    @Test func scssVariablesDirectivesInterpolationAndNestedPropertiesKeepContext() async throws {
        let text = "$gap: 1rem !default; // note { fake: 3 }\n@mixin spacing($size) { padding: $size; font: { size: 12px; weight: bold; } } .card-#{$name} { @include spacing($gap); &:hover { color: $theme; } border-#{$side}: solid; }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "SCSS")
        #expect(styleParts(.reference, tokens, text) == ["$gap", "$size", "$size", "#{$name}", "$gap", "$theme", "#{$side}"])
        #expect(styleParts(.keyword, tokens, text) == ["!default", "@mixin", "@include"])
        #expect(styleParts(.key, tokens, text) == ["padding", "font", "size", "weight", "color", "border-"])
        #expect(styleParts(.comment, tokens, text) == ["// note { fake: 3 }"])
        styleRanges(tokens, text)
    }

    @Test func cssDoesNotUseScssLineCommentsAndFallbackStaysPlain() async throws {
        let text = ".card { color: red; // comment\n width: 2px; }"
        let css = try await SyntaxHighlighting.tokens(in: text, fileExtension: "css")
        let scss = try await SyntaxHighlighting.tokens(in: text, fileExtension: "scss")
        #expect(styleParts(.comment, css, text).isEmpty)
        #expect(styleParts(.comment, scss, text) == ["// comment"])
        #expect(styleParts(.key, scss, text) == ["color", "width"])
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sass").isEmpty)
        #expect(try await SyntaxHighlighting.tokens(in: text, fileExtension: "txt").isEmpty)
        styleRanges(css, text)
    }

    @Test func escapedNamesIncompleteStringsAndUnicodeHaveSafeRanges() async throws {
        let text = #".\31 23, .çocuk { --renk: #f00; content: '👀'; }"#
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "css")
        #expect(styleParts(.section, tokens, text) == [#".\31 23"#, ".çocuk"])
        #expect(styleParts(.key, tokens, text) == ["--renk", "content"])
        for language in ["css", "scss"] {
            for source in ["", ".card {", "a { content: 'unfinished 👀", "/* unfinished", "a { image: url(unfinished", "$x: #{'unfinished }", "a { color: red\n}"] {
                styleRanges(try await SyntaxHighlighting.tokens(in: source, fileExtension: language), source)
            }
        }
        styleRanges(tokens, text)
    }

    @Test func numericHashValuesAndSelectorsStayWhole() async throws {
        let text = "#123-id { color: #123456; outline-color: #0008; width: .5e+2px; margin: +2.0em; }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "css")
        #expect(styleParts(.section, tokens, text) == ["#123-id"])
        #expect(styleParts(.literal, tokens, text) == ["#123456", "#0008"])
        #expect(styleParts(.number, tokens, text) == [".5e+2px", "+2.0em"])
        styleRanges(tokens, text)
    }

    @Test func customPropertyBlocksAndStringRecoveryRetainFollowingDeclarations() async throws {
        let text = "a { --theme: { nested: [red; blue]; text: '}'; }; content: 'bad\n; color: red; content: 'line\\\r\ncontinued'; width: 2px; }"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "css")
        #expect(styleParts(.key, tokens, text) == ["--theme", "content", "color", "content", "width"])
        #expect(styleParts(.literal, tokens, text).contains("nested"))
        #expect(styleParts(.string, tokens, text) == ["'}'", "'bad", "'line\\\r\ncontinued'"])
        styleRanges(tokens, text)
    }

    @Test func interpolationInsideStringsAndUrlsKeepsContainingValuesWhole() async throws {
        let text = ##"$theme: 'demo'; .card { content: "#{map.get($theme, 'key')} text"; background: url(https://example.test/#{fn(')')}.png); color /* note */: red; }"##
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: "scss")
        #expect(styleParts(.reference, tokens, text) == ["$theme"])
        #expect(styleParts(.key, tokens, text) == ["content", "background", "color"])
        #expect(styleParts(.string, tokens, text) == ["'demo'", ##""#{map.get($theme, 'key')} text""##, #"url(https://example.test/#{fn(')')}.png)"#])
        styleRanges(tokens, text)
    }

    @Test func largeAndDeepStyleInputHasOrderedRanges() async throws {
        let line = ".card:hover { color: #abc; padding: 12px; content: 'text'; }\n"
        let text = String(String(repeating: line, count: TextPreview.maximumBytes / line.utf8.count + 1).prefix(TextPreview.maximumBytes))
        for language in ["css", "scss"] {
            let tokens = try await SyntaxHighlighting.tokens(in: text, fileExtension: language)
            #expect(tokens.count > 50_000)
            styleRanges(tokens, text)
            let deep = String(repeating: ".a {", count: 200) + "color: red;" + String(repeating: "}", count: 200)
            styleRanges(try await SyntaxHighlighting.tokens(in: deep, fileExtension: language), deep)
        }
        var nestedString = "true"
        for _ in 0..<200 { nestedString = "\"#{" + nestedString + "}\"" }
        let interpolation = ".a { content: " + nestedString + "; }"
        styleRanges(try await SyntaxHighlighting.tokens(in: interpolation, fileExtension: "scss"), interpolation)
        let longName = String(repeating: "-", count: 100_000) + " { color: red; }"
        let tokens = try await SyntaxHighlighting.tokens(in: longName, fileExtension: "css")
        #expect(styleParts(.key, tokens, longName) == ["color"])
        styleRanges(tokens, longName)
    }
}

private func styleParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func styleRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
