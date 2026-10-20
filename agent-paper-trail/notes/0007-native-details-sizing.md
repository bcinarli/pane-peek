# Native Details sizing

Status: Active

The window owns preferred width and expansion state. Keep the existing native split controller and hosting controllers alive during sizing; do not recreate the editor. Native browser/Details minimums and a required half-content-width constraint enforce bounds throughout dragging. A lower-priority width preference retains the requested width through temporary clamping. Activate constraints after the split children share a view hierarchy.

Retain a browser-width proportion below the Details width preference. Leaving the browser distribution unconstrained allowed repeated Expand/Restore clicks to allocate the same remaining space differently. Start at equal proportions; a user browser-divider drag captures its chosen ratio. Automatic sizing and Details dragging preserve that ratio, including through temporary minimum-width clamping. This is session-only native layout state, with no new persistence requirement.

For native split notifications, require a user drag of the Details divider before changing the preference or exiting expansion. Divider indices also occur on automatic layout notifications, so require `NSSplitViewUserResizeKey` as well. Resizing the browser divider must preserve Details expansion. [Apple's resize notification documentation](https://developer.apple.com/documentation/appkit/nssplitview/willresizesubviewsnotification) describes the user-resize flag. Keyboard sizing measures the current native geometry immediately before applying its delta; layout callbacks alone can leave stale measurements after window resize.

TextKit can scroll a retained selection into view during width reflow. The existing editor snapshots its scroll origin on width change and restores it after layout, subject to native document bounds. The native split regression test covers an offscreen selection, dirty buffer, same text-view identity and retained undo alongside scroll position.

Bounds reserve the visible browser count and its dividers. In single mode the Details divider has a different native index; derive it from the visible count before interpreting a drag. Relaunch persistence belongs to T17. [T19 evidence](../specs/001-mvp/evidence/browser-layout-modes-expandable-details.md) owns current outcome and limits.

## Browser modes and retained state

`PaneID.left` and `.right` identify retained browsers, not their current displayed sides. `BrowserState.presentationOrder` owns those sides and accessible names follow it. One-pane mode rejects focus, selection and navigation commands to the hidden identity; new other-pane requests receive no destination. Real transfer handlers and captured operation snapshots remain later tasks.

Detach only the hidden native split item and retain its hosting controller. The active browser and Details stay attached, preserving the native editor and first responder. Restore the hidden item after the active browser, so a previously right browser stays on the left when returning to dual.

SwiftUI's native List can adjust its clip origin after reattachment, even with the same host and scroll view. Capture browser scroll origins before detaching and restore them after the UI layout transaction, with a one-shot main-run-loop observer. Restoring immediately or through queued blocks ran before the list's own offset adjustment. The native regression checks actual retained list scroll, alongside the existing editor identity/caret/scroll/undo checks.
