import AppKit
import Darwin
import ImageIO
import Testing
import Synchronization
import UniformTypeIdentifiers
import PanePeekCore
@testable import PanePeek

struct ImagePreviewTests {
    @Test func sandboxDecoderRejectsListedAndReplacedLinks() async throws {
        let fixture = try ImageFixture()
        defer { fixture.finish() }
        let target = try fixture.write("target.png", width: 16, height: 8)
        let link = fixture.root.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target.url)
        for listedAsLink in [false, true] {
            let item = DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: listedAsLink)
            await #expect(throws: ImagePreview.Failure.symbolicLink) { try await ImagePreview.read(item, followingLinks: false) }
        }
        let image = try await ImagePreview.read(target, followingLinks: false)
        #expect(image.width == 16 && image.height == 8)
        let rotated = try fixture.write("rotated.jpg", width: 120, height: 60, orientation: 6)
        let oriented = try await ImagePreview.read(rotated, followingLinks: false)
        #expect(oriented.width == 60 && oriented.height == 120)
    }

    @Test @MainActor func sandboxLinkPolicyRejectsBeforeCallingTheReader() async {
        let reads = Mutex(0)
        let state = ImagePreviewState(read: { _ in
            reads.withLock { $0 += 1 }
            return try ImageFixture.image(width: 16, height: 8)
        })
        let link = DirectoryEntry(url: URL(fileURLWithPath: "/selected/link.png"), isDirectory: false, isSymbolicLink: true)
        await state.load(DetailsSelection(item: link, listingRevision: UUID()), followingLinks: false)
        #expect(reads.withLock { $0 } == 0)
        #expect(state.image == nil && state.errorMessage?.contains("Link previews") == true && !state.isLoading)
    }

    @Test(arguments: [false, true]) @MainActor
    func imageReadersRetainAccessAfterCancellationOrSupersession(cancelled: Bool) async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<CGImage, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let released = Mutex(0)
        let state = ImagePreviewState(read: { _ in
            try await withCheckedThrowingContinuation { source.yield($0) }
        })
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/selected/image.png"), isDirectory: false)
        let pending = Task {
            await state.load(DetailsSelection(item: item, listingRevision: UUID(), access: DirectoryAccess(root: item.url.deletingLastPathComponent()) {
                released.withLock { $0 += 1 }
            }))
        }
        let read = try #require(await iterator.next())
        if cancelled { pending.cancel() }
        await state.load(nil)
        #expect(released.withLock { $0 } == 0)
        read.resume(returning: try ImageFixture.image(width: 16, height: 8))
        await pending.value
        #expect(released.withLock { $0 } == 1)
        #expect(state.selection == nil && state.image == nil && state.errorMessage == nil)
    }

    @Test func thumbnailFitsItsBoundsAndAppliesOrientation() async throws {
        let fixture = try ImageFixture()
        defer { fixture.finish() }
        let wide = try fixture.write("wide.png", width: 4096, height: 128)
        let thumbnail = try await ImagePreview.read(wide)
        #expect(thumbnail.width == 2048 && thumbnail.height == 64)
        let rotated = try fixture.write("rotated.jpg", width: 120, height: 60, orientation: 6)
        let oriented = try await ImagePreview.read(rotated)
        #expect(oriented.width == 60 && oriented.height == 120)
        let animated = fixture.root.appendingPathComponent("animated.gif")
        let destination = try #require(CGImageDestinationCreateWithURL(animated as CFURL, UTType.gif.identifier as CFString, 2, nil))
        CGImageDestinationAddImage(destination, try ImageFixture.image(width: 16, height: 8), nil)
        CGImageDestinationAddImage(destination, try ImageFixture.image(width: 8, height: 16), nil)
        try #require(CGImageDestinationFinalize(destination))
        let gif = try await ImagePreview.read(DirectoryEntry(url: animated, isDirectory: false))
        #expect(gif.width == 16 && gif.height == 16)
        let link = fixture.root.appendingPathComponent("linked.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: wide.url)
        #expect(try await ImagePreview.read(DirectoryEntry(url: link, isDirectory: false, isSymbolicLink: true)).width == 2048)
    }

    @Test(arguments: [false, true]) func invalidOversizedAndNonRegularFilesHaveNoDecodedImage(followingLinks: Bool) async throws {
        let fixture = try ImageFixture()
        defer { fixture.finish() }
        let corrupt = fixture.root.appendingPathComponent("corrupt.png")
        try Data("not an image".utf8).write(to: corrupt)
        await #expect(throws: ImagePreview.Failure.unsupported) { try await ImagePreview.read(DirectoryEntry(url: corrupt, isDirectory: false), followingLinks: followingLinks) }
        let misnamedPDF = fixture.root.appendingPathComponent("document.png")
        var page = CGRect(x: 0, y: 0, width: 100, height: 100)
        let consumer = try #require(CGDataConsumer(url: misnamedPDF as CFURL))
        let pdf = try #require(CGContext(consumer: consumer, mediaBox: &page, nil))
        pdf.beginPDFPage(nil)
        pdf.endPDFPage()
        pdf.closePDF()
        await #expect(throws: ImagePreview.Failure.unsupported) { try await ImagePreview.read(DirectoryEntry(url: misnamedPDF, isDirectory: false), followingLinks: followingLinks) }
        let oversized = fixture.root.appendingPathComponent("oversized.png")
        try Data().write(to: oversized)
        let file = try FileHandle(forWritingTo: oversized)
        try file.truncate(atOffset: UInt64(ImagePreview.maximumBytes + 1))
        try file.close()
        await #expect(throws: ImagePreview.Failure.tooLarge) { try await ImagePreview.read(DirectoryEntry(url: oversized, isDirectory: false), followingLinks: followingLinks) }
        let huge = try fixture.write("huge.jpg", width: 16, height: 8)
        var header = try Data(contentsOf: huge.url)
        let frame = try #require((0..<(header.count - 8)).first {
            header[$0] == 0xFF && [0xC0, 0xC1, 0xC2].contains(header[$0 + 1])
        })
        header.replaceSubrange((frame + 5)..<(frame + 9), with: [0x1F, 0x40, 0x23, 0x28])
        try header.write(to: huge.url)
        await #expect(throws: ImagePreview.Failure.dimensions) { try await ImagePreview.read(huge, followingLinks: followingLinks) }
        let fifo = fixture.root.appendingPathComponent("pipe.png")
        try #require(mkfifo(fifo.path, 0o600) == 0)
        await #expect(throws: ImagePreview.Failure.nonRegularFile) { try await ImagePreview.read(DirectoryEntry(url: fifo, isDirectory: false), followingLinks: followingLinks) }
        #expect(ImagePreview.supports(DirectoryEntry(url: corrupt, isDirectory: false)))
        #expect(ImagePreview.supports(DirectoryEntry(url: fixture.root.appendingPathComponent("UPPER.PNG"), isDirectory: false)))
        #expect(!ImagePreview.supports(DirectoryEntry(url: corrupt, isDirectory: true)))
        #expect(!ImagePreview.supports(DirectoryEntry(url: corrupt, isDirectory: false, isPackage: true)))
        #expect(!ImagePreview.supports(DirectoryEntry(url: fixture.root.appendingPathComponent("notes.txt"), isDirectory: false)))
    }

    @Test(arguments: [false, true], [false, true]) @MainActor
    func staleSuccessOrFailureCannotReplaceTheLatestImageOrClearedSelection(olderFails: Bool, cleared: Bool) async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<CGImage, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = ImagePreviewState(read: { _ in
            try await withCheckedThrowingContinuation { source.yield($0) }
        })
        let old = Task { await state.load(selection("old.png")) }
        let oldRead = try #require(await iterator.next())
        let latestSelection = selection("latest.png")
        let latest = Task { await state.load(latestSelection) }
        let latestRead = try #require(await iterator.next())
        let image = try ImageFixture.image(width: 16, height: 8)
        latestRead.resume(returning: image)
        await latest.value
        if cleared { await state.load(nil) }
        if olderFails { oldRead.resume(throwing: CocoaError(.fileReadNoPermission)) }
        else { oldRead.resume(returning: try ImageFixture.image(width: 8, height: 16)) }
        await old.value
        #expect(state.selection == (cleared ? nil : latestSelection))
        #expect(cleared ? state.image == nil : state.image === image)
        #expect(!state.isLoading && state.errorMessage == nil)
    }

    @Test @MainActor func refreshRereadsTheSameURLAndFailureClearsPreviousImage() async throws {
        let fixture = try ImageFixture()
        defer { fixture.finish() }
        let item = try fixture.write("refresh.png", width: 16, height: 8)
        let state = ImagePreviewState()
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        #expect(state.image?.width == 16)
        _ = try fixture.write("refresh.png", width: 8, height: 16)
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        #expect(state.image?.height == 16)
        try Data("corrupt".utf8).write(to: item.url)
        await state.load(DetailsSelection(item: item, listingRevision: UUID()))
        #expect(state.image == nil && state.errorMessage != nil && !state.isLoading)
        await state.load(selection("plain.txt"))
        #expect(state.image == nil && state.errorMessage == nil && state.selection == nil)
    }

    @Test @MainActor func cancelledReadCannotPublishAnImage() async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<CGImage, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = ImagePreviewState(read: { _ in
            try await withCheckedThrowingContinuation { source.yield($0) }
        })
        let pending = Task { await state.load(selection("cancelled.png")) }
        let read = try #require(await iterator.next())
        pending.cancel()
        read.resume(returning: try ImageFixture.image(width: 16, height: 8))
        await pending.value
        #expect(state.image == nil && state.errorMessage == nil && !state.isLoading)
    }

    private func selection(_ name: String) -> DetailsSelection {
        DetailsSelection(item: DirectoryEntry(url: URL(fileURLWithPath: "/image-fixture/" + name), isDirectory: false), listingRevision: UUID())
    }
}

private struct ImageFixture {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-images-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func finish() { try? FileManager.default.removeItem(at: root) }
    static func image(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.65, green: 0.4, blue: 0.85, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }
    func write(_ name: String, width: Int, height: Int, orientation: Int = 1) throws -> DirectoryEntry {
        let url = root.appendingPathComponent(name)
        let type = url.pathExtension == "jpg" ? UTType.jpeg : .png
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try Self.image(width: width, height: height),
                                  [kCGImagePropertyOrientation: orientation] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return DirectoryEntry(url: url, isDirectory: false)
    }
}
