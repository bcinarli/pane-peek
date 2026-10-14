import AppKit
import Observation

@Observable @MainActor
final class DetailsSizing {
    static let browserMinimum: CGFloat = 250
    static let detailsMinimum: CGFloat = 280
    static let compactWidth: CGFloat = 300
    private(set) var preferredWidth: CGFloat = compactWidth
    private(set) var isExpanded = false
    @ObservationIgnored private var visibleWidth: CGFloat = compactWidth
    @ObservationIgnored private var maximumWidth: CGFloat = detailsMinimum
    @ObservationIgnored var refreshLayout: (() -> Void)?

    static func maximumWidth(in contentWidth: CGFloat, dividerThickness: CGFloat, browserCount: Int = 2) -> CGFloat {
        max(detailsMinimum, min(contentWidth / 2, contentWidth - CGFloat(browserCount) * (browserMinimum + dividerThickness)))
    }

    func requestedWidth(in contentWidth: CGFloat) -> CGFloat {
        isExpanded ? contentWidth / 2 : preferredWidth
    }

    func recordLayout(contentWidth: CGFloat, dividerThickness: CGFloat, visibleWidth: CGFloat, browserCount: Int = 2) {
        self.visibleWidth = visibleWidth
        maximumWidth = Self.maximumWidth(in: contentWidth, dividerThickness: dividerThickness, browserCount: browserCount)
    }

    func toggleExpansion() {
        isExpanded.toggle()
    }

    func restorePreferredWidth(_ width: CGFloat) {
        preferredWidth = width
        isExpanded = false
    }

    func setWidthFromUser(_ width: CGFloat) {
        preferredWidth = min(max(width, Self.detailsMinimum), maximumWidth)
        isExpanded = false
    }

    func adjust(by delta: CGFloat) {
        refreshLayout?()
        setWidthFromUser(visibleWidth + delta)
    }
}
