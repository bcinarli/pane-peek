import PanePeekCore

/// Selects a built-in presentation without opening the item or constructing a renderer.
enum PreviewRoute: Equatable, Sendable {
    enum Source: Equatable, Sendable { case text, markdown, svg, html }
    case none, source(Source), image, video, pdf

    init(_ item: DirectoryEntry?) {
        guard let item else { self = .none; return }
        if ImagePreview.supports(item) { self = .image }
        else if VideoPreview.supports(item) { self = .video }
        else if PDFPreview.supports(item) { self = .pdf }
        else if SVGPreview.isSVG(item.name) { self = .source(.svg) }
        else if HTMLPreviewState.isHTML(item.name) { self = .source(.html) }
        else if MarkdownRendering.isMarkdown(item.name) { self = .source(.markdown) }
        else { self = .source(.text) }
    }

    var isSource: Bool {
        if case .source = self { return true }
        return false
    }

    /// Clear unselected readers while retaining each reader's validation and cancellation guards.
    @MainActor func load(_ selection: DetailsSelection?, preview: PreviewState,
                         image: ImagePreviewState, video: VideoPreviewState, pdf: PDFPreviewState) async {
        async let imageLoad: Void = image.load(self == .image ? selection : nil, followingLinks: preview.followsLinks)
        async let videoLoad: Void = video.load(self == .video ? selection : nil, followingLinks: preview.followsLinks)
        async let pdfLoad: Void = pdf.load(self == .pdf ? selection : nil, followingLinks: preview.followsLinks)
        await preview.load(isSource ? selection : nil)
        _ = await (imageLoad, videoLoad, pdfLoad)
    }
}
