import Foundation
import Testing
@testable import PanePeekCore

struct MarkdownRenderingTests {
    @Test(arguments: ["\n", "\r\n", "\r"], ["---", "..."])
    func frontMatterKeepsLiteralYAMLBeforeTheMarkdownBody(newline: String, closing: String) async throws {
        let yaml = ["--- \t", "title: \"**literal** [link](https://example.com)\"", "description: |",
                    "  ```", "  ---", "  <b>literal</b>", "enabled: true", closing + "\t"].joined(separator: newline)
        let blocks = try await MarkdownRendering.blocks(in: yaml + newline + newline + "# Body" + newline + newline + "---")
        let metadata = try #require(blocks.first)
        #expect(metadata.kind == .code && String(metadata.content.characters) == yaml)
        #expect(metadata.content.runs.allSatisfy { $0.link == nil && $0.inlinePresentationIntent == nil })
        #expect(metadata.tokens.contains(SyntaxToken(range: (yaml as NSString).range(of: "title"), kind: .key)))
        #expect(blocks.dropFirst().map(\.kind) == [.heading(level: 1), .thematicBreak])
        #expect(String(blocks[1].content.characters) == "Body")
    }

    @Test(arguments: ["\n---\ntitle: Example\n---\n\n# Body", " ---\ntitle: Example\n---\n\n# Body",
                      "----\ntitle: Example\n---\n\n# Body", "---\ntitle: Example\n\n# Body",
                      "Intro\n\n---\ntitle: Example\n---\n\n# Body"])
    func ordinaryMarkdownAndUnclosedMetadataAreNotFrontMatter(source: String) async throws {
        let blocks = try await MarkdownRendering.blocks(in: source)
        #expect(blocks.first?.kind != .code)
        #expect(blocks.contains { $0.kind == .heading(level: 1) && String($0.content.characters) == "Body" })
    }

    @Test(arguments: ["---\n---", "---\n...\n", "\u{FEFF}---\r\n---"])
    func emptyFrontMatterWithoutABodyKeepsItsDelimiters(source: String) async throws {
        let blocks = try await MarkdownRendering.blocks(in: source)
        #expect(blocks.count == 1 && blocks.first?.kind == .code)
        #expect(blocks.first?.tokens.isEmpty == false)
    }

    @Test @MainActor func previewingFrontMatterDraftsPreservesSourceAndSavedBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("markdown-front-matter-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("notes.md")
        let source = "---\r\ntitle: Saved\r\ninvalid: [\r\n---\r\n\r\n# Body\r\n"
        let bom = Data([0xEF, 0xBB, 0xBF])
        try (bom + Data(source.utf8)).write(to: url)
        let state = PreviewState()
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        #expect(state.text == source && state.markdown?.first?.kind == .code)
        let document = state.documentID
        state.setMode(.edit)
        let draft = source.replacingOccurrences(of: "Saved", with: "Draft")
        await state.updateText(draft)?.value
        await state.setMode(.preview)?.value
        #expect(state.text == draft && state.isDirty && state.documentID == document)
        #expect(state.markdown?.first.map { String($0.content.characters).contains("title: Draft") } == true)
        #expect(try Data(contentsOf: url) == bom + Data(source.utf8))
        #expect(await state.save())
        #expect(try Data(contentsOf: url) == bom + Data(draft.utf8))
    }

