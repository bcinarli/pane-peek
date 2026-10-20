import AppKit
import Darwin
import Observation
import PDFKit
import SwiftUI
import PanePeekCore

enum PDFPreview {
    static let maximumBytes = 32 * 1_048_576
    static let maximumPages = 500
    static let maximumPageDimension: CGFloat = 14_400

    static func supports(_ item: DirectoryEntry?) -> Bool {
        guard let item, !item.isDirectory, !item.isPackage else { return false }
        return item.url.pathExtension.lowercased() == "pdf"
    }

    enum Failure: LocalizedError, Equatable {
        case unsupported, locked, tooLarge, tooManyPages, dimensions, nonRegularFile
        var errorDescription: String? {
            switch self {
            case .unsupported: "This PDF is damaged or cannot be previewed."
            case .locked: "This PDF requires a password. Open it in another app to unlock it."
            case .tooLarge: "PDF preview is limited to files up to 32 MiB."
            case .tooManyPages: "PDF preview is limited to 500 pages."
            case .dimensions: "This PDF has page dimensions that are too large to preview."
            case .nonRegularFile: "No PDF preview for this file type."
            }
        }
    }

    private static let decoder = Decoder()

    @MainActor static func read(_ item: DirectoryEntry) async throws -> PDFDocument {
        try await decoder.read(item)
    }

    // PDFKit parsing is synchronous; serialise it off the UI thread across windows.
    private actor Decoder {
        func read(_ item: DirectoryEntry) throws -> sending PDFDocument {
            guard item.url.isFileURL, PDFPreview.supports(item) else { throw Failure.unsupported }
            try Task.checkCancellation()
            let descriptor = Darwin.open(item.url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
            guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var attributes = stat()
            guard fstat(descriptor, &attributes) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw Failure.nonRegularFile }
            guard attributes.st_size <= PDFPreview.maximumBytes else { throw Failure.tooLarge }
            let data = try handle.read(upToCount: PDFPreview.maximumBytes + 1) ?? Data()
            try Task.checkCancellation()
            guard data.count <= PDFPreview.maximumBytes else { throw Failure.tooLarge }
            guard let document = PDFDocument(data: data) else { throw Failure.unsupported }
            guard !document.isLocked else { throw Failure.locked }
            guard document.pageCount > 0 else { throw Failure.unsupported }
            guard document.pageCount <= PDFPreview.maximumPages else { throw Failure.tooManyPages }
            for index in 0..<document.pageCount {
                try Task.checkCancellation()
                guard let page = document.page(at: index) else { throw Failure.unsupported }
                for box in [PDFDisplayBox.mediaBox, .cropBox] {
                    let bounds = page.bounds(for: box)
                    guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                          bounds.width.isFinite, bounds.height.isFinite,
                          bounds.width > 0, bounds.height > 0,
                          bounds.width <= PDFPreview.maximumPageDimension,
                          bounds.height <= PDFPreview.maximumPageDimension else { throw Failure.dimensions }
                }
                // Keep visible annotations, but disable form editing and document-supplied actions.
                for annotation in page.annotations {
                    annotation.action = nil
                    annotation.removeValue(forAnnotationKey: .additionalActions)
                    if annotation.type == "Widget" { annotation.isReadOnly = true }
                    if annotation.type == "Link" { annotation.destination = nil }
                }
            }
            try Task.checkCancellation()
            return document
        }
    }
}

@MainActor @Observable final class PDFPreviewState {
    private(set) var selection: DetailsSelection?
    private(set) var document: PDFDocument?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var requestID = UUID()
    private let read: @MainActor (DirectoryEntry) async throws -> PDFDocument

    init(read: @escaping @MainActor (DirectoryEntry) async throws -> PDFDocument = PDFPreview.read) { self.read = read }

    func load(_ selection: DetailsSelection?) async {
        guard !Task.isCancelled else { return }
        stop()
        let request = requestID
        self.selection = PDFPreview.supports(selection?.item) ? selection : nil
        isLoading = self.selection != nil
        defer { if requestID == request { isLoading = false } }
        guard let selection = self.selection else { return }
        do {
            let document = try await read(selection.item)
            guard requestID == request, !Task.isCancelled else { return }
            self.document = document
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t preview this PDF. \(error.localizedDescription)"
        }
    }

    func stop() {
        requestID = UUID()
        document = nil
        selection = nil
        isLoading = false
        errorMessage = nil
    }
}

struct PDFPreviewView: NSViewRepresentable {
    let document: PDFDocument
    let name: String
    func makeNSView(context: Context) -> PDFPreviewContainer { PDFPreviewContainer(frame: .zero) }
    func updateNSView(_ view: PDFPreviewContainer, context: Context) { view.show(document, name: name) }
    static func dismantleNSView(_ view: PDFPreviewContainer, coordinator: ()) { view.detach() }
}

final class PDFPreviewContainer: NSView, @MainActor PDFViewDelegate {
    let pdfView = PDFView(frame: .zero)

    override init(frame: NSRect) {
        super.init(frame: frame)
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.minScaleFactor = 0.01
        pdfView.maxScaleFactor = 4
        pdfView.acceptsDraggedFiles = false
        pdfView.isInMarkupMode = false
        pdfView.backgroundColor = .clear
        pdfView.delegate = self
        let zoomOut = NSButton(title: "−", target: self, action: #selector(zoomOut(_:)))
        zoomOut.setAccessibilityLabel("Zoom out PDF")
        zoomOut.toolTip = "Zoom out PDF"
        let zoomIn = NSButton(title: "+", target: self, action: #selector(zoomIn(_:)))
        zoomIn.setAccessibilityLabel("Zoom in PDF")
        zoomIn.toolTip = "Zoom in PDF"
        let fit = NSButton(title: "Fit Width", target: self, action: #selector(fitWidth(_:)))
        fit.setAccessibilityLabel("Fit PDF to width")
        fit.toolTip = "Fit PDF pages to the available width"
        let controls = NSStackView(views: [zoomOut, zoomIn, fit])
        controls.spacing = 8
        controls.orientation = .horizontal
        addSubview(controls)
        addSubview(pdfView)
        controls.translatesAutoresizingMaskIntoConstraints = false
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            controls.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            pdfView.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 8),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func show(_ document: PDFDocument, name: String) {
        if pdfView.document !== document {
            pdfView.document = document
            fitWidth(nil)
        }
        pdfView.setAccessibilityLabel("Read-only PDF preview of \(name)")
    }

    @objc func zoomIn(_ sender: Any?) { pdfView.autoScales = false; pdfView.zoomIn(sender) }
    @objc func zoomOut(_ sender: Any?) { pdfView.autoScales = false; pdfView.zoomOut(sender) }
    @objc func fitWidth(_ sender: Any?) { pdfView.autoScales = true }
    func detach() { pdfView.document = nil }

    // The inline viewer never opens document-supplied links or companion files.
    func pdfViewWillClick(onLink sender: PDFView, with url: URL) {}
    func pdfViewOpenPDF(_ sender: PDFView, forRemoteGoToAction action: PDFActionRemoteGoTo) {}

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: window)
        } else { detach() }
    }

    @objc private func windowWillClose(_ notification: Notification) { detach() }
}
