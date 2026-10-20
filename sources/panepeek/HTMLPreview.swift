import AppKit
import Observation
import SwiftUI
import WebKit
import PanePeekCore

@MainActor @Observable final class HTMLPreviewState: NSObject, WKNavigationDelegate {
    private(set) var webView: WKWebView?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var requestID = UUID()
    private var initialNavigation: WKNavigation?
    private var allowsInitialNavigation = false
    private var schemeHandler: HTMLPreviewSchemeHandler?
    private var completion: CheckedContinuation<Void, any Error>?
    private var timeout: Task<Void, Never>?
    private let configuration: @MainActor () -> WKWebViewConfiguration
    private let rules: @MainActor () async throws -> WKContentRuleList
    private let openLink: @MainActor (URL) -> Void

    nonisolated static func isHTML(_ name: String) -> Bool {
        ["html", "htm"].contains((name as NSString).pathExtension.lowercased())
    }

    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        return configuration
    }

    private static let compiledRules = Task { @MainActor in
        guard let rules = try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "PanePeekLocalHTML", encodedContentRuleList: """
        [
          {"trigger":{"url-filter":".*"},"action":{"type":"block"}},
          {"trigger":{"url-filter":"^data:"},"action":{"type":"ignore-previous-rules"}},
          {"trigger":{"url-filter":"^panepeek-html://"},"action":{"type":"ignore-previous-rules"}}
        ]
        """) else { throw Failure("The HTML resource policy could not be prepared.") }
        return rules
    }

    init(configuration: @escaping @MainActor () -> WKWebViewConfiguration = HTMLPreviewState.configuration,
         rules: @escaping @MainActor () async throws -> WKContentRuleList = { try await HTMLPreviewState.compiledRules.value },
         openLink: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }) {
        self.configuration = configuration
        self.rules = rules
        self.openLink = openLink
        super.init()
    }

    func load(_ text: String, selection: DetailsSelection? = nil) async {
        defer { withExtendedLifetime(selection) {} }
        guard !Task.isCancelled else { return }
        stop()
        let request = requestID
        isLoading = true
        defer { if requestID == request { isLoading = false } }
        do {
            guard text.utf8.count <= TextPreview.maximumBytes else {
                throw Failure("HTML preview is limited to UTF-8 files up to 1 MiB.")
            }
            let rules = try await rules()
            guard requestID == request, !Task.isCancelled else { return }
            let assets: HTMLPreviewAssets?
            if let selection { assets = try await HTMLPreviewAssets.open(selection) }
            else { assets = nil }
            guard requestID == request, !Task.isCancelled else { return }
            let configuration = configuration()
            configuration.userContentController.add(rules)
            // Install the policy before any source markup, including its own head or resource hints.
            let document = """
            <!doctype html><html><head><meta http-equiv="Content-Security-Policy"
            content="default-src 'none'; script-src 'none'; style-src 'unsafe-inline' data: panepeek-html:;
            img-src data: panepeek-html:; font-src data: panepeek-html:; media-src data:; frame-src 'none'; object-src 'none';
            connect-src 'none'; base-uri 'none'; form-action 'none'">
            <meta name="color-scheme" content="light dark"></head>
            \(text)
            """
            let handler = HTMLPreviewSchemeHandler(document: document, assets: assets)
            configuration.setURLSchemeHandler(handler, forURLScheme: HTMLPreviewSchemeHandler.scheme)
            schemeHandler = handler
            let view = WKWebView(frame: .zero, configuration: configuration)
            view.allowsLinkPreview = false
            view.navigationDelegate = self
            webView = view
            allowsInitialNavigation = true
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    completion = continuation
                    timeout = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(10)) } catch { return }
                        self?.finish(.failure(Failure("This HTML took too long to preview.")))
                    }
                    initialNavigation = view.load(URLRequest(url: handler.documentURL))
                }
            } onCancel: {
                Task { @MainActor [weak self] in
                    guard let self, self.requestID == request else { return }
                    self.stop()
                }
            }
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t preview this HTML. \(error.localizedDescription)"
            releaseWebView()
        }
    }

    func stop() {
        requestID = UUID()
        finish(.failure(CancellationError()))
        releaseWebView()
        isLoading = false
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard webView === self.webView, let url = action.request.url else { decisionHandler(.cancel); return }
        guard let documentURL = schemeHandler?.documentURL else { decisionHandler(.cancel); return }
        if allowsInitialNavigation, url == documentURL, action.targetFrame?.isMainFrame == true {
            allowsInitialNavigation = false
            decisionHandler(.allow)
            return
        }
        if action.navigationType == .linkActivated {
            if url.fragment != nil, url.absoluteString.components(separatedBy: "#").first == documentURL.absoluteString,
               action.targetFrame?.isMainFrame == true {
                decisionHandler(.allow)
                return
            }
            if ["http", "https"].contains(url.scheme?.lowercased() ?? "") { openLink(url) }
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView, navigation === initialNavigation else { return }
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        guard webView === self.webView, navigation === initialNavigation else { return }
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        self.webView(webView, didFail: navigation, withError: error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView else { return }
        errorMessage = "Couldn’t preview this HTML. The web content process stopped."
        finish(.failure(Failure("The web content process stopped.")))
        releaseWebView()
    }

    private func finish(_ result: Result<Void, any Error>) {
        timeout?.cancel()
        timeout = nil
        let completion = completion
        self.completion = nil
        completion?.resume(with: result)
    }

    private func releaseWebView() {
        schemeHandler?.stop()
        schemeHandler = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        initialNavigation = nil
        allowsInitialNavigation = false
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}

struct HTMLPreviewView: View {
    let text: String
    let name: String
    let selection: DetailsSelection?
    @SwiftUI.State private var preview = HTMLPreviewState()

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let view = preview.webView {
                HTMLWebView(view: view, name: name)
                    .id(ObjectIdentifier(view))
            }
            if preview.isLoading || preview.errorMessage != nil {
                Text(preview.isLoading ? "Rendering HTML preview…" : preview.errorMessage ?? "No HTML preview available.")
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .task(id: text) { await preview.load(text, selection: selection) }
        .onDisappear { preview.stop() }
    }
}

private struct HTMLWebView: NSViewRepresentable {
    let view: WKWebView
    let name: String
    func makeNSView(context: Context) -> WKWebView { view }
    func updateNSView(_ view: WKWebView, context: Context) {
        view.setAccessibilityLabel("Rendered HTML preview of \(name)")
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: ()) {
        view.stopLoading()
        view.navigationDelegate = nil
    }
}
