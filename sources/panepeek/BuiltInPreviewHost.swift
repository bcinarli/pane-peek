import AppKit
import SwiftUI
import PanePeekCore

struct BuiltInPreviewHost: View {
    let selection: DetailsSelection?
    let preview: PreviewState
    let imagePreview: ImagePreviewState
    let videoPreview: VideoPreviewState
    let pdfPreview: PDFPreviewState
    let notifications: OperationNotifications
    let route: PreviewRoute

    init(selection: DetailsSelection?, preview: PreviewState, imagePreview: ImagePreviewState,
         videoPreview: VideoPreviewState, pdfPreview: PDFPreviewState, notifications: OperationNotifications) {
        self.selection = selection
        self.preview = preview
        self.imagePreview = imagePreview
        self.videoPreview = videoPreview
        self.pdfPreview = pdfPreview
        self.notifications = notifications
        route = PreviewRoute(selection?.item)
    }

    private var item: DirectoryEntry? { selection?.item }
    private var hasTextSelection: Bool {
        guard let selection else { return false }
        // Listing revisions must not remove a retained editor before its baseline check finishes.
        return preview.selection == selection || (preview.mode == .edit && preview.selection?.item.url == selection.item.url)
    }

    var canCopyFileContent: Bool {
        route.isSource && hasTextSelection && !preview.isLoading && preview.text != nil
    }

    func copyFileContent(to board: NSPasteboard = .general,
                         write: (String, NSPasteboard) -> Bool = { text, board in
                             FileClipboard.writeText(text, to: board)
                         }) {
        guard canCopyFileContent, let text = preview.text else { return }
        let copied = write(text, board)
        notifications.post(copied ? "File content copied." : "Couldn’t copy file content. Try again.",
                            kind: copied ? .success : .error)
    }

    private var previewMessage: String {
        switch route {
        case .none: return "No item selected"
        case .image:
            guard imagePreview.selection == selection, !imagePreview.isLoading else { return "Loading image preview…" }
            return imagePreview.errorMessage ?? "No image preview available."
        case .video:
            guard videoPreview.selection == selection, !videoPreview.isLoading else { return "Loading video preview…" }
            return videoPreview.errorMessage ?? "No video preview available."
        case .pdf:
            guard pdfPreview.selection == selection, !pdfPreview.isLoading else { return "Loading PDF preview…" }
            return pdfPreview.errorMessage ?? "No PDF preview available."
        case .source:
            guard hasTextSelection, !preview.isLoading else { return "Loading text preview…" }
            if let error = preview.errorMessage { return error }
            if case .unavailable(let reason) = preview.preview { return reason.message }
            return "Empty text file."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let item {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .opacity(preview.isDirty ? 1 : 0)
                        .accessibilityLabel("Unsaved changes")
                        .accessibilityHidden(!preview.isDirty)
                }
            }

            if route.isSource, item?.isDirectory == false, hasTextSelection,
               preview.text != nil || preview.isLoading {
                HStack(spacing: 8) {
                    TextModeToggle(mode: Binding(get: { [preview] in preview.mode }, set: { [preview] in preview.setMode($0) }),
                                   isEnabled: preview.canBeginEditing)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Text mode")
                    .help(preview.canBeginEditing ? (preview.canEdit ? "Preview or edit this text draft" : "Allow folder access to edit this text") : "Editing is unavailable for this item")
                    Button { copyFileContent() } label: {
                        Label("Copy file content", image: "icon-copy")
                            .labelStyle(.iconOnly)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Copy file content")
                    .disabled(!canCopyFileContent)
                    Spacer(minLength: 12)
                    Button(preview.isSaving ? "Saving…" : "Save") {
                        Task { await preview.save() }
                    }
                    .fixedSize()
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!preview.isDirty || !preview.canSave)
                    .help("Save changes to this file (⌘S)")
                }
            }

            Group {
                if route == .image, imagePreview.selection == selection, let image = imagePreview.image {
                    ImagePreviewView(image: image, name: item?.name ?? "selected image")
                } else if route == .video, videoPreview.selection == selection, let player = videoPreview.player {
                    VideoPreviewView(player: player, name: item?.name ?? "selected video", stopped: { [videoPreview] player in
                        if videoPreview.player === player { videoPreview.stop() }
                    })
                } else if route == .pdf, pdfPreview.selection == selection, let document = pdfPreview.document {
                    PDFPreviewView(document: document, name: item?.name ?? "selected PDF")
                } else if route.isSource, hasTextSelection, let text = preview.text {
                    PreviewDocument(preview: preview, text: text, route: route)
                } else {
                    Text(previewMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                }
            }
            .frame(minHeight: 236, maxHeight: .infinity)
            .background(Color(nsColor: AppColours.paper), in: RoundedRectangle(cornerRadius: 7))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color(nsColor: AppColours.divider), lineWidth: 1)
            }

            if let error = preview.errorMessage, preview.text != nil {
                Text(error).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .background {
            if !route.isSource {
                FindPresentationView(presentation: .unavailable)
            } else if !hasTextSelection || preview.text == nil {
                let identity = FindPresentation.Identity(document: preview.documentID, editing: preview.mode == .edit)
                FindPresentationView(presentation: !hasTextSelection || preview.isLoading ? .waiting(identity) : .unavailable)
            }
        }
        .task(id: selection) {
            await route.load(selection, preview: preview, image: imagePreview, video: videoPreview, pdf: pdfPreview)
        }
        .onDisappear { videoPreview.stop(); pdfPreview.stop() }
    }
}
