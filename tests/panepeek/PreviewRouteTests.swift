import AppKit
import AVFoundation
import PDFKit
import Synchronization
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct PreviewRouteTests {
    nonisolated private static let formats: [(String, PreviewRoute)] = [
        ("notes.txt", .source(.text)), ("unknown.bin", .source(.text)),
        ("code.ts", .source(.text)), ("CODE.MTS", .source(.text)),
        ("readme.md", .source(.markdown)), ("README.MD", .source(.markdown)),
        ("art.svg", .source(.svg)), ("ART.SVG", .source(.svg)),
        ("page.html", .source(.html)), ("PAGE.HTM", .source(.html)),
        ("image.png", .image), ("IMAGE.JPEG", .image),
        ("movie.mp4", .video), ("MOVIE.MOV", .video), ("movie.m2ts", .video),
        ("document.pdf", .pdf), ("DOCUMENT.PDF", .pdf)
    ]

    @Test(arguments: formats)
    func existingFormatPrecedenceSelectsOnePresentation(format: (String, PreviewRoute)) {
        #expect(PreviewRoute(item(format.0)) == format.1)
    }

    @Test(arguments: [("Makefile.notes.md", "README.md"), ("Dockerfile.notes.MD", "README.md"),
                      ("Makefile.json", "Makefile"), ("Dockerfile.swift", "Dockerfile")])
    func buildFilePrefixCollisionsKeepOneDecisionInPreviewAndEdit(name: String, control: String) async throws {
        let source = "# Title\nall: build\nFROM alpine # note\n"
        let markdown = control == "README.md"
        #expect(PreviewRoute(item(name)) == (markdown ? .source(.markdown) : .source(.text)))
        let expected = try await SyntaxHighlighting.tokens(in: source, fileName: control)
        let state = PreviewState(read: { _ in .text(source) })
        await state.load(DetailsSelection(item: item(name), listingRevision: UUID()))
        #expect(state.preview == .text(source) && state.tokens == expected)
        await state.setMode(.edit)?.value
        #expect(state.mode == .edit && state.tokens == expected)
    }

    @Test func emptyAndContainerSelectionsRetainTheirUnavailableTextPath() async {
        #expect(PreviewRoute(nil) == .none)
        for entry in [DirectoryEntry(url: URL(fileURLWithPath: "/route/folder.svg"), isDirectory: true),
                      DirectoryEntry(url: URL(fileURLWithPath: "/route/package.pdf"), isDirectory: false, isPackage: true)] {
            let state = PreviewState()
            let selection = DetailsSelection(item: entry, listingRevision: UUID())
            let route = PreviewRoute(entry)
            #expect(route.isSource)
            await BuiltInPreviewState().load(selection, registration: BuiltInPreviewCatalogue.registration(for: entry), preview: state)
            #expect(state.text == nil && !state.canBeginEditing)
            #expect(state.preview == .unavailable(entry.isPackage ? .package : .folder))
        }
    }

    @Test(arguments: ["code.ts", "art.svg", "page.html", "readme.md", "image.png", "movie.mov", "document.pdf"])
    func onlyTheSelectedReaderStartsWork(name: String) async throws {
        let reads = Mutex<[String: Int]>([:])
        let preview = PreviewState(read: { _ in reads.withLock { $0["text", default: 0] += 1 }; return .text("") })
        let image = ImagePreviewState(read: { _ in
            reads.withLock { $0["image", default: 0] += 1 }
            return try Self.image()
        })
        let video = VideoPreviewState(prepare: { _, _ in
            reads.withLock { $0["video", default: 0] += 1 }
            return VideoPreview.Prepared(item: AVPlayerItem(asset: AVMutableComposition()))
        })
        let pdf = PDFPreviewState(read: { _ in reads.withLock { $0["pdf", default: 0] += 1 }; return PDFDocument() })
        let selection = DetailsSelection(item: item(name), listingRevision: UUID())
        let route = PreviewRoute(selection.item)
        let presentations = BuiltInPreviewState(image: image, video: video, pdf: pdf)
        await presentations.load(selection, registration: BuiltInPreviewCatalogue.registration(for: selection.item), preview: preview)
        let reader = route.isSource ? "text" : name.hasSuffix("png") ? "image" : name.hasSuffix("mov") ? "video" : "pdf"
        #expect(reads.withLock { $0 } == [reader: 1])
        let host = BuiltInPreviewHost(selection: selection, preview: preview, presentations: presentations, notifications: OperationNotifications())
        #expect(host.canCopyFileContent == route.isSource)
        await presentations.load(nil, registration: nil, preview: preview)
        #expect(preview.selection == nil && image.image == nil && video.player == nil && pdf.document == nil)
        #expect(reads.withLock { $0 } == [reader: 1])
    }

    @Test(arguments: [false, true])
    func aLateMediaResultCannotReplaceTheCurrentSource(fails: Bool) async throws {
        try await withNativeTestScope { scope in
            let request: NativeTestRequest<Void> = scope.request("old image")
            let image = ImagePreviewState(read: { _ in
                try await request.value()
                if fails { throw CocoaError(.fileReadCorruptFile) }
                return try Self.image()
            })
            let preview = PreviewState(read: { _ in .text("current source") })
            let video = VideoPreviewState()
            let pdf = PDFPreviewState()
            let first = DetailsSelection(item: item("old.png"), listingRevision: UUID())
            let presentations = BuiltInPreviewState(image: image, video: video, pdf: pdf)
            let old = Task { await presentations.load(first, registration: BuiltInPreviewCatalogue.registration(for: first.item), preview: preview) }
            scope.track(old)
            try await request.started.wait()
            old.cancel()
            let current = DetailsSelection(item: item("current.ts"), listingRevision: UUID())
            let route = PreviewRoute(current.item)
            await presentations.load(current, registration: BuiltInPreviewCatalogue.registration(for: current.item), preview: preview)
            request.result.signal(())
            await old.value
            #expect(preview.selection == current && preview.text == "current source")
            #expect(image.selection == nil && image.image == nil && image.errorMessage == nil)
            #expect(route == .source(.text))
        }
    }

    nonisolated private static func image() throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try #require(context.makeImage())
    }

    private func item(_ name: String) -> DirectoryEntry {
        DirectoryEntry(url: URL(fileURLWithPath: "/route/\(name)"), isDirectory: false)
    }
}
