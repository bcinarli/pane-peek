import AppKit
import CoreText
import SwiftUI
import Testing
import WebKit
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct HTMLPreviewTests {
    @Test func renderedFindUsesTheNativeBarAndVisibleWebContent() async throws {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: HTMLPreviewView(text: "<h1>Visible needle</h1><p data-note='markup-only'>Body</p>",
                                                         name: "page.html", selection: nil))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.contentView = nil; window.orderOut(nil) }
        func webView(in view: NSView) -> WKWebView? {
            (view as? WKWebView) ?? view.subviews.lazy.compactMap { webView(in: $0) }.first
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            host.layoutSubtreeIfNeeded()
            if let view = webView(in: host), view.url != nil, !view.isLoading { break }
            await Task.yield()
        }
        let view = try #require(webView(in: host))
        let client: any NSTextFinderClient = view
        #expect(client.isEditable == false)
        let browser = BrowserState()
        let find = BrowserFind()
        find.window = window
        find.browser = browser
        window.makeFirstResponder(view)
        let request = find.folderRequest
        find.find(in: window)
        let scroll = try #require(view.enclosingScrollView)
        #expect(scroll.isFindBarVisible)
        let validation = try #require(scroll as? NSUserInterfaceValidations)
        let replace = NSMenuItem(title: "Replace", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "")
        for action: NSTextFinder.Action in [.showReplaceInterface, .replace, .replaceAll, .replaceAndFind, .replaceAllInSelection] {
            replace.tag = action.rawValue
            #expect(!validation.validateUserInterfaceItem(replace))
            scroll.tryToPerform(#selector(NSResponder.performTextFinderAction(_:)), with: replace)
        }
        find.find(in: window)
        #expect(scroll.isFindBarVisible && find.folderRequest == request)
        func searchField(in view: NSView?) -> NSSearchField? {
            guard let view else { return nil }
            return (view as? NSSearchField) ?? view.subviews.lazy.compactMap { searchField(in: $0) }.first
        }
        let field = try #require(searchField(in: scroll.findBarView))
        let next = NSMenuItem(title: "Next", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "")
        next.tag = NSTextFinder.Action.nextMatch.rawValue
        func selection() async throws -> String? {
            // Observe native Find's result without running a second search.
            try await view.callAsyncJavaScript("return getSelection().toString();", arguments: [:], in: nil, contentWorld: .defaultClient) as? String
        }
        func search(_ query: String) throws {
            #expect(window.makeFirstResponder(field))
            let input = try #require(field.currentEditor() as? NSTextView)
            input.insertText(query, replacementRange: NSRange(location: 0, length: input.string.utf16.count))
            #expect(field.stringValue == query)
            #expect(scroll.tryToPerform(#selector(NSResponder.performTextFinderAction(_:)), with: next))
        }
        func expectSelection(_ expected: String) async throws {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            var selected = try await selection()
            while selected != expected && ContinuousClock.now < deadline { selected = try await selection() }
            #expect(selected == expected)
        }
        try search("Visible needle")
        try await expectSelection("Visible needle")
        try search("markup-only")
        try await expectSelection("")
        try search("Body")
        try await expectSelection("Body")
        #expect(!view.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        #expect(!view.configuration.websiteDataStore.isPersistent)
    }

    @Test func folderStylesAndImagesRenderFromTheSelectedDocumentsDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-html-assets-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("assets"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("h1 { color: rgb(12, 34, 56); }".utf8).write(to: root.appendingPathComponent("styles.css"))
        try Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"6\"><rect width=\"10\" height=\"6\"/></svg>".utf8).write(to: root.appendingPathComponent("assets/mark café.svg"))
        let item = DirectoryEntry(url: root.appendingPathComponent("index.html"), isDirectory: false)
        let state = HTMLPreviewState()
        defer { state.stop() }
        await state.load("<link rel='stylesheet' href='styles.css?v=17'><h1>Folder assets ✓ café</h1><img src='assets/mark%20caf%C3%A9.svg'>", selection: DetailsSelection(item: item, listingRevision: UUID()))
        let view = try #require(state.webView)
        let result = try await view.callAsyncJavaScript("return [getComputedStyle(document.querySelector('h1')).color, String(document.images[0].naturalWidth), document.querySelector('h1').textContent];", arguments: [:], in: nil, contentWorld: .defaultClient) as? [String]
        #expect(result == ["rgb(12, 34, 56)", "10", "Folder assets ✓ café"])
    }

    @Test func nestedCSSImportsImagesAndFontsUseStylesheetRelativePaths() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-html-css-" + UUID().uuidString)
        for directory in ["styles/nested", "images", "fonts"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let font = CTFontCreateWithName("Arial" as CFString, 12, nil)
        let fontURL = try #require(CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL)
        let fontName = "fixture." + fontURL.pathExtension
        try FileManager.default.copyItem(at: fontURL, to: root.appendingPathComponent("fonts/" + fontName))
        try Data("@import url('nested/appearance.css?v=2');".utf8).write(to: root.appendingPathComponent("styles/main.css"))
        try Data("""
        @import url('panepeek-test://remote/style.css');
        @font-face { font-family: PanePeekFixture; src: url('../../fonts/\(fontName)'); }
        h1 { color: rgb(12, 34, 56); font-family: PanePeekFixture; background-image: url('../../images/mark.svg'); }
        """.utf8).write(to: root.appendingPathComponent("styles/nested/appearance.css"))
        try Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"6\"><rect width=\"10\" height=\"6\"/></svg>".utf8).write(to: root.appendingPathComponent("images/mark.svg"))
        let requests = HTMLResourceRequests()
        let state = HTMLPreviewState(configuration: {
            let configuration = HTMLPreviewState.configuration()
            configuration.setURLSchemeHandler(requests, forURLScheme: "panepeek-test")
            return configuration
        })
        defer { state.stop() }
        let selection = DetailsSelection(item: DirectoryEntry(url: root.appendingPathComponent("index.html"), isDirectory: false), listingRevision: UUID())
        await state.load("<link rel='stylesheet' href='styles/main.css'><h1>Local font</h1>", selection: selection)
        let view = try #require(state.webView, "\(state.errorMessage ?? "No view")")
        let result = try await view.callAsyncJavaScript("""
            await document.fonts.ready;
            const style = getComputedStyle(document.querySelector('h1'));
            const image = new Image();
            image.src = style.backgroundImage.slice(5, -2);
            await image.decode();
            return [style.color, String(image.naturalWidth), [...document.fonts][0].status];
            """, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String]
        #expect(result == ["rgb(12, 34, 56)", "10", "loaded"])
        #expect(requests.urls.isEmpty)
    }

    @Test func inlineStylesAndEmbeddedImagesRenderWithoutRunningSourceScripts() async throws {
        let image = Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"6\"><rect width=\"10\" height=\"6\" fill=\"blue\"/></svg>".utf8).base64EncodedString()
        let state = HTMLPreviewState()
        defer { state.stop() }
        await state.load("""
        <!doctype html><html><head><style>h1 { color: rgb(12, 34, 56); }</style></head>
        <body onload="document.querySelector('h1').textContent='Executed'">
          <h1>Local draft</h1><img src="data:image/svg+xml;base64,\(image)">
          <script>document.querySelector('h1').textContent='Executed';</script>
        </body></html>
        """)
        let view = try #require(state.webView, "\(state.errorMessage ?? "No web view")")
        let result = try await view.callAsyncJavaScript("""
            await document.images[0].decode();
            return [document.querySelector('h1').textContent,
                    getComputedStyle(document.querySelector('h1')).color,
                    String(document.images[0].naturalWidth)];
            """, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String]
        #expect(result == ["Local draft", "rgb(12, 34, 56)", "10"])
        #expect(!view.configuration.websiteDataStore.isPersistent)
        #expect(!view.configuration.defaultWebpagePreferences.allowsContentJavaScript && !view.allowsLinkPreview)
        #expect(state.errorMessage == nil && !state.isLoading)
        #expect(HTMLPreviewState.isHTML("page.HTM") && HTMLPreviewState.isHTML("page.HTML"))
        #expect(!HTMLPreviewState.isHTML("page.html.txt"))
    }

    @Test func referencedResourcesFramesRedirectsAndFormsCannotEscapeThePreview() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("panepeek-html-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let style = root.appendingPathComponent("secret.css")
        try Data("h1 { color: rgb(255, 0, 0) !important; }".utf8).write(to: style)
        let image = root.appendingPathComponent("secret.svg")
        try Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"6\"><rect width=\"10\" height=\"6\"/></svg>".utf8).write(to: image)
        let requests = HTMLResourceRequests()
        var links: [URL] = []
        let state = HTMLPreviewState(configuration: {
            let configuration = HTMLPreviewState.configuration()
            configuration.setURLSchemeHandler(requests, forURLScheme: "panepeek-test")
            return configuration
        }, openLink: { links.append($0) })
        defer { state.stop() }
        await state.load("""
        <head>
          <base href="\(root.absoluteString)/">
          <meta http-equiv="refresh" content="0; url=panepeek-test://redirect">
          <link rel="stylesheet" href="\(style.absoluteString)">
          <link rel="stylesheet" href="panepeek-html://another-preview/secret.css">
          <link rel="stylesheet" href="panepeek-test://resources/style.css">
          <style>
            @import url('panepeek-test://resources/import.css');
            @font-face { font-family: Secret; src: url('panepeek-test://resources/font.woff'); }
            h1 { color: rgb(12, 34, 56); font-family: Secret; background-image: url('panepeek-test://resources/background.png'); }
          </style>
        </head><body>
          <h1>Retained document</h1><img src="panepeek-test://resources/image.png">
          <img src="\(image.absoluteString)"><img src="secret.png">
          <img src="panepeek-html://another-preview/secret.svg">
          <iframe src="panepeek-test://resources/frame"></iframe>
          <object data="panepeek-test://resources/object"></object>
          <video src="panepeek-test://resources/video.mp4" autoplay></video>
          <script src="panepeek-test://resources/script.js"></script>
          <form action="panepeek-test://resources/submit"><input name="value" value="private"></form>
          <a id="script" href="javascript:document.querySelector('h1').remove()">Script</a>
        </body>
        """, selection: DetailsSelection(item: DirectoryEntry(url: root.appendingPathComponent("index.html"), isDirectory: false), listingRevision: UUID()))
        let view = try #require(state.webView, "\(state.errorMessage ?? "No web view")")
        _ = try await view.callAsyncJavaScript("document.forms[0].submit(); document.getElementById('script').click();", arguments: [:], in: nil, contentWorld: .defaultClient)
        let result = try await view.callAsyncJavaScript("""
            return [document.querySelector('h1').textContent,
                    getComputedStyle(document.querySelector('h1')).color,
                    document.baseURI, String(document.images[0].naturalWidth), String(document.images[1].naturalWidth), String(document.images[3].naturalWidth)];
            """, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String]
        #expect(result == ["Retained document", "rgb(12, 34, 56)", view.url?.absoluteString ?? "", "0", "0", "0"])
        #expect(requests.urls.isEmpty && links.isEmpty)
        #expect(view.url?.scheme == HTMLPreviewSchemeHandler.scheme && state.errorMessage == nil)
    }

    @Test(arguments: [false, true])
    func onlyDeliberateWebLinksOpenOutside(newWindow: Bool) async throws {
        let (opened, source) = AsyncStream<URL>.makeStream()
        defer { source.finish() }
        var iterator = opened.makeAsyncIterator()
        let state = HTMLPreviewState(openLink: { source.yield($0) })
        defer { state.stop() }
        await state.load("<h1>Links</h1><a id='external' href='https://example.invalid/document' \(newWindow ? "target='_blank'" : "")>Open</a>")
        let view = try #require(state.webView)
        let deadline = Task {
            do { try await Task.sleep(for: .seconds(5)); source.finish() } catch {}
        }
        defer { deadline.cancel() }
        _ = try await view.callAsyncJavaScript("document.getElementById('external').click();", arguments: [:], in: nil, contentWorld: .defaultClient)
        let link = await iterator.next()
        #expect(link?.absoluteString == "https://example.invalid/document")
        #expect(view.url?.scheme == HTMLPreviewSchemeHandler.scheme)
    }

    @Test func failedPolicyPreparationAndOversizedSourceDoNotCreateAWebView() async {
        let failed = HTMLPreviewState(rules: { throw CocoaError(.fileReadNoPermission) })
        await failed.load("<h1>Source remains editable</h1>")
        #expect(failed.webView == nil && failed.errorMessage != nil && !failed.isLoading)
        let oversized = HTMLPreviewState()
        await oversized.load(String(repeating: "x", count: TextPreview.maximumBytes + 1))
        #expect(oversized.webView == nil && oversized.errorMessage?.contains("1 MiB") == true && !oversized.isLoading)
    }

    @Test(arguments: [false, true])
    func obsoleteOrStoppedPolicyPreparationCannotPublishAWebView(stopped: Bool) async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<WKContentRuleList, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = HTMLPreviewState(rules: { try await withCheckedThrowingContinuation { source.yield($0) } })
        let old = Task { await state.load("<h1>Old</h1>") }
        let oldRead = try #require(await iterator.next())
        let latest = Task { await state.load("<h1>Latest</h1>") }
        let latestRead = try #require(await iterator.next())
        let rules = try #require(try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "PanePeekHTMLStaleTest", encodedContentRuleList: #"[{"trigger":{"url-filter":".*"},"action":{"type":"block"}},{"trigger":{"url-filter":"^panepeek-html://"},"action":{"type":"ignore-previous-rules"}}]"#))
        latestRead.resume(returning: rules)
        await latest.value
        let current = state.webView
        if stopped { state.stop() }
        oldRead.resume(throwing: CocoaError(.fileReadNoPermission))
        await old.value
        #expect(stopped ? state.webView == nil : state.webView === current)
        #expect(state.errorMessage == nil && !state.isLoading)
        state.stop()
    }

    @Test func cancelledPolicyPreparationCannotPublishAnError() async throws {
        let (requests, source) = AsyncStream<CheckedContinuation<WKContentRuleList, any Error>>.makeStream()
        defer { source.finish() }
        var iterator = requests.makeAsyncIterator()
        let state = HTMLPreviewState(rules: { try await withCheckedThrowingContinuation { source.yield($0) } })
        let pending = Task { await state.load("<h1>Cancelled</h1>") }
        let read = try #require(await iterator.next())
        pending.cancel()
        read.resume(throwing: CocoaError(.fileReadNoPermission))
        await pending.value
        #expect(state.webView == nil && state.errorMessage == nil && !state.isLoading)
    }
}

@MainActor private final class HTMLResourceRequests: NSObject, WKURLSchemeHandler {
    private(set) var urls: [URL] = []
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url { urls.append(url) }
        urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
