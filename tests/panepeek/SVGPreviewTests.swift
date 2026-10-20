import AppKit
import Testing
import WebKit
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct SVGPreviewTests {
    @Test func svgUsesTheTextEditorInsteadOfTheReadOnlyImageRoute() async throws {
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/svg-fixture/art.SVG"), isDirectory: false)
        #expect(SVGPreview.isSVG(item.name) && !ImagePreview.supports(item))
        #expect(!SVGPreview.isSVG("art.svg.zip") && !SVGPreview.isSVG("svg"))
        let text = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path fill=\"red\"/></svg>"
        let preview = PreviewState(read: { _ in .text(text) })
        await preview.load(DetailsSelection(item: item, listingRevision: UUID()))
        #expect(preview.canEdit && !preview.tokens.isEmpty)
        #expect(preview.tokens == (try await SyntaxHighlighting.tokens(in: text, fileExtension: "xml")))
        preview.setMode(.edit)
        await preview.updateText(text.replacingOccurrences(of: "red", with: "blue"))?.value
        preview.setMode(.preview)
        #expect(preview.isDirty && preview.text?.contains("blue") == true)
    }

    @Test(arguments: ["width=\"200\" height=\"100\"", ""])
    func staticRenderingKeepsAspectRatioAndInternalGradients(dimensions: String) async throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" \(dimensions) viewBox="0 0 200 100">
          <defs><linearGradient id="paint"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>
          <rect width="200" height="100" fill="url(#paint)"/>
        </svg>
        """
        let image = try await SVGPreview.read(svg)
        #expect(image.width == ImagePreview.maximumDimension && image.height == ImagePreview.maximumDimension / 2)
        let pixel = try sample(image)
        #expect(pixel[0] > 50 && pixel[1] < 10 && pixel[2] > 50 && pixel[3] > 250)
    }

    @Test(arguments: ["not SVG", "<svg", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>text</body></html>"])
    func malformedOrNonSVGContentFails(source: String) async {
        await #expect(throws: (any Error).self) { try await SVGPreview.read(source) }
    }

    @Test func rasterisationKeepsACircleRoundInANonSquareViewport() async throws {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400\" height=\"240\" viewBox=\"0 0 400 240\"><circle cx=\"200\" cy=\"120\" r=\"64\" fill=\"red\"/></svg>"
        let image = try await SVGPreview.read(svg)
        var pixels = [UInt8](repeating: 0, count: 400 * 240 * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: 400, height: 240, bitsPerComponent: 8,
                                               bytesPerRow: 400 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 400, height: 240))
        }
        let horizontal = (0..<400).count { pixels[(120 * 400 + $0) * 4 + 3] > 128 }
        let vertical = (0..<240).count { pixels[($0 * 400 + 200) * 4 + 3] > 128 }
        #expect(abs(horizontal - 128) <= 2 && abs(vertical - 128) <= 2)
    }

    @Test func oversizedSourceIsRejected() async throws {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><desc>"
            + String(repeating: "x", count: TextPreview.maximumBytes) + "</desc></svg>"
        do {
            _ = try await SVGPreview.read(svg)
            Issue.record("SVG input exceeded the size limit without rejection.")
        } catch SVGPreview.Failure.tooLarge {}
    }

    @Test func imageDecodingCannotRunSourceScriptsOrLoadReferencedResources() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("svg-reference-\(UUID()).png")
        let png = try #require(NSBitmapImageRep(cgImage: solidImage(width: 2, height: 2)).representation(using: .png, properties: [:]))
        try png.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let requests = SVGResourceRequests()
        let configuration = SVGRenderer.configuration()
        configuration.setURLSchemeHandler(requests, forURLScheme: "panepeek-test")
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"
             onload="document.getElementById('paint').setAttribute('fill','red')">
          <style>@import url('panepeek-test://resources/style.css');</style>
          <rect id="paint" width="100" height="50" fill="blue"/>
          <image width="100" height="50" href="panepeek-test://resources/image.png"/>
          <image width="100" height="50" href="\(file.absoluteString)"/>
          <script>document.getElementById('paint').setAttribute('fill','red'); fetch('panepeek-test://resources/script');</script>
        </svg>
        """
        let image = try await SVGRenderer(configuration: configuration).render(svg)
        let pixel = try sample(image)
        #expect(pixel[0] < 10 && pixel[1] < 10 && pixel[2] > 250 && pixel[3] > 250)
        #expect(requests.urls.isEmpty)
    }

    @Test(arguments: [false, true])
    func staleSuccessOrFailureCannotReplaceTheCurrentDraftImage(olderFails: Bool) async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<CGImage, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let preview = SVGPreviewState(read: { _ in
            try await withCheckedThrowingContinuation { source.yield($0) }
        })
        let old = Task { await preview.load("old") }
        let oldRead = try #require(await iterator.next())
        let latest = Task { await preview.load("latest") }
        let latestRead = try #require(await iterator.next())
        latestRead.resume(returning: try solidImage(width: 14, height: 9))
        await latest.value
        if olderFails { oldRead.resume(throwing: CocoaError(.fileReadCorruptFile)) }
        else { oldRead.resume(returning: try solidImage(width: 12, height: 8)) }
        await old.value
        #expect(preview.image?.height == 9 && preview.errorMessage == nil && !preview.isLoading)
    }

    @Test func cancelledRenderingCannotPublishAnImage() async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<CGImage, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let preview = SVGPreviewState(read: { _ in
            try await withCheckedThrowingContinuation { source.yield($0) }
        })
        let pending = Task { await preview.load("cancelled") }
        let read = try #require(await iterator.next())
        pending.cancel()
        read.resume(returning: try solidImage(width: 12, height: 8))
        await pending.value
        #expect(preview.image == nil && preview.errorMessage == nil && !preview.isLoading)
    }

    private func solidImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                           bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    private func sample(_ image: CGImage) throws -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                               bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: -image.width / 2, y: -image.height / 2, width: image.width, height: image.height))
        }
        return pixel
    }
}

@MainActor private final class SVGResourceRequests: NSObject, WKURLSchemeHandler {
    private(set) var urls: [URL] = []
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url { urls.append(url) }
        urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
