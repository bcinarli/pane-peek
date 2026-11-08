# Native Details sizing

Status: Active

The window owns preferred Details width and expansion state. The native split controller, hosting controllers and editor retain their identity during sizing. Browser/Details minimums and the mode-dependent maximum enforce bounds throughout dragging; a lower-priority width preference retains the requested width through temporary clamping.

The browser-width proportion has lower priority than the Details width preference, keeping Expand/Restore distribution stable. Fresh windows start with equal proportions; deliberate browser-divider drags change the ratio, while automatic sizing and Details dragging preserve it through clamping. [A27](../specs/001-mvp/spec.md#multiple-windows-and-remembered-directories) owns persistence.

Native split notifications change the Details preference or exit expansion only for user drags of its divider. Divider indices alone do not distinguish automatic layout: notifications also need `NSSplitViewUserResizeKey`, described in [Apple's resize notification documentation](https://developer.apple.com/documentation/appkit/nssplitview/willresizesubviewsnotification). Browser-divider drags preserve Details expansion. Keyboard sizing uses current native geometry because layout callbacks can lag window resizing.

TextKit can move the clip toward a retained selection during width reflow. The editor retains its pre-reflow scroll origin through ordinary layout, subject to native document bounds. Native requests to reveal a text range cancel pending restoration so that the requested range stays visible. [Document Find feedback](../specs/001-mvp/evidence/document-find-match-feedback.md) owns the verified scope and remaining checks.

Bounds reserve space for the visible browsers and dividers. The Details divider index depends on the visible browser count. [Layout evidence](../specs/001-mvp/evidence/browser-layout-modes-expandable-details.md) owns verified outcomes and limits.

## Hosted content constraints

The split items and window own panel bounds. Their hosting controllers use `sizingOptions = []`: result lists and multiline search warnings fit those bounds without changing the hosts' minimum or maximum size. Competing content-derived constraints can cause repeated native layout passes and an AppKit exception. [Apple's sizing-options documentation](https://developer.apple.com/documentation/swiftui/nshostingcontroller/sizingoptions) describes the generated constraints; [search relevance evidence](../specs/001-mvp/evidence/search-relevance.md) owns verified outcomes and limits.

## Browser modes and retained state

`PaneID.left` and `.right` identify retained browsers independently of their displayed sides. `BrowserState.presentationOrder` owns those sides and accessible names follow it. One-pane mode rejects focus, selection, navigation and new other-pane requests to the hidden browser; submitted transfers retain their captured targets under [A8/A34](../specs/001-mvp/spec.md#browser-layout-modes-and-details-sizing).

One-pane mode detaches only the hidden native split item, retaining its hosting controller. The active browser and Details stay attached, preserving the editor and first responder. Returning to two panes places the retained hidden item after the active browser.

A one-shot main-run-loop observer restores captured browser scroll origins after the layout transaction, preserving scroll through reattachment.
