import Foundation
import Testing
@testable import PanePeekCore

struct NvmViminfoHighlightingTests {
    @Test func nvmVersionsAndAliasesAreWholeLiteralsWithHashComments() async throws {
        let text = "# Node version\r\n v22.14.0 # pinned\nlts/*\nnode\ncustom-alias\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: "/project/.nvmrc")
        #expect(nvParts(.comment, tokens, text) == ["# Node version", "# pinned"])
        #expect(nvParts(.literal, tokens, text) == ["v22.14.0", "lts/*", "node", "custom-alias"])
        nvRanges(tokens, text)
    }

    @Test func nvmHasNoShellQuotingEscapesOrExpansion() async throws {
        let text = "alias\\# comment\n\"lts# still a comment\n $NODE # literal data\n`node --version`\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".nvmrc")
        #expect(nvParts(.literal, tokens, text) == ["alias\\", "\"lts", "$NODE", "`node --version`"])
        #expect(nvParts(.comment, tokens, text) == ["# comment", "# still a comment", "# literal data"])
        #expect(nvParts(.reference, tokens, text).isEmpty)
        nvRanges(tokens, text)
    }

    @Test func nvmReservedAssignmentsKeepWholeValues() async throws {
        let text = " engine = lts/* # reserved\nfeature=\"enabled\";yes\nempty= \n=orphan\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".nvmrc")
        #expect(nvParts(.key, tokens, text) == ["engine", "feature", "empty"])
        #expect(nvParts(.string, tokens, text) == ["lts/*", "\"enabled\";yes"])
        #expect(nvParts(.comment, tokens, text) == ["# reserved"])
        nvRanges(tokens, text)
    }

    @Test func viminfoCommentsOptionsAndModernRecordsAreDistinct() async throws {
        let text = "# Viminfo version\n|1,4\n|2,0,1,,\"echo # text\"\n*encoding=utf-8\n|<continued # payload\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".viminfo")
        #expect(nvParts(.comment, tokens, text) == ["# Viminfo version"])
        #expect(nvParts(.keyword, tokens, text) == ["|", "|", "*", "|<"])
        #expect(nvParts(.number, tokens, text) == ["1", "2"])
        #expect(nvParts(.key, tokens, text) == ["encoding"])
        #expect(nvParts(.string, tokens, text) == [",4", ",0,1,,\"echo # text\"", "utf-8", "continued # payload"])
        nvRanges(tokens, text)
    }

    @Test func viminfoLegacyRecordsKeepPayloadsOpaque() async throws {
        let text = ":echo 'literal'\n'a  2  0  /project/👀.txt\n\"\"a\tLINE\t0\n~MSle0~/pattern#data\n\t# register payload\n # leading space\nunknown record\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".viminfo")
        #expect(nvParts(.keyword, tokens, text) == [":", "'a", "\"\"a", "~"])
        #expect(nvParts(.string, tokens, text) == ["echo 'literal'", "  2  0  /project/👀.txt", "\tLINE\t0", "MSle0~/pattern#data"])
        #expect(nvParts(.comment, tokens, text).isEmpty)
        nvRanges(tokens, text)
    }

