import Foundation
import Testing
@testable import PanePeekCore

struct SQLHighlightingTests {
    @Test func parameterAndUnicodeNamesCannotBecomeKeywords() async throws {
        let source = "SELECT @select, @@select, :from, $where, $1, #select, ##from, ıf, ſelect FROM records;"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(sqlParts(.keyword, tokens, source) == ["SELECT", "FROM"])
        #expect(sqlParts(.reference, tokens, source) == ["@select", "@@select", ":from", "$where", "$1"])
        sqlRanges(tokens, source)
    }

    @Test func longDollarTagsAndStandardBackslashesStayLiteral() async throws {
        let tag = String(repeating: "a", count: 1024)
        let string = "$" + tag + "$" + String(repeating: "$" + tag + "b$", count: 500) + "$" + tag + "$"
        let source = string + " SELECT 'slash\\' FROM records;"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(sqlParts(.string, tokens, source) == [string, "'slash\\'"])
        #expect(sqlParts(.keyword, tokens, source) == ["SELECT", "FROM"])
        sqlRanges(tokens, source)
    }

    @Test func keywordsAreCaseInsensitiveAndRespectNames() async throws {
        let source = "sElEcT selected, select_name, select$tag, selectTürkçe, 👀select FROM records WHERE active IS NOT NULL AND valid = TRUE;"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "SQL")
        #expect(sqlParts(.keyword, tokens, source) == ["sElEcT", "FROM", "WHERE", "IS", "NOT", "AND"])
        #expect(sqlParts(.literal, tokens, source) == ["NULL", "TRUE"])
        sqlRanges(tokens, source)
    }

    @Test func quotedStringsProtectDoubledQuotesAndComments() async throws {
        let strings = ["'Dianne''s -- horse'", "'line\n/* literal */'", #"E'it\'s fine'"#, "N'Unicode 👀'", "B'1001'", "X'1FF'", #"U&'d\0061ta'"#]
        let source = "SELECT " + strings.joined(separator: ", ") + ";"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(sqlParts(.string, tokens, source) == strings)
        #expect(sqlParts(.comment, tokens, source).isEmpty)
        sqlRanges(tokens, source)
    }

    @Test func quotedIdentifiersRemainWhole() async throws {
        let names = [#""select""#, #""a""b -- literal""#, "`a``b`", "[a]]b]", #"U&"d\0061ta""#]
        let source = "SELECT " + names.joined(separator: ", ") + " FROM records;"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(sqlParts(.reference, tokens, source) == names)
        #expect(sqlParts(.keyword, tokens, source) == ["SELECT", "FROM"])
        sqlRanges(tokens, source)
    }

    @Test func commentsNestAndStopAtLineBoundaries() async throws {
        let source = "-- SELECT 'x'\r\n/* outer /* inner */ WHERE 'x' */ SELECT 'ok'; -- final 👀"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(sqlParts(.comment, tokens, source) == ["-- SELECT 'x'", "/* outer /* inner */ WHERE 'x' */", "-- final 👀"])
        #expect(sqlParts(.keyword, tokens, source) == ["SELECT"])
        #expect(sqlParts(.string, tokens, source) == ["'ok'"])
        sqlRanges(tokens, source)
    }

    @Test func dollarQuotesRequireMatchingCaseAndProtectInnerSource() async throws {
        let strings = ["$$SELECT 'x'; -- literal$$", "$body$BEGIN $inner$x$inner$; $BODY$ END$body$", "$Türkçe$👀$Türkçe$"]
        let source = "SELECT " + strings.joined(separator: ", ") + "; SELECT name$tag$part, $1;"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(sqlParts(.string, tokens, source) == strings)
        #expect(sqlParts(.keyword, tokens, source) == ["SELECT", "SELECT"])
        #expect(sqlParts(.comment, tokens, source).isEmpty)
        sqlRanges(tokens, source)
    }

    @Test @MainActor func sqlFilenameUsesTheExistingPreviewPipeline() async throws {
        let source = "SELECT 'text' FROM records;\n"
        let expected = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(!expected.isEmpty)
        let state = PreviewState(read: { _ in .text(source) })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview/sample.SQL"), isDirectory: false), listingRevision: UUID()))
        #expect(state.preview == .text(source) && state.tokens == expected)
        #expect(try await SyntaxHighlighting.tokens(in: source, fileName: "sample.txt").isEmpty)
    }

    @Test func largeIncompleteAndDeepCommentsHaveSafeRanges() async throws {
        let line = "SELECT '👀' FROM records; -- text\n"
        let limit = TextPreview.maximumBytes
        let bytes = Data(line.utf8)
        var data = Data()
        while data.count + bytes.count <= limit { data.append(bytes) }
        data.append(Data(repeating: 32, count: limit - data.count))
        let source = String(decoding: data, as: UTF8.self)
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileExtension: "sql")
        #expect(source.utf8.count == limit && !tokens.isEmpty)
        sqlRanges(tokens, source)
        for text in ["", "'", "\"", "[", "`", "/*", "$body$", "E'\\", String(repeating: "/*", count: 1000) + "x", "'" + String(repeating: "x", count: limit - 1), String(repeating: "$", count: 100_000), "SELECT" + String(repeating: "a", count: 100_000)] {
            sqlRanges(try await SyntaxHighlighting.tokens(in: text, fileExtension: "sql"), text)
        }
    }
}

private func sqlParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func sqlRanges(_ tokens: [SyntaxToken], _ text: String) {
    let length = text.utf16.count
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
