import PanePeekCore

/// Selects a built-in presentation without opening the item or constructing a renderer.
enum PreviewRoute: Equatable, Sendable {
    enum Source: Equatable, Sendable { case text, markdown, svg, html }
    case none, source(Source), image, video, pdf

    init(_ item: DirectoryEntry?) {
        self = BuiltInPreviewCatalogue.registration(for: item)?.route ?? .none
    }

    var isSource: Bool {
        if case .source = self { return true }
        return false
    }
}