    @Test func blocksKeepStructureAndInlineTextWithoutMarkdownSyntax() async throws {
        let text = """
        # Title *em*

        Para with **bold** and `code`
        soft line\u{20}\u{20}
        hard break

        - one
        - two
          - nested

          second paragraph
        3. third
        - [ ] open
        - [x] done

        > quote
        > > inner

        ```swift
        let x = 1

        print(x)
        ```

        ---

        <div>raw</div>
        """
        let blocks = try await MarkdownRendering.blocks(in: text)
        #expect(blocks.map(\.kind) == [.heading(level: 1), .paragraph, .paragraph, .paragraph, .paragraph, .paragraph,
                                       .paragraph, .paragraph, .paragraph, .paragraph, .paragraph, .code, .thematicBreak, .code])
        #expect(blocks.map { String($0.content.characters) } == [
            "Title em", "Para with bold and code soft line\nhard break", "one", "two", "nested", "second paragraph",
            "third", "open", "done", "quote", "inner", "let x = 1\n\nprint(x)", "", "<div>raw</div>"
        ])
        #expect(blocks.map(\.marker) == [nil, nil, "•", "•", "◦", nil, "3.", "☐", "☑", nil, nil, nil, nil, nil])
        #expect(blocks[4].containers.count == 2 && blocks[5].containers == blocks[3].containers)
        #expect(blocks[10].containers.count == 2 && blocks[10].containers.first == blocks[9].containers.first)
        let strong = try #require(blocks[1].content.runs.first { $0.inlinePresentationIntent == .stronglyEmphasized })
        #expect(String(blocks[1].content[strong.range].characters) == "bold")
    }

    @Test func tableCellsShareTheirTableAndKeepRowsAndColumns() async throws {
        let blocks = try await MarkdownRendering.blocks(in: "| A | B |\n|---|:-:|\n| 1 | 2 |\n\n| C |\n|---|\n| 3 |")
        let cells = blocks.compactMap { block -> [Int]? in
            guard case .tableCell(let table, let row, let column, let columns) = block.kind else { return nil }
            return [table, row, column, columns]
        }
        #expect(blocks.map { String($0.content.characters) } == ["A", "B", "1", "2", "C", "3"])
        #expect(cells.map { Array($0.dropFirst()) } == [[0, 0, 2], [0, 1, 2], [1, 0, 2], [1, 1, 2], [0, 0, 1], [1, 0, 1]])
        #expect(Set(cells.prefix(4).map(\.[0])).count == 1 && cells[0][0] != cells[4][0])
    }

    @Test func emptyTableHeadersCellsAndRowsKeepTheirStructure() async throws {
        let empty = try await MarkdownRendering.blocks(in: "| | |\n|---|---|\n| | |")
        let gaps = try await MarkdownRendering.blocks(in: "| A | |\n|---|---|\n| | |\n| 1 | 2 |\n\n```\n| | |\n|---|---|\n```")
        func cells(_ blocks: [MarkdownBlock]) -> [[Int]] {
            blocks.compactMap { block in
                guard case .tableCell(_, let row, let column, _) = block.kind else { return nil }
                return [row, column]
            }
        }
        #expect(cells(empty) == [[0, 0], [0, 1], [1, 0], [1, 1]])
        #expect(empty.allSatisfy { $0.content.characters.isEmpty })
        #expect(cells(gaps) == [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]])
        #expect(gaps.map { String($0.content.characters) } == ["A", "", "", "", "1", "2", "| | |\n|---|---|"])
    }

    @Test func fencedCodeUsesKnownLanguageHighlightingAndLinksResolveLocally() async throws {
        let text = "```swift\nlet x = 1\n```\n\n```python\nimport os\n```\n\n```unknown\nlet y\n```\n\n[doc](notes/a.md) [web](https://example.com)"
        let blocks = try await MarkdownRendering.blocks(in: text, baseURL: URL(fileURLWithPath: "/docs/", isDirectory: true))
        #expect(blocks[0].tokens.contains(SyntaxToken(range: NSRange(location: 0, length: 3), kind: .keyword)))
        #expect(blocks[1].tokens.contains(SyntaxToken(range: NSRange(location: 0, length: 6), kind: .keyword)))
        #expect(blocks[2].tokens.isEmpty && blocks[3].tokens.isEmpty)
        #expect(blocks[3].content.runs.compactMap(\.link).map(\.absoluteString) == ["file:///docs/notes/a.md", "https://example.com"])
    }

    @Test @MainActor func previewRendersTheCurrentMarkdownTextWhileEditKeepsSource() async throws {
        let state = PreviewState(read: { _ in .text("# Saved") })
        await state.load(markdownSelection("notes.txt"))
        #expect(state.markdown == nil)
        await state.load(markdownSelection("notes.md"))
        #expect(rendered(state) == ["Saved"])
        state.setMode(.edit)
        await state.updateText("# Draft")?.value
        #expect(state.markdown == nil)
        let stale = state.setMode(.preview)
        state.setMode(.edit)
        await state.updateText("# Latest")?.value
        await stale?.value
        #expect(state.markdown == nil)
        await state.setMode(.preview)?.value
        #expect(rendered(state) == ["Latest"])
        await state.discardChanges()?.value
        #expect(rendered(state) == ["Saved"] && state.text == "# Saved" && !state.isDirty)
        await state.load(nil)
        #expect(state.markdown == nil)
    }

    @Test func onlyMarkdownFileNamesRender() {
        #expect(MarkdownRendering.isMarkdown("README.md") && MarkdownRendering.isMarkdown("notes.MD"))
        #expect(!MarkdownRendering.isMarkdown("md") && !MarkdownRendering.isMarkdown("notes.txt") && !MarkdownRendering.isMarkdown("archive.md.zip"))
    }
}

@MainActor private func rendered(_ state: PreviewState) -> [String]? {
    state.markdown?.map { String($0.content.characters) }
}

private func markdownSelection(_ name: String) -> DetailsSelection {
    DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/markdown/\(name)"), isDirectory: false), listingRevision: UUID())
}
