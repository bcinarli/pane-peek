import AppKit
import WebKit

/// Hosts the native Find bar while WebKit retains its own document scrolling and text-search client.
@MainActor final class HTMLFindView: NSScrollView, NSUserInterfaceValidations {
    let webView: WKWebView
    private let finder = NSTextFinder()

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        borderType = .noBorder
        drawsBackground = false
        hasVerticalScroller = false
        hasHorizontalScroller = false
        findBarPosition = .aboveContent
        documentView = webView
        webView.autoresizingMask = [.width, .height]
        finder.client = webView
        finder.findBarContainer = self
        finder.isIncrementalSearchingEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func tile() {
        super.tile()
        if webView.frame.size != contentSize { webView.setFrameSize(contentSize) }
    }

    override func performTextFinderAction(_ sender: Any?) {
        guard let item = sender as? NSValidatedUserInterfaceItem,
              let action = NSTextFinder.Action(rawValue: item.tag), finder.validateAction(action) else { return }
        finder.performAction(action)
    }

    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard item.action == #selector(performTextFinderAction(_:)),
              let action = NSTextFinder.Action(rawValue: item.tag) else { return false }
        return finder.validateAction(action)
    }

    func detach() {
        if isFindBarVisible { finder.performAction(.hideFindInterface) }
        finder.cancelFindIndicator()
        finder.client = nil
        finder.findBarContainer = nil
    }
}