    @Test func viminfoRecognisesLegacyMarkersWithoutParsingCommands() async throws {
        let markers = ["/", "&", "$", "@", ":", "?", "=", "%", "!", "<", "-a", "'b", "> ", "\"c", "~"]
        let text = markers.map { $0 + "payload # data" }.joined(separator: "\r\n")
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".viminfo")
        #expect(nvParts(.keyword, tokens, text) == markers)
        #expect(nvParts(.string, tokens, text) == Array(repeating: "payload # data", count: markers.count))
        nvRanges(tokens, text)
    }

    @Test func viminfoIncompletePrefixesDoNotSplitUnicodePayloads() async throws {
        let text = "'👀payload\n\"\"👀payload\n>👀path\n"
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: ".viminfo")
        #expect(nvParts(.keyword, tokens, text) == ["'", "\"\"", ">"])
        #expect(nvParts(.string, tokens, text) == ["👀payload", "👀payload", "👀path"])
        nvRanges(tokens, text)
    }

    @Test func incompleteRecordsRecoverAtNewlinesAndUnknownNamesStayPlain() async throws {
        for name in [".nvmrc", ".viminfo"] {
            #expect(SyntaxDetection.language(forFileName: name) != .plainText)
            for text in ["", "#", "|", "|<", "\"", "\"\"", "*encoding=", "=", "\\\n# next 👀\n"] {
                nvRanges(try await SyntaxHighlighting.tokens(in: text, fileName: name), text)
            }
        }
        for name in [".NVMRC", ".VIMINFO", ".nvmrc.local", ".viminfo.tmp", "notes.viminfo", ".vimrc", ".node-version"] {
            #expect(try await SyntaxHighlighting.tokens(in: "# comment\nlts/*\n|1,4", fileName: name).isEmpty)
        }
        #expect(SyntaxDetection.language(forFileName: ".nvmrc.json") == .json)
        #expect(SyntaxDetection.language(forFileName: ".viminfo.sh") == .shell)
    }

    @Test(arguments: [".nvmrc", ".viminfo"])
    @MainActor func previewDraftAndSavePreserveBomAndCrLf(name: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent(name)
        let vim = name == ".viminfo"
        let original = vim ? "# load\r\n|1,4\r\n" : "# load\r\nv22.14.0\r\n"
        let draft = vim ? "# 👀 draft\r\n|2,0,1,,\"Türkçe\"\r\n" : "# 👀 draft\r\nlts/*\r\n"
        let bom = Data([0xef, 0xbb, 0xbf])
        try (bom + Data(original.utf8)).write(to: file)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: file, isDirectory: false), listingRevision: UUID()))
        #expect(!nvParts(vim ? .number : .literal, state.tokens, original).isEmpty)
        let document = state.documentID
        state.setMode(.edit)
        await state.updateText(draft)?.value
        state.setMode(.preview)
        state.setMode(.edit)
        #expect(state.documentID == document && state.isDirty && state.text == draft)
        #expect(nvParts(.comment, state.tokens, draft) == ["# 👀 draft"])
        #expect(nvParts(vim ? .keyword : .literal, state.tokens, draft) == [vim ? "|" : "lts/*"])
        #expect(try Data(contentsOf: file) == bom + Data(original.utf8))
        await state.save()
        #expect(!state.isDirty && state.errorMessage == nil)
        #expect(try Data(contentsOf: file) == bom + Data(draft.utf8))
    }

    @Test(arguments: [".nvmrc", ".viminfo"])
    func largeAndLongRecordsHaveWholeOrderedSourceRanges(name: String) async throws {
        let line = name == ".nvmrc" ? "lts/*\n# comment 👀\n" : "|2,0,1,,\"payload 👀\"\n# comment\n"
        let text = String(repeating: line, count: 20_000)
        let tokens = try await SyntaxHighlighting.tokens(in: text, fileName: name)
        #expect(tokens.count >= 40_000)
        nvRanges(tokens, text)
        let prefix = name == ".nvmrc" ? "" : ":"
        let long = prefix + String(repeating: "x", count: 100_000) + "👀\n# end\n"
        let result = try await SyntaxHighlighting.tokens(in: long, fileName: name)
        let payload = result.first { $0.kind == (name == ".nvmrc" ? .literal : .string) }
        #expect(payload?.range == NSRange(location: prefix.utf16.count, length: 100_002))
        #expect(nvParts(.comment, result, long) == ["# end"])
        nvRanges(result, long)
    }
}

private func nvParts(_ kind: SyntaxToken.Kind, _ tokens: [SyntaxToken], _ text: String) -> [String] {
    tokens.filter { $0.kind == kind }.map { (text as NSString).substring(with: $0.range) }
}

private func nvRanges(_ tokens: [SyntaxToken], _ text: String) {
    var end = 0
    let length = text.utf16.count
    for token in tokens {
        #expect(token.range.location >= end && token.range.length > 0)
        #expect(NSMaxRange(token.range) <= length)
        end = NSMaxRange(token.range)
    }
}
