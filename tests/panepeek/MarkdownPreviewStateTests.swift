import Foundation
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct MarkdownPreviewStateTests {
    @Test func rendersOnlyWhenPresentedAndReusesOnlyExactCurrentSource() async throws {
        var reads = [String]()
        let preview = MarkdownPreviewState(render: { source in
            reads.append(source.text)
            return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
        })
        let document = UUID()
        let saved = MarkdownPreviewState.Source(documentID: document, text: "# Café", baseURL: URL(fileURLWithPath: "/docs/"))
        await preview.load(saved, presenting: false)
        #expect(reads.isEmpty && preview.blocks(for: saved) == nil && !preview.isRendering)
        await preview.load(saved, presenting: true)
        #expect(preview.blocks(for: saved)?.map { String($0.content.characters) } == ["Café"])
        await preview.load(saved, presenting: false)
        await preview.load(saved, presenting: true)
        #expect(reads.count == 1)
        let decomposed = MarkdownPreviewState.Source(documentID: document, text: "# Cafe\u{301}", baseURL: saved.baseURL)
        #expect(saved.text == decomposed.text)
        await preview.load(decomposed, presenting: false)
        #expect(preview.blocks(for: saved) == nil)
        await preview.load(decomposed, presenting: true)
        #expect(reads.count == 2 && reads.last?.utf8.elementsEqual(decomposed.text.utf8) == true)
        preview.stop()
        #expect(preview.blocks(for: decomposed) == nil && !preview.isRendering)
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
        let renderer = MarkdownPreviewState()
        defer { renderer.stop() }
        await state.load(DetailsSelection(item: DirectoryEntry(url: url, isDirectory: false), listingRevision: UUID()))
        let savedPresentation = try presentation(state)
        await renderer.load(savedPresentation, presenting: true)
        #expect(state.text == source && renderer.blocks(for: savedPresentation)?.first?.kind == .code)
        let document = state.documentID
        state.setMode(.edit)
        let draft = source.replacingOccurrences(of: "Saved", with: "Draft")
        await state.updateText(draft)?.value
        state.setMode(.preview)
        let draftPresentation = try presentation(state)
        await renderer.load(draftPresentation, presenting: true)
        #expect(state.text == draft && state.isDirty && state.documentID == document)
        #expect(renderer.blocks(for: draftPresentation)?.first.map { String($0.content.characters).contains("title: Draft") } == true)
        #expect(try Data(contentsOf: url) == bom + Data(source.utf8))
        #expect(await state.save())
        #expect(try Data(contentsOf: url) == bom + Data(draft.utf8))
        state.setMode(.edit)
        await state.updateText("# Changed")?.value
        state.setMode(.preview)
        await renderer.load(try presentation(state), presenting: true)
        await state.discardChanges()?.value
        let discardedPresentation = try presentation(state)
        await renderer.load(discardedPresentation, presenting: true)
        #expect(state.text == draft && !state.isDirty && state.documentID != document)
        #expect(renderer.blocks(for: discardedPresentation)?.first?.kind == .code)
    }

    @Test(arguments: [false, true])
    func lateSuccessOrFailureCannotReplaceTheCurrentPresentation(fails: Bool) async throws {
        try await withNativeTestScope { scope in
            let request: NativeTestRequest<Void> = scope.request("old Markdown parse")
            let renderer = MarkdownPreviewState(render: { source in
                if source.text == "# Old" {
                    try await request.value()
                    if fails { throw CocoaError(.fileReadCorruptFile) }
                }
                return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
            })
            let old = MarkdownPreviewState.Source(documentID: UUID(), text: "# Old", baseURL: nil)
            let current = MarkdownPreviewState.Source(documentID: UUID(), text: "# Current", baseURL: nil)
            let pending = Task { await renderer.load(old, presenting: true) }
            scope.track(pending)
            try await request.started.wait()
            await renderer.load(current, presenting: true)
            request.result.signal(())
            await pending.value
            #expect(renderer.blocks(for: current)?.map { String($0.content.characters) } == ["Current"])
            #expect(renderer.blocks(for: old) == nil && !renderer.isRendering)
        }
    }

    @Test(arguments: [false, true])
    func stoppedOrCancelledWorkCannotPublishAndTheSameSourceCanRetry(stop: Bool) async throws {
        try await withNativeTestScope { scope in
            let request: NativeTestRequest<Void> = scope.request("cancelled Markdown parse")
            var reads = 0
            let renderer = MarkdownPreviewState(render: { source in
                reads += 1
                if reads == 1 { try await request.value() }
                return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
            })
            let source = MarkdownPreviewState.Source(documentID: UUID(), text: "# Current", baseURL: nil)
            let pending = Task { await renderer.load(source, presenting: true) }
            scope.track(pending)
            try await request.started.wait()
            #expect(renderer.isRendering && renderer.isPending(source))
            if stop { renderer.stop() } else { pending.cancel() }
            request.result.signal(())
            await pending.value
            #expect(renderer.blocks(for: source) == nil && !renderer.isRendering)
            await renderer.load(source, presenting: true)
            #expect(reads == 2 && renderer.blocks(for: source)?.isEmpty == false)
        }
    }

    @Test func failedRenderingFallsBackToSourceAndAllowsRetry() async {
        var reads = 0
        let renderer = MarkdownPreviewState(render: { source in
            reads += 1
            if reads == 1 { throw CocoaError(.fileReadCorruptFile) }
            return try await MarkdownRendering.blocks(in: source.text, baseURL: source.baseURL)
        })
        let source = MarkdownPreviewState.Source(documentID: UUID(), text: "# Current", baseURL: nil)
        await renderer.load(source, presenting: true)
        #expect(!renderer.isPending(source) && !renderer.isRendering && renderer.blocks(for: source) == nil)
        await renderer.load(source, presenting: true)
        #expect(reads == 2 && renderer.blocks(for: source)?.isEmpty == false)
    }

    private func presentation(_ state: PreviewState) throws -> MarkdownPreviewState.Source {
        MarkdownPreviewState.Source(documentID: state.documentID, text: try #require(state.text),
                                    baseURL: state.selection?.item.url.deletingLastPathComponent())
    }
}
