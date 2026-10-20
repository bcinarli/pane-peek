import AppKit
import ImageIO
import Observation
import SwiftUI
import WebKit
import PanePeekCore

@MainActor enum SVGPreview {
    nonisolated static func isSVG(_ name: String) -> Bool {
        (name as NSString).pathExtension.lowercased() == "svg"
    }

    enum Failure: LocalizedError {
        case tooLarge, unsupported, timedOut
        var errorDescription: String? {
            switch self {
            case .tooLarge: "SVG preview is limited to UTF-8 files up to 1 MiB."
            case .unsupported: "This SVG is damaged or uses features that cannot be previewed."
            case .timedOut: "This SVG took too long to preview."
            }
        }
    }

    static func read(_ text: String) async throws -> CGImage {
        try await SVGRenderer().render(text)
    }
}

/// Decode in an inert image context, then release the web view and retain only a bounded static image.
@MainActor final class SVGRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var completion: CheckedContinuation<CGImage, any Error>?
    private var timeout: Task<Void, Never>?

    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        return configuration
    }

    init(configuration: WKWebViewConfiguration? = nil) {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1, height: 1),
                            configuration: configuration ?? Self.configuration())
        super.init()
        webView.navigationDelegate = self
    }

    func render(_ text: String) async throws -> CGImage {
        try Task.checkCancellation()
        guard text.utf8.count <= TextPreview.maximumBytes else { throw SVGPreview.Failure.tooLarge }
        let source = Data(text.utf8).base64EncodedString()
        // Keep the image's intrinsic viewport so canvas rasterisation preserves its geometry.
        let html = """
        <!doctype html><html><head><meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; img-src data:; base-uri 'none'; form-action 'none'"></head>
        <body><img src="data:image/svg+xml;base64,\(source)"></body></html>
        """
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                completion = continuation
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(10)) } catch { return }
                    self?.finish(.failure(SVGPreview.Failure.timedOut))
                }
                webView.loadHTMLString(html, baseURL: nil)
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard completion != nil else { return }
        // Content JavaScript stays disabled; app-owned code runs in an isolated world.
        webView.callAsyncJavaScript("""
            const image = document.images[0];
            await image.decode();
            const width = image.naturalWidth, height = image.naturalHeight;
            if (!(width > 0 && height > 0)) { throw new Error('Invalid SVG dimensions'); }
            const scale = maximumDimension / Math.max(width, height);
            const canvas = document.createElement('canvas');
            canvas.width = Math.max(1, Math.round(width * scale));
            canvas.height = Math.max(1, Math.round(height * scale));
            canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height);
            return canvas.toDataURL('image/png').split(',')[1];
            """, arguments: ["maximumDimension": ImagePreview.maximumDimension], in: nil, in: .defaultClient) { [weak self] result in
            guard let self, completion != nil else { return }
            guard case .success(let value) = result, let encoded = value as? String,
                  let data = Data(base64Encoded: encoded),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  image.width <= ImagePreview.maximumDimension, image.height <= ImagePreview.maximumDimension else {
                finish(.failure(SVGPreview.Failure.unsupported))
                return
            }
            finish(.success(image))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        finish(.failure(SVGPreview.Failure.unsupported))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        finish(.failure(SVGPreview.Failure.unsupported))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(.failure(SVGPreview.Failure.unsupported))
    }

    private func finish(_ result: Result<CGImage, any Error>) {
        guard let completion else { return }
        self.completion = nil
        timeout?.cancel()
        timeout = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        completion.resume(with: result)
    }
}

@MainActor @Observable final class SVGPreviewState {
    private(set) var image: CGImage?
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private var requestID = UUID()
    private let read: @MainActor (String) async throws -> CGImage

    init(read: @escaping @MainActor (String) async throws -> CGImage = SVGPreview.read) { self.read = read }

    func load(_ text: String) async {
        guard !Task.isCancelled else { return }
        let request = UUID()
        requestID = request
        image = nil
        errorMessage = nil
        isLoading = true
        defer { if requestID == request { isLoading = false } }
        do {
            let image = try await read(text)
            guard requestID == request, !Task.isCancelled else { return }
            self.image = image
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct SVGPreviewView: View {
    let text: String
    let name: String
    @SwiftUI.State private var preview = SVGPreviewState()

    var body: some View {
        Group {
            if let image = preview.image {
                ImagePreviewView(image: image, name: name)
            } else {
                Text(preview.isLoading ? "Rendering SVG preview…" : preview.errorMessage ?? "No SVG preview available.")
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: text) { await preview.load(text) }
    }
}
