import AppKit
import Darwin
import PDFKit
import Synchronization
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct PDFPreviewTests {
    @Test func sandboxDecoderRejectsListedAndReplacedLinks() async throws {
        let fixture = try PDFFixture()
        defer { fixture.finish() }
        let target = try fixture.write("target.pdf")
        let link = fixture.root.appendingPathComponent("link.pdf")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target.url)
        for listedAsLink in [false, true] {
            let item = DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: listedAsLink)
            await #expect(throws: PDFPreview.Failure.symbolicLink) { _ = try await PDFPreview.read(item, followingLinks: false) }
        }
        #expect(try await PDFPreview.read(target, followingLinks: false).pageCount == 1)
        var reads = 0
        let state = PDFPreviewState(read: { _ in reads += 1; return PDFDocument() })
        await state.load(DetailsSelection(item: DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: true), listingRevision: UUID()), followingLinks: false)
        #expect(reads == 0 && state.document == nil && state.errorMessage?.contains("Link previews") == true)
    }

    @Test(arguments: [false, true])
    func readersRetainAccessAfterCancellationOrSupersession(cancelled: Bool) async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<PDFDocument, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let released = Mutex(0)
        let state = PDFPreviewState(read: { _ in
            try await withCheckedThrowingContinuation { source.yield($0) }
        })
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/selected/document.pdf"), isDirectory: false)
        let pending = Task {
            await state.load(DetailsSelection(item: item, listingRevision: UUID(), access: DirectoryAccess(root: item.url.deletingLastPathComponent()) {
                released.withLock { $0 += 1 }
            }))
        }
        let read = try #require(await iterator.next())
        if cancelled { pending.cancel() }
        await state.load(nil)
        #expect(released.withLock { $0 } == 0)
        read.resume(returning: PDFDocument())
        await pending.value
        #expect(released.withLock { $0 } == 1)
        #expect(state.selection == nil && state.document == nil && state.errorMessage == nil)
    }

    @Test func pagesLoadWithoutChangingSourceOrEnablingFormActions() async throws {
        let fixture = try PDFFixture()
        defer { fixture.finish() }
        let item = try fixture.write("document.PDF", pages: 2)
        let source = try #require(PDFDocument(url: item.url))
        let page = try #require(source.page(at: 0))
        let field = PDFAnnotation(bounds: CGRect(x: 20, y: 20, width: 150, height: 30), forType: .widget, withProperties: nil)
        field.widgetFieldType = .text
        field.widgetStringValue = "Saved value"
        field.action = PDFActionURL(url: URL(string: "https://example.invalid/form")!)
        page.addAnnotation(field)
        let link = PDFAnnotation(bounds: CGRect(x: 20, y: 80, width: 100, height: 30), forType: .link, withProperties: nil)
        link.destination = PDFDestination(page: try #require(source.page(at: 1)), at: .zero)
        page.addAnnotation(link)
        try #require(source.write(to: item.url))
        let bytes = try Data(contentsOf: item.url)
        let document = try await PDFPreview.read(item)
        #expect(document.pageCount == 2 && document.documentURL == nil)
        let loadedField = try #require(document.page(at: 0)?.annotations.first)
        #expect(loadedField.isReadOnly)
        #expect(loadedField.action == nil)
        #expect(loadedField.widgetStringValue == "Saved value")
        let loadedLink = try #require(document.page(at: 0)?.annotations.first { $0.type == "Link" })
        #expect(loadedLink.action == nil && loadedLink.destination == nil)
        #expect(try Data(contentsOf: item.url) == bytes)
        let symlink = fixture.root.appendingPathComponent("linked.pdf")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: item.url)
        #expect(try await PDFPreview.read(DirectoryEntry(url: symlink, isDirectory: false, isSymbolicLink: true)).pageCount == 2)
        #expect(PDFPreview.supports(item) && !ImagePreview.supports(item))
        #expect(!PDFPreview.supports(DirectoryEntry(url: item.url, isDirectory: true)))
        #expect(!PDFPreview.supports(DirectoryEntry(url: item.url, isDirectory: false, isPackage: true)))
        #expect(!PDFPreview.supports(DirectoryEntry(url: fixture.root.appendingPathComponent("notes.txt"), isDirectory: false)))
    }

    @Test func invalidLockedOversizedAndSpecialFilesHaveHonestFailures() async throws {
        let fixture = try PDFFixture()
        defer { fixture.finish() }
        let item = try fixture.write("locked.pdf")
        let document = try #require(PDFDocument(url: item.url))
        try #require(document.write(to: item.url, withOptions: [.ownerPasswordOption: "owner", .userPasswordOption: "reader"]))
        await #expect(throws: PDFPreview.Failure.locked) { _ = try await PDFPreview.read(item) }
        let corrupt = fixture.root.appendingPathComponent("corrupt.pdf")
        try Data("not a PDF".utf8).write(to: corrupt)
        await #expect(throws: PDFPreview.Failure.unsupported) { _ = try await PDFPreview.read(DirectoryEntry(url: corrupt, isDirectory: false)) }
        let oversized = fixture.root.appendingPathComponent("oversized.pdf")
        try Data().write(to: oversized)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(PDFPreview.maximumBytes + 1))
        try handle.close()
        await #expect(throws: PDFPreview.Failure.tooLarge) { _ = try await PDFPreview.read(DirectoryEntry(url: oversized, isDirectory: false)) }
        let manyPages = try fixture.write("many-pages.pdf", pages: PDFPreview.maximumPages + 1)
        await #expect(throws: PDFPreview.Failure.tooManyPages) { _ = try await PDFPreview.read(manyPages) }
        let huge = try fixture.write("huge-page.pdf", size: CGSize(width: PDFPreview.maximumPageDimension + 1, height: 100))
        await #expect(throws: PDFPreview.Failure.dimensions) { _ = try await PDFPreview.read(huge) }
        let fifo = fixture.root.appendingPathComponent("pipe.pdf")
        try #require(mkfifo(fifo.path, 0o600) == 0)
        await #expect(throws: PDFPreview.Failure.nonRegularFile) { _ = try await PDFPreview.read(DirectoryEntry(url: fifo, isDirectory: false)) }
        await #expect(throws: (any Error).self) {
            _ = try await PDFPreview.read(DirectoryEntry(url: fixture.root.appendingPathComponent("missing.pdf"), isDirectory: false))
        }
        await #expect(throws: PDFPreview.Failure.unsupported) {
            _ = try await PDFPreview.read(DirectoryEntry(url: URL(string: "https://example.invalid/document.pdf")!, isDirectory: false))
        }
    }

    @Test(arguments: [false, true], [false, true])
    func staleResultsCannotReplaceTheCurrentOrStoppedDocument(olderFails: Bool, stopped: Bool) async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<PDFDocument, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = PDFPreviewState(read: { _ in try await withCheckedThrowingContinuation { source.yield($0) } })
        let selection = DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/pdf-fixture/document.pdf"), isDirectory: false), listingRevision: UUID())
        let old = Task { await state.load(selection) }
        let oldRead = try #require(await iterator.next())
        let latestSelection = DetailsSelection(item: selection.item, listingRevision: UUID())
        let latest = Task { await state.load(latestSelection) }
        let latestRead = try #require(await iterator.next())
        let document = PDFDocument()
        let identity = ObjectIdentifier(document)
        latestRead.resume(returning: document)
        await latest.value
        if stopped { state.stop() }
        if olderFails { oldRead.resume(throwing: PDFPreview.Failure.unsupported) }
        else { oldRead.resume(returning: PDFDocument()) }
        await old.value
        #expect(state.selection == (stopped ? nil : latestSelection))
        #expect(stopped ? state.document == nil : state.document.map(ObjectIdentifier.init) == identity)
        #expect(state.errorMessage == nil && !state.isLoading)
    }

    @Test func cancelledLoadingCannotPublishAndRefreshReplacesTheDocument() async throws {
        let fixture = try PDFFixture()
        defer { fixture.finish() }
        let item = try fixture.write("refresh.pdf")
        let state = PDFPreviewState()
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        let old = { [weak document = state.document] in document }
        _ = try fixture.write("refresh.pdf", pages: 2)
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        #expect(state.document?.pageCount == 2 && old() == nil)
        await state.load(nil)
        #expect(state.selection == nil && state.document == nil)
        let cancelled = PDFPreviewState(read: { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return PDFDocument()
        })
        await Task { await cancelled.load(DetailsSelection(item: item, listingRevision: UUID())) }.value
        #expect(cancelled.document == nil && cancelled.errorMessage == nil && !cancelled.isLoading)
    }

    @Test func nativeViewerFitsZoomsRetainsItsPageAndDetaches() throws {
        _ = NSApplication.shared
        let fixture = try PDFFixture()
        defer { fixture.finish() }
        let document = try #require(PDFDocument(url: fixture.write("viewer.pdf", pages: 2).url))
        let viewer = PDFPreviewContainer(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
        let window = NSWindow(contentRect: viewer.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = viewer
        window.orderFront(nil)
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        viewer.show(document, name: "viewer.pdf")
        viewer.layoutSubtreeIfNeeded()
        let pdf = viewer.pdfView
        #expect(pdf.displayMode == .singlePageContinuous && pdf.autoScales && !pdf.acceptsDraggedFiles && !pdf.isInMarkupMode)
        let fitted = pdf.scaleFactor
        viewer.zoomIn(nil)
        #expect(pdf.scaleFactor > fitted && !pdf.autoScales)
        let zoomed = pdf.scaleFactor
        let second = try #require(document.page(at: 1))
        pdf.go(to: second)
        viewer.show(document, name: "viewer.pdf")
        #expect(pdf.scaleFactor == zoomed && pdf.currentPage === second)
        viewer.fitWidth(nil)
        #expect(pdf.autoScales && abs(pdf.scaleFactor - fitted) < 0.01)
        window.close()
        #expect(pdf.document == nil)
    }
}

private struct PDFFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-pdf-" + UUID().uuidString)
    init() throws { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    func finish() { try? FileManager.default.removeItem(at: root) }
    func write(_ name: String, pages: Int = 1, size: CGSize = CGSize(width: 612, height: 792)) throws -> DirectoryEntry {
        let url = root.appendingPathComponent(name)
        let consumer = try #require(CGDataConsumer(url: url as CFURL))
        var bounds = CGRect(origin: .zero, size: size)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &bounds, nil))
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(red: 0.65, green: 0.4, blue: 0.85, alpha: 1))
            context.fill(CGRect(x: 20, y: 20, width: 100, height: 80))
            context.endPDFPage()
        }
        context.closePDF()
        return DirectoryEntry(url: url, isDirectory: false)
    }
}
