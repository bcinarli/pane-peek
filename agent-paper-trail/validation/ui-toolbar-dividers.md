# Toolbar divider revision validation

Status: accepted. Bilal confirmed the live-drag correction and authorised commit on 2026-10-09. Push remains separately gated.

## Scope and result

The two content dividers now start below the toolbar. `BrowserSplitView` owns a public AppKit `NSSplitViewController` with three `NSHostingController` children, replacing `HSplitView`. The existing file panes, Details content and toolbar remain SwiftUI.

The first layout balances the file panes and requests 300 points for Details with temporary low-priority constraints. After appearance, it releases those constraints and intrinsic sizing. Native split items own the width limits: file panes have a 250-point minimum; Details is 280–400 points. SwiftUI fills the allocated space. Constraint activation happens after child attachment. Accent tint and scene phase are passed explicitly into the hosted panes.

SwiftUI has no public tracking-separator removal control. Retaining its separators would keep the smaller implementation. The owned AppKit container adds a native integration boundary that requires resize and focus review. It uses no private view lookup, generated toolbar-item removal or custom divider gestures.

API references: [NSSplitViewController](https://developer.apple.com/documentation/appkit/nssplitviewcontroller), [tracking separators](https://developer.apple.com/documentation/appkit/nstrackingseparatortoolbaritem), [hosting sizing options](https://developer.apple.com/documentation/swiftui/nshostingcontroller/sizingoptions).

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4 and macOS SDK 27.0 on Apple Silicon. Deployment minimum remains macOS 26; no macOS 26 runtime check is claimed.

| Check | Result |
| --- | --- |
| Build/package | `node scripts/build-app.mjs` passes with normal compiler-cache access. Existing CLT linker search-path warnings remain non-fatal. |
| Bundle/whitespace | Info.plist lint and `git diff --check` pass. |
| Native launch | Final build launches with equal file-pane widths and a 300-point Details panel. |
| Dark appearance | Native screenshots show an uninterrupted toolbar; both vertical separators begin at its lower edge. Idle toolbar controls remain bare icons. |
| Native sizing | Both dividers moved during runtime checks. Native accessibility adjustments clamp file-pane width at 250 points and Details width at 280–400 points. Unequal widths survive navigation and selection updates. |
| Focus and selection | Command-L independently navigates each focused pane. Multi-selection and arrow navigation update the primary item and Details. Final build rechecked focused navigation and selection with unequal widths. |
| Native commands | Go → Enclosing Folder targets the focused right pane. Directory actions → Refresh dismisses and retains the listing. Item context menu exposes both copied-path actions. |

No new automated behaviour tests or full suite rerun for this layout unit, following the [plan's validation rule](../specs/001-mvp/plan.md#task-workflow-and-exit-gates).

## Review passes and manual gate

Standard tighten retained typed hosting controllers. Standard probe checked lifecycle, native sizing and focused-command integration; it also added explicit scene-phase forwarding for the panes' existing activation refresh.

Quit PanePeek before rebuilding, then use the [build/run instructions](../../README.md#build-and-run). The final bundle is running for review; no fixture or filesystem mutation is needed.

- [x] Bilal confirms toolbar separation in dark and light appearance.
- [x] Bilal confirms both dividers drag freely and retain their positions.
- [x] Bilal confirms window resizing and fullscreen work.

The focused-pane and menu checks above are agent evidence. Bilal also authorised a separate panel-header alignment follow-up. Commit and push retain separate approval gates.

## Live-drag correction

[Changed] Bilal's recording shows Details growing beyond its intended width while held, with panel content shifting and snapping back on release. The earlier endpoint checks did not cover that trajectory. Width limits had been declared only in SwiftUI; the native split items had unspecified limits.

The correction moves those limits to the public `NSSplitViewItem.minimumThickness` and `maximumThickness` properties and removes competing SwiftUI width bounds. Initial Details width is now part of the temporary first-layout constraints. Retaining SwiftUI bounds would leave two sizing owners; nesting splits would add another container without addressing the missing native limits.

Final build/package, Info.plist lint and whitespace checks pass. Native launch at a 1,100-point window gives 399/399/300-point panels. Native accessibility adjustments reach Details widths of 280 and 400 without moving the left divider; an out-of-range adjustment is rejected. The left pane reaches its 250-point minimum. Both panes navigate independently and selection updates Details without changing widths. An intermediate build also survived native half-window resizing and restoration within the limits.

Temporary frame diagnostics were removed. Automated pointer attempts did not reliably move the Details divider; they are not evidence that the live-drag regression is resolved. No new automated behaviour test or full suite rerun is claimed. Standard tighten centralised width ownership in the native split items; standard probe checked initial constraint release, bounds and navigation. The final app is running for manual review.

- [x] Bilal confirms the reported live-drag/release regression is fixed.

Bilal accepted the correction and authorised commit of the reviewed changes. The follow-up response did not separately enumerate both-direction, window-resize or fullscreen checks; their earlier acceptance is recorded above.
