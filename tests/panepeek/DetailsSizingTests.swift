import AppKit
import Testing
@testable import PanePeek

@MainActor struct DetailsSizingTests {
    @Test func boundsReserveBothBrowsersAndDividersBeforeAllowingHalfWidth() {
        #expect(DetailsSizing.maximumWidth(in: 1100, dividerThickness: 1) == 550)
        #expect(DetailsSizing.maximumWidth(in: 800, dividerThickness: 1) == 298)
        #expect(DetailsSizing.maximumWidth(in: 800, dividerThickness: 2) == 296)
    }

    @Test func singlePaneBoundsReserveTheBrowserAndAllowSixtySixPercentWidth() {
        #expect(DetailsSizing.maximumWidth(in: 1400, dividerThickness: 1, browserCount: 1) == 924)
        #expect(DetailsSizing.maximumWidth(in: 800, dividerThickness: 1, browserCount: 1) == 528)
        #expect(DetailsSizing.maximumWidth(in: 800, dividerThickness: 2, browserCount: 1) == 528)
        #expect(DetailsSizing.maximumWidth(in: 700, dividerThickness: 1, browserCount: 1) == 449)
        let sizing = DetailsSizing()
        sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 900, browserCount: 1)
        sizing.adjust(by: 400)
        #expect(sizing.preferredWidth == 924)
        sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 528, browserCount: 1)
        #expect(sizing.preferredWidth == 924)
        sizing.adjust(by: -10)
        #expect(sizing.preferredWidth == 518)
    }

    @Test func automaticClampingRetainsTheRequestedWidth() {
        let sizing = DetailsSizing()
        sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 300)
        sizing.setWidthFromUser(620)
        sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 298)
        #expect(sizing.preferredWidth == 620)
        sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 620)
        #expect(sizing.requestedWidth(in: 1400) == 620)
    }

    @Test func expansionFollowsWindowWidthAndRestoreKeepsThePreferenceBeforeClamping() {
        let sizing = DetailsSizing()
        sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 300)
        sizing.setWidthFromUser(480)
        sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 298)
        sizing.toggleExpansion()
        #expect(sizing.isExpanded)
        #expect(sizing.requestedWidth(in: 800) == 400)
        #expect(sizing.requestedWidth(in: 1400) == 700)
        sizing.toggleExpansion()
        #expect(!sizing.isExpanded)
        #expect(sizing.preferredWidth == 480)
    }

    @Test func keyboardSizingStartsFromTheClampedVisibleWidth() {
        let sizing = DetailsSizing()
        sizing.recordLayout(contentWidth: 1400, dividerThickness: 1, visibleWidth: 300)
        sizing.setWidthFromUser(620)
        sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 298)
        sizing.adjust(by: -10)
        #expect(sizing.preferredWidth == 288)
        sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 288)
        sizing.adjust(by: 100)
        #expect(sizing.preferredWidth == 298)
        sizing.recordLayout(contentWidth: 800, dividerThickness: 1, visibleWidth: 298)
        sizing.adjust(by: -100)
        #expect(sizing.preferredWidth == 280)
    }

    @Test func deliberateSizingExitsExpansionAndBecomesTheNextRestoreWidth() {
        let sizing = DetailsSizing()
        sizing.recordLayout(contentWidth: 1100, dividerThickness: 1, visibleWidth: 300)
        sizing.toggleExpansion()
        sizing.recordLayout(contentWidth: 1100, dividerThickness: 1, visibleWidth: 550)
        sizing.adjust(by: -10)
        #expect(!sizing.isExpanded)
        #expect(sizing.preferredWidth == 540)
        sizing.toggleExpansion()
        sizing.toggleExpansion()
        #expect(sizing.preferredWidth == 540)
    }
}
