# Directory navigation and breadcrumbs

Status: Active

Directory-link navigation uses the canonical target and its ancestry, following the [Finder-style decision](../decisions/0005-finder-directory-symlink-navigation.md). The off-thread read returns that directory together with its entries; only the latest successful request updates the pane. Foundation can normalise enumerated child URLs differently from the directory URL, so rebase children on the returned canonical directory. A link in its parent listing retains its own identity.

Breadcrumb scrolling keeps short paths beside Home and reveals the current component for long paths. SwiftUI's [scroll anchor roles](https://developer.apple.com/documentation/swiftui/view/defaultscrollanchor(_:for:)) separate undersized-content alignment from initial position. The scroll view's identity follows the displayed path so a new directory starts at its current component; failed navigation preserves the existing breadcrumb and scroll position.

Use the shared panel-header height for both the breadcrumb scroll content and its viewport. Symmetric vertical padding centres the labels while reserving space below them for the native horizontal scroller; the header must be tall enough to clear it. Home, favourite stars and Details centre in the same height. An outer frame alone does not prevent scrollbar overlap. Native buttons follow macOS Keyboard navigation: Tab traversal requires that setting, and Space activates a focused button. See [Apple's focus guidance](https://developer.apple.com/videos/play/wwdc2023/10162/).

## Favourites

The application owns one observable favourites store. Views share it; tests supply a uniquely named preference suite. Save the pane's canonical displayed directory, normalise lexical path variants and retain unavailable paths when loading preferences. Star rendering does not resolve links or check disk availability. Favourite navigation captures the focused pane before scheduling the existing directory navigation, preserving its request/error handling. See [T15 evidence](../validation/t15-persistent-favourites.md).

The pane-wide tap gesture would focus an inactive pane when its star was clicked. Focusing remains on the existing list and explicit navigation/sort controls, so star clicks retain focus, selection and the Details item. Recheck this seam and route favourite navigation through the same guard as other navigation when the editor arrives.

Use the standard native toolbar menu presentation. A forced-width layout wrapper widened the outer surface but left a narrower active highlight in light appearance; Bilal requested its removal. Explain native feasibility and presentation compromises before introducing an alternative. Validate hover/menu-open states alongside idle geometry. See [the toolbar review](../validation/t15-persistent-favourites.md#toolbar-pill-shape-follow-up).
