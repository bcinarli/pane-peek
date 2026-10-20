import Foundation
import Observation

@MainActor @Observable
public final class PreviewState {
    public enum Mode: Sendable { case preview, edit }
    public let isReadOnly: Bool
    public let followsLinks: Bool
    public private(set) var isRequestingWriteAccess = false
    public private(set) var mode: Mode = .preview
    public private(set) var isDirty = false
    public private(set) var isSaving = false
    public private(set) var saveRevision = UUID()
    public private(set) var documentID = UUID()
    var operations: FileOperationCoordinator?
    public var isOperationLocked: Bool { operations?.isLocked(self) == true }
    public var canSave: Bool { canEdit && operations?.canSave(self) != false }
    // Rename presentation is local; edit and Save exclusion belongs to the coordinator.
    private var changingLocation: ItemRename?
    public var isChangingLocation: Bool {
        selection.map { changingLocation?.affects($0.item.url) == true } ?? false
    }
    public var canBeginEditing: Bool {
        if case .text(_, let editable) = preview {
            return !isReadOnly && editable && selection?.item.isSymbolicLink == false
                && !isLoading && !isSaving && !isOperationLocked && !isRequestingWriteAccess
        }
        return false
    }
    public var canEdit: Bool {
        canBeginEditing && (acquireWriteAccess == nil || selection?.access?.mode == .readWrite)
    }
    public var text: String? {
        if case .text(let text, _) = preview { return text }
        return nil
    }
    public private(set) var selection: DetailsSelection?
    public private(set) var preview: TextPreview?
    public private(set) var tokens: [SyntaxToken] = []
    /// Rendered blocks for the current Markdown text; nil while a draft change awaits Preview.
    public private(set) var markdown: [MarkdownBlock]?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let read: @Sendable (DirectoryEntry) async throws -> TextPreview.Loaded
    private let acquireWriteAccess: (@MainActor (DetailsSelection) async throws -> DirectoryAccess?)?
    private var accessTask: Task<Void, Never>?
    private var accessRequestID = UUID()
    private let write: @Sendable (TextFileSnapshot, String, URL) async throws -> TextFileSnapshot
    private let highlight: @Sendable (String, String) async throws -> [SyntaxToken]
    private var requestID = UUID()
    private var editRequestID = UUID()
    private var editTask: Task<Void, Never>?
    private var markdownRequestID = UUID()
    private var markdownTask: Task<Void, Never>?
    private var original: TextPreview?
    private var originalTokens: [SyntaxToken] = []
    private var snapshot: TextFileSnapshot?
    var fileSnapshot: TextFileSnapshot? { snapshot }

    public init(
        readOnly: Bool = false,
        acquireWriteAccess: (@MainActor (DetailsSelection) async throws -> DirectoryAccess?)? = nil,
        read: (@Sendable (DirectoryEntry) async throws -> TextPreview)? = nil,
        highlight: (@Sendable (String, String) async throws -> [SyntaxToken])? = nil,
        write: (@Sendable (TextFileSnapshot, String, URL) async throws -> TextFileSnapshot)? = nil
    ) {
        self.isReadOnly = readOnly
        self.acquireWriteAccess = acquireWriteAccess
        let followsLinks = !readOnly && acquireWriteAccess == nil
        self.followsLinks = followsLinks
        if let read {
            self.read = { TextPreview.Loaded(preview: try await read($0)) }
        } else {
            self.read = { try await TextPreview.load($0, followingLinks: followsLinks) }
        }
        self.highlight = highlight ?? { try await SyntaxHighlighting.tokens(in: $0, fileName: $1) }
        self.write = write ?? { try await $0.save($1, to: $2) }
    }

    func setChangingLocation(_ operation: ItemRename?) { changingLocation = operation }

