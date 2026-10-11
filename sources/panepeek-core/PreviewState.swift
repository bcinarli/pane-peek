import Foundation
import Observation

@MainActor @Observable
public final class PreviewState {
    public private(set) var selection: DetailsSelection?
    public private(set) var preview: TextPreview?
    public private(set) var tokens: [SyntaxToken] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    private let read: @Sendable (DirectoryEntry) async throws -> TextPreview
    private let highlight: @Sendable (String, String) async throws -> [SyntaxToken]
    private var requestID = UUID()

    public init(
        read: @escaping @Sendable (DirectoryEntry) async throws -> TextPreview = TextPreview.read,
        highlight: @escaping @Sendable (String, String) async throws -> [SyntaxToken] = { try await SyntaxHighlighting.tokens(in: $0, fileName: $1) }
    ) {
        self.read = read
        self.highlight = highlight
    }

    /// Replace content for a primary selection, discarding superseded or cancelled reads.
    public func load(_ selection: DetailsSelection?) async {
        guard !Task.isCancelled else { return }
        let request = UUID()
        requestID = request
        self.selection = selection
        preview = nil
        tokens = []
        errorMessage = nil
        isLoading = selection != nil
        defer {
            if requestID == request { isLoading = false }
        }
        guard let selection else { return }
        do {
            let preview = try await read(selection.item)
            guard requestID == request, !Task.isCancelled else { return }
            var tokens: [SyntaxToken] = []
            if case .text(let text) = preview {
                tokens = try await highlight(text, selection.item.url.lastPathComponent)
            }
            guard requestID == request, !Task.isCancelled else { return }
            self.preview = preview
            self.tokens = tokens
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t read text preview. \(error.localizedDescription)"
        }
    }
}
