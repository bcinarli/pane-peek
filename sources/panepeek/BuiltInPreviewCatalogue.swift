import Observation
import PanePeekCore

/// Registrations are ordered by precedence; matching never opens files or creates presentation state.
enum BuiltInPreviewCatalogue {
    enum ID: String, CaseIterable, Sendable { case text, markdown, svg, html, image, video, pdf }

    struct Registration: Sendable {
        let id: ID
        let route: PreviewRoute
        let matches: @Sendable (DirectoryEntry) -> Bool
        let makePresentation: @MainActor @Sendable () -> BuiltInPreviewState.Presentation
    }

    static let registrations: [Registration] = [
        Registration(id: .image, route: .image, matches: ImagePreview.supports, makePresentation: { .image(ImagePreviewState()) }),
        Registration(id: .video, route: .video, matches: VideoPreview.supports, makePresentation: { .video(VideoPreviewState()) }),
        Registration(id: .pdf, route: .pdf, matches: PDFPreview.supports, makePresentation: { .pdf(PDFPreviewState()) }),
        Registration(id: .svg, route: .source(.svg), matches: { SVGPreview.isSVG($0.name) }, makePresentation: { .source }),
        Registration(id: .html, route: .source(.html), matches: { HTMLPreviewState.isHTML($0.name) }, makePresentation: { .source }),
        Registration(id: .markdown, route: .source(.markdown), matches: { MarkdownRendering.isMarkdown($0.name) },
                     makePresentation: { .markdown(MarkdownPreviewState()) }),
        Registration(id: .text, route: .source(.text), matches: { _ in true }, makePresentation: { .source })
    ]

    static func registration(for item: DirectoryEntry?) -> Registration? {
        guard let item else { return nil }
        return registrations.first { $0.matches(item) }
    }
}

/// Holds only the selected concrete owner. Source editing and web-backed leaf views keep their existing lifetimes.
@MainActor @Observable final class BuiltInPreviewState {
    enum Presentation {
        case source, markdown(MarkdownPreviewState), image(ImagePreviewState), video(VideoPreviewState), pdf(PDFPreviewState)
    }

    private(set) var id: BuiltInPreviewCatalogue.ID?
    private var presentation: Presentation?
    private let make: (BuiltInPreviewCatalogue.Registration) -> Presentation

    init(make: @escaping (BuiltInPreviewCatalogue.Registration) -> Presentation = { $0.makePresentation() }) {
        self.make = make
    }

    var image: ImagePreviewState? { if case .image(let state) = presentation { state } else { nil } }
    var video: VideoPreviewState? { if case .video(let state) = presentation { state } else { nil } }
    var pdf: PDFPreviewState? { if case .pdf(let state) = presentation { state } else { nil } }
    var markdown: MarkdownPreviewState? { if case .markdown(let state) = presentation { state } else { nil } }

    func activate(_ registration: BuiltInPreviewCatalogue.Registration?) {
        guard id != registration?.id else { return }
        stop()
        id = registration?.id
        presentation = registration.map(make)
    }

    func load(_ selection: DetailsSelection?, registration: BuiltInPreviewCatalogue.Registration?, preview: PreviewState) async {
        guard !Task.isCancelled else { return }
        activate(registration)
        let selected = presentation
        async let media: Void = Self.loadMedia(selected, selection: selection, followingLinks: preview.followsLinks)
        await preview.load(registration?.route.isSource == true ? selection : nil)
        await media
    }

    private static func loadMedia(_ presentation: Presentation?, selection: DetailsSelection?, followingLinks: Bool) async {
        switch presentation {
        case .image(let state): await state.load(selection, followingLinks: followingLinks)
        case .video(let state): await state.load(selection, followingLinks: followingLinks)
        case .pdf(let state): await state.load(selection, followingLinks: followingLinks)
        default: break
        }
    }

    func stop() {
        switch presentation {
        case .image(let state): state.stop()
        case .video(let state): state.stop()
        case .pdf(let state): state.stop()
        case .markdown(let state): state.stop()
        default: break
        }
        presentation = nil
        id = nil
    }
}