    /// Replace content for a primary selection, discarding superseded or cancelled reads.
    public func load(_ selection: DetailsSelection?) async {
        defer { withExtendedLifetime(selection) {} }
        guard !Task.isCancelled else { return }
        // A missed UI guard must still never replace an unsaved buffer.
        if isDirty || isSaving {
            if let selection, selection.item.url == self.selection?.item.url {
                self.selection = DetailsSelection(item: selection.item, listingRevision: selection.listingRevision,
                                                 access: self.selection?.access ?? selection.access)
            }
            return
        }
        if let selection, mode == .edit, selection.item.url == self.selection?.item.url, let snapshot {
            let request = UUID()
            requestID = request
            isLoading = true
            defer { if requestID == request { isLoading = false } }
            let access = self.selection?.access
            let check = Task.detached(priority: .userInitiated) {
                defer { withExtendedLifetime(access) {} }
                try snapshot.validate(selection.item.url)
            }
            let unchanged = try? await withTaskCancellationHandler { try await check.value } onCancel: { check.cancel() }
            guard requestID == request, !Task.isCancelled else { return }
            if unchanged != nil {
                self.selection = DetailsSelection(item: selection.item, listingRevision: selection.listingRevision,
                                                 access: access ?? selection.access)
                return
            }
        }
        cancelAccessRequest()
        editTask?.cancel()
        editRequestID = UUID()
        invalidateMarkdown()
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
            let preview: TextPreview
            if isReadOnly, case .text(let text, _) = loaded.preview {
                preview = .text(text, editable: false)
            } else {
                preview = loaded.preview
            }
            guard requestID == request, !Task.isCancelled else { return }
            var tokens: [SyntaxToken] = []
            var markdown: [MarkdownBlock]?
            if case .text(let text, _) = preview {
                tokens = try await highlight(text, selection.item.url.lastPathComponent)
                // Unrenderable Markdown falls back to the highlighted source.
                if MarkdownRendering.isMarkdown(selection.item.name) {
                    markdown = try? await MarkdownRendering.blocks(in: text, baseURL: selection.item.url.deletingLastPathComponent())
                }
            }
            guard requestID == request, !Task.isCancelled else { return }
            self.preview = preview
            self.markdown = markdown
            original = preview
            snapshot = isReadOnly ? nil : loaded.snapshot
            originalTokens = tokens
            self.tokens = tokens
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t read text preview. \(error.localizedDescription)"
        }
    }

    @discardableResult public func setMode(_ mode: Mode) -> Task<Void, Never>? {
        if mode == .preview {
            cancelAccessRequest()
            self.mode = mode
            return renderMarkdownIfNeeded()
        }
        guard canBeginEditing else { return nil }
        if canEdit { self.mode = mode; return nil }
        guard let acquireWriteAccess, let selection else { return nil }
        let request = UUID()
        accessRequestID = request
        let document = documentID
        isRequestingWriteAccess = true
        errorMessage = nil
        accessTask = Task { [weak self] in
            defer {
                withExtendedLifetime(selection) {}
                if self?.accessRequestID == request {
                    self?.isRequestingWriteAccess = false
                    self?.accessTask = nil
                }
            }
            do {
                guard let access = try await acquireWriteAccess(selection) else { return }
                try Task.checkCancellation()
                guard let self, self.accessRequestID == request, self.documentID == document else { return }
                let parent = selection.item.url.deletingLastPathComponent().standardized.pathComponents
                guard access.mode == .readWrite, parent.starts(with: access.root.standardized.pathComponents) else {
                    throw CocoaError(.fileWriteNoPermission)
                }
                self.selection = DetailsSelection(item: selection.item, listingRevision: selection.listingRevision, access: access)
                self.mode = .edit
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.accessRequestID == request, self.documentID == document, !Task.isCancelled else { return }
                self.errorMessage = "Couldn’t allow editing. Choose the file’s containing folder or a parent folder. \(error.localizedDescription)"
            }
        }
        return accessTask
    }

    private func cancelAccessRequest() {
        accessTask?.cancel()
        accessTask = nil
        accessRequestID = UUID()
        isRequestingWriteAccess = false
    }

    /// Update the draft immediately; only the latest background colours may publish.
    @discardableResult public func updateText(_ text: String) -> Task<Void, Never>? {
        guard canEdit, mode == .edit, let current = self.text,
              !current.utf8.elementsEqual(text.utf8), text.utf8.count <= TextPreview.maximumBytes else { return nil }
        preview = .text(text)
        invalidateMarkdown()
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

    @discardableResult public func discardChanges() -> Task<Void, Never>? {
        guard isDirty, !isSaving else { return nil }
        editTask?.cancel()
        editRequestID = UUID()
        preview = original
        tokens = originalTokens
        isDirty = false
        errorMessage = nil
        documentID = UUID()
        invalidateMarkdown()
        return renderMarkdownIfNeeded()
    }

    private func invalidateMarkdown() {
        markdownTask?.cancel()
        markdownRequestID = UUID()
        markdown = nil
    }

    /// Render a changed Markdown draft only when Preview needs it; newer text supersedes the result.
    private func renderMarkdownIfNeeded() -> Task<Void, Never>? {
        guard mode == .preview, markdown == nil, let text, let selection, MarkdownRendering.isMarkdown(selection.item.name) else { return nil }
        markdownTask?.cancel()
        let request = UUID()
        markdownRequestID = request
        markdownTask = Task { [weak self] in
            let blocks = try? await MarkdownRendering.blocks(in: text, baseURL: selection.item.url.deletingLastPathComponent())
            guard let self, self.markdownRequestID == request, !Task.isCancelled else { return }
            self.markdown = blocks
        }
        return markdownTask
    }

    /// A restored destination keeps its draft while verified rename metadata becomes its Save baseline.
    func refreshRestoredSnapshot(at url: URL) async -> String? {
        guard selection?.item.url.path == url.path, let snapshot else { return nil }
        let document = documentID
        do {
            let restored = try await snapshot.acceptingRestoredFile(at: url)
            guard documentID == document, selection?.item.url.path == url.path else { return nil }
            self.snapshot = restored
            return nil
        } catch {
            return "Couldn’t verify the restored file at \(url.path). The draft is retained. \(error.localizedDescription)"
        }
    }

    /// Keep the draft and native undo identity on success or failure; publish a new disk baseline only after writing.
    @discardableResult public func save() async -> Bool {
        guard !isSaving else { return false }
        guard isDirty else { return true }
        guard operations?.beginSave(self) != false else {
            errorMessage = "Couldn’t save this draft while another file operation is in progress. Try again when it finishes."
            return false
        }
        defer { operations?.endSave(self) }
        guard canEdit, let text, let selection, let snapshot else {
            errorMessage = "Couldn’t save this draft. Reload the file before editing."
            return false
        }
        defer { withExtendedLifetime(selection) {} }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            self.snapshot = try await write(snapshot, text, selection.item.url)
            original = preview
            originalTokens = tokens
            if let errors = await operations?.refreshAfterSave(at: selection.item.url), !errors.isEmpty {
                errorMessage = "Saved changes, but couldn’t refresh the listing. " + errors.joined(separator: "\n")
            }
            isDirty = false
            saveRevision = UUID()
            return true
        } catch {
            errorMessage = "Couldn’t save changes. \(error.localizedDescription)"
            return false
        }
    }
}
