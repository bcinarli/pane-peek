import Foundation
import Testing
@testable import PanePeekCore

struct DockerfileHighlightingTests {
    @Test func quotedParameterBracesAndCustomEscapesCannotSplitFollowingValues() async throws {
        let parameter = #"${NAME:-"${OTHER:-"}"}"}"#
        let source = "# escape=`\nENV name=\"a`\"b\"\nRUN echo \"a\\\"b\"\nWORKDIR " + parameter + "\nCOPY . /app\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.string, tokens, source) == ["\"a`\"b\"", "\"a\\\"b\""])
        #expect(dockerParts(.reference, tokens, source) == [parameter])
        #expect(dockerParts(.keyword, tokens, source) == ["ENV", "RUN", "WORKDIR", "COPY"])
        dockerRanges(tokens, source)
        let continuation = "ENV name=\"a\\\n# comment\n b\"\nCOPY . /app\n"
        let continued = try await SyntaxHighlighting.tokens(in: continuation, fileName: "Dockerfile")
        #expect(dockerParts(.string, continued, continuation) == ["\"a\\", "b\""])
        #expect(dockerParts(.comment, continued, continuation) == ["# comment"])
        #expect(dockerParts(.keyword, continued, continuation) == ["ENV", "COPY"])
        dockerRanges(continued, continuation)
    }

    @Test func longTokensLabelsAndNearHeredocDelimitersStayBounded() async throws {
        for prefix in ["#", "RUN \"", "ENV name=${", "COPY <<EOF\n"] {
            let source = prefix + String(repeating: "x", count: TextPreview.maximumBytes - prefix.utf8.count)
            let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
            #expect(!tokens.isEmpty && NSMaxRange(tokens.last!.range) == source.utf16.count)
            dockerRanges(tokens, source)
        }
        let label = String(repeating: "E", count: 100_000)
        let source = "COPY <<" + label + " /file\n" + label + "x\n" + label + "\nFROM base\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.keyword, tokens, source) == ["COPY", "FROM"])
        dockerRanges(tokens, source)
        for text in ["ONBUILD " + String(repeating: "a", count: 100_000), "RUN " + String(repeating: "<", count: 100_000), "ENV name=${" + String(repeating: "{", count: 100_000), "RUN <<''\n\nFROM base\n", "RUN echo \\\\\nCOPY . /app\n"] {
            dockerRanges(try await SyntaxHighlighting.tokens(in: text, fileName: "Dockerfile"), text)
        }
    }

    @Test func instructionsOnlyStartLogicalLinesAndOnbuildPrefixes() async throws {
        let source = "  from alpine AS build\nRUN echo FROM RUN # literal\nONBUILD COPY . /app\nONBUILD RUN echo COPY\nRUNner nope\nFROMç nope\nſHELL nope\nENV key=value\nCMD [\"echo\", \"RUN\"]\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.keyword, tokens, source) == ["from", "RUN", "ONBUILD", "COPY", "ONBUILD", "RUN", "ENV", "CMD"])
        #expect(dockerParts(.comment, tokens, source).isEmpty)
        #expect(dockerParts(.string, tokens, source) == ["\"echo\"", "\"RUN\""])
        dockerRanges(tokens, source)
    }

    @Test func commentsAndContinuationLinesKeepTheirOwnBoundaries() async throws {
        let source = "# header 👀\r\nRUN echo \\\r\n  # comment \\\r\n  FROM literal\r\nCOPY source /dest # argument\n  # tail\nRUN echo \\\n\nCOPY argument\nENV name=value\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.keyword, tokens, source) == ["RUN", "COPY", "RUN", "ENV"])
        #expect(dockerParts(.comment, tokens, source) == ["# header 👀", "# comment \\", "# tail"])
        dockerRanges(tokens, source)
    }

    @Test func topParserDirectivesChooseTheContinuationEscape() async throws {
        let source = "# syntax=docker/dockerfile:1\n# EsCaPe = `\nFROM alpine\nRUN echo `  \nCOPY argument\nRUN echo \\\nCOPY actual\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.keyword, tokens, source) == ["FROM", "RUN", "RUN", "COPY"])
        #expect(dockerParts(.comment, tokens, source) == ["# syntax=docker/dockerfile:1", "# EsCaPe = `"])
        for prefix in ["# ordinary\n", "\n", "FROM base\n", "# unknown=value\n"] {
            let text = prefix + "# escape=`\nRUN echo `\nCOPY actual\n"
            let result = try await SyntaxHighlighting.tokens(in: text, fileName: "Dockerfile")
            #expect(dockerParts(.keyword, result, text).suffix(2) == ["RUN", "COPY"])
        }
        dockerRanges(tokens, source)
    }

    @Test func quotedValuesProtectHashesEscapesAndVariables() async throws {
        let quoted = #""Türkçe \"quoted\" # $NAME""#
        let source = "ENV message=" + quoted + " literal='$NAME # text'\nRUN echo \"unfinished\nCOPY \"next\" /app\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.string, tokens, source) == [quoted, "'$NAME # text'", "\"unfinished", "\"next\""])
        #expect(dockerParts(.comment, tokens, source).isEmpty)
        #expect(dockerParts(.reference, tokens, source).isEmpty)
        #expect(dockerParts(.keyword, tokens, source) == ["ENV", "RUN", "COPY"])
        dockerRanges(tokens, source)
    }

    @Test func parametersKeepWholeNestedBracesAndEscapedDollarsPlain() async throws {
        let source = #"FROM ${BASE:-${FALLBACK}}"# + "\nWORKDIR $ROOT/${NAME} \\$escaped $$ $1\nCOPY ${unfinished\nRUN echo $NEXT\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.reference, tokens, source) == ["${BASE:-${FALLBACK}}", "$ROOT", "${NAME}", "${unfinished", "$NEXT"])
        #expect(dockerParts(.keyword, tokens, source) == ["FROM", "WORKDIR", "COPY", "RUN"])
        dockerRanges(tokens, source)
    }

    @Test func heredocsProtectBodyInstructionsAndQueueQuotedTabStrippedLabels() async throws {
        let source = "RUN <<'END' <<-E\"OT\"\nFROM $NAME # literal 👀\nEND\n\tCOPY \"literal\"\n\tEOT\nCOPY <<EOF /file\n# literal\nEOF\nRUN echo '<<NOT'\nCMD [\"<<JSON\"]\nFROM base\n"
        let tokens = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(dockerParts(.keyword, tokens, source) == ["RUN", "COPY", "RUN", "CMD", "FROM"])
        #expect(dockerParts(.string, tokens, source) == ["'END'", "E\"OT\"", "FROM $NAME # literal 👀\nEND", "\tCOPY \"literal\"\n\tEOT", "EOF", "# literal\nEOF", "'<<NOT'", "\"<<JSON\""])
        #expect(dockerParts(.reference, tokens, source).isEmpty)
        #expect(dockerParts(.comment, tokens, source).isEmpty)
        dockerRanges(tokens, source)
    }

    @Test @MainActor func filenameVariantsAndLargeIncompleteSourceReachThePreviewPipeline() async throws {
        let source = "FROM alpine\nRUN echo \"👀\" # literal\n"
        let expected = try await SyntaxHighlighting.tokens(in: source, fileName: "Dockerfile")
        #expect(!expected.isEmpty)
        for name in ["Dockerfile", "dockerfile", "DOCKERFILE", "Dockerfile.dev", "Dockerfile.release", "build.Dockerfile", "build.DOCKERFILE", "/preview/Dockerfile"] {
            #expect(try await SyntaxHighlighting.tokens(in: source, fileName: name) == expected)
        }
        let state = PreviewState(read: { _ in .text(source) })
        await state.load(DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/preview/Dockerfile.dev"), isDirectory: false), listingRevision: UUID()))
        #expect(state.preview == .text(source) && state.tokens == expected)
        for name in ["DockerfileBackup", "Dockerfile.", "Containerfile", "MakefileBackup", "notes.txt", ".dockerignore"] {
            #expect(try await SyntaxHighlighting.tokens(in: source, fileName: name).isEmpty)
        }
        let line = "RUN echo \"value\"\n"
        let large = String(String(repeating: line, count: TextPreview.maximumBytes / line.count + 1).prefix(TextPreview.maximumBytes))
        let tokens = try await SyntaxHighlighting.tokens(in: large, fileName: "Dockerfile")
        #expect(large.utf8.count == TextPreview.maximumBytes && !tokens.isEmpty)
        dockerRanges(tokens, large)
        for text in ["", "#", "RUN", "RUN \\", "RUN \"", "COPY <<EOF\n👀", "ENV name=${", "RUN <<'unfinished"] {
            dockerRanges(try await SyntaxHighlighting.tokens(in: text, fileName: "Dockerfile"), text)
        }
    }
}

private func dockerParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func dockerRanges(_ tokens: [SyntaxToken], _ text: String) {
    let length = text.utf16.count
    var end = 0
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
