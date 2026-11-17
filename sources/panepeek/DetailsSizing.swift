import AppKit
import Observation

@Observable @MainActor
final class DetailsSizing {
    static let browserMinimum: CGFloat = 250
    static let detailsMinimum: CGFloat = 280
    static let compactWidth: CGFloat = 300
    private(set) var preferredWidth: CGFloat = compactWidth
    private(set) var isExpanded = false
    private(set) var browserProportion: CGFloat = 1
    // Consumed once the native window is attached, before startup can publish.
    var frameToRestore: NSRect?
    var restoredBrowserLayoutReady = false
    @ObservationIgnored private var layout: (visibleWidth: CGFloat, maximumWidth: CGFloat, backingScale: CGFloat)?
    @ObservationIgnored private var hasRestoredWidth = false
    @ObservationIgnored var refreshLayout: (() -> Void)?

    static func maximumProportion(browserCount: Int) -> CGFloat {
        browserCount == 1 ? 0.66 : 0.5
    }

    static func maximumWidth(in contentWidth: CGFloat, dividerThickness: CGFloat, browserCount: Int = 2) -> CGFloat {
        max(detailsMinimum, min(contentWidth * maximumProportion(browserCount: browserCount),
                               contentWidth - CGFloat(browserCount) * (browserMinimum + dividerThickness)))
    }

    func requestedWidth(in contentWidth: CGFloat, browserCount: Int = 2) -> CGFloat {
        isExpanded ? contentWidth * Self.maximumProportion(browserCount: browserCount) : preferredWidth
    }

    func recordLayout(contentWidth: CGFloat, dividerThickness: CGFloat, visibleWidth: CGFloat,
                      browserCount: Int = 2, backingScale: CGFloat = 1) {
        guard contentWidth > 0 else { return }
        let maximumWidth = Self.maximumWidth(in: contentWidth, dividerThickness: dividerThickness, browserCount: browserCount)
        layout = (visibleWidth, maximumWidth, backingScale)
    }

    private func isAtMaximum(_ width: CGFloat) -> Bool {
        guard let layout else { return false }
        // AppKit can place the divider at the last whole backing pixel under the limit.
        return width >= (layout.maximumWidth * layout.backingScale).rounded(.down) / layout.backingScale
    }

    func toggleExpansion() {
        if isExpanded && hasRestoredWidth {
            refreshLayout?()
            if layout != nil {
                if isAtMaximum(preferredWidth) { preferredWidth = Self.compactWidth }
                hasRestoredWidth = false
            }
        }
        isExpanded.toggle()
    }

    func setBrowserProportion(_ proportion: CGFloat) {
        browserProportion = proportion
    }

    func restorePreferredWidth(_ width: CGFloat, expanded: Bool = false) {
        preferredWidth = width
        isExpanded = expanded
        hasRestoredWidth = true
    }

    func setWidthFromUser(_ width: CGFloat) {
        guard !isExpanded || !isAtMaximum(width) else { return }
        preferredWidth = min(max(width, Self.detailsMinimum), layout?.maximumWidth ?? Self.detailsMinimum)
        isExpanded = false
        hasRestoredWidth = false
    }

    func adjust(by delta: CGFloat) {
        refreshLayout?()
        setWidthFromUser((layout?.visibleWidth ?? Self.compactWidth) + delta)
    }
}
