import Foundation
import Observation

@MainActor @Observable
public final class PreviewState {
    public enum Mode: Sendable { case preview, edit }
    public private(set) var mode: Mode = .preview
    public private(set) var isDirty = false
    public private(set) var isSaving = false
    public private(set) var saveRevision = UUID()
    public private(set) var documentID = UUID()
    public var canEdit: Bool {
        if case .text(_, let editable) = preview {
            return editable && selection?.item.isSymbolicLink == false && !isLoading && !isSaving
        }
        return false
    }
    public var text: String? {
        if case .text(let text, _) = preview { return text }
        return nil
    }
    public private(set) var selection: DetailsSelection?
    public private(set) var preview: TextPreview?
    public private(set) var tokens: [SyntaxToken] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let read: @Sendable (DirectoryEntry) async throws -> TextPreview.Loaded
    private let write: @Sendable (TextFileSnapshot, String, URL) async throws -> TextFileSnapshot
    private let highlight: @Sendable (String, String) async throws -> [SyntaxToken]
    private var requestID = UUID()
    private var editRequestID = UUID()
    private var editTask: Task<Void, Never>?
    private var original: TextPreview?
    private var originalTokens: [SyntaxToken] = []
    private var snapshot: TextFileSnapshot?

    public init(
        read: (@Sendable (DirectoryEntry) async throws -> TextPreview)? = nil,
        highlight: @escaping @Sendable (String, String) async throws -> [SyntaxToken] = { try await SyntaxHighlighting.tokens(in: $0, fileName: $1) },
        write: @escaping @Sendable (TextFileSnapshot, String, URL) async throws -> TextFileSnapshot = { try await $0.save($1, to: $2) }
    ) {
        if let read {
            self.read = { TextPreview.Loaded(preview: try await read($0)) }
        } else {
            self.read = TextPreview.load
        }
        self.highlight = highlight
        self.write = write
    }

    /// Replace content for a primary selection, discarding superseded or cancelled reads.
    public func load(_ selection: DetailsSelection?) async {
        guard !Task.isCancelled else { return }
        // A missed UI guard must still never replace an unsaved buffer.
        if isDirty || isSaving {
            if let selection, selection.item.url == self.selection?.item.url { self.selection = selection }
            return
        }
        editTask?.cancel()
        editRequestID = UUID()
        let request = UUID()
        requestID = request
        self.selection = selection
        preview = nil
        original = nil
        snapshot = nil
        originalTokens = []
        mode = .preview
        documentID = UUID()
        tokens = []
        errorMessage = nil
        isLoading = selection != nil
        defer {
            if requestID == request { isLoading = false }
        }
        guard let selection else { return }
        do {
            let loaded = try await read(selection.item)
            let preview = loaded.preview
            guard requestID == request, !Task.isCancelled else { return }
            var tokens: [SyntaxToken] = []
            if case .text(let text, _) = preview {
                tokens = try await highlight(text, selection.item.url.lastPathComponent)
            }
            guard requestID == request, !Task.isCancelled else { return }
            self.preview = preview
            original = preview
            snapshot = loaded.snapshot
            originalTokens = tokens
            self.tokens = tokens
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t read text preview. \(error.localizedDescription)"
        }
    }

    public func setMode(_ mode: Mode) {
        guard mode == .preview || canEdit else { return }
        self.mode = mode
    }

    /// Update the draft immediately; only the latest background colours may publish.
    @discardableResult public func updateText(_ text: String) -> Task<Void, Never>? {
        guard canEdit, mode == .edit, let current = self.text,
              !current.utf8.elementsEqual(text.utf8), text.utf8.count <= TextPreview.maximumBytes else { return nil }
        preview = .text(text)
        if case .text(let originalText, _) = original {
            isDirty = !originalText.utf8.elementsEqual(text.utf8)
        }
        tokens = []
        errorMessage = nil
        editTask?.cancel()
        let request = UUID()
        editRequestID = request
        let fileName = selection?.item.url.lastPathComponent ?? ""
        editTask = Task { [weak self, highlight] in
            do {
                let tokens = try await highlight(text, fileName)
                guard let self, self.editRequestID == request, !Task.isCancelled else { return }
                self.tokens = tokens
                if !self.isDirty { self.originalTokens = tokens }
            } catch {
                guard let self, self.editRequestID == request, !Task.isCancelled else { return }
                self.errorMessage = "Couldn’t highlight edited text. \(error.localizedDescription)"
            }
        }
        return editTask
    }

    public func discardChanges() {
        guard isDirty, !isSaving else { return }
        editTask?.cancel()
        editRequestID = UUID()
        preview = original
        tokens = originalTokens
        isDirty = false
        errorMessage = nil
        documentID = UUID()
    }

    /// Keep the draft and native undo identity on success or failure; publish a new disk baseline only after writing.
    @discardableResult public func save() async -> Bool {
        guard !isSaving else { return false }
        guard isDirty else { return true }
        guard canEdit, let text, let selection, let snapshot else {
            errorMessage = "Couldn’t save this draft. Reload the file before editing."
            return false
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            self.snapshot = try await write(snapshot, text, selection.item.url)
            original = preview
            originalTokens = tokens
            isDirty = false
            saveRevision = UUID()
            return true
        } catch {
            errorMessage = "Couldn’t save changes. \(error.localizedDescription)"
            return false
        }
    }
}
