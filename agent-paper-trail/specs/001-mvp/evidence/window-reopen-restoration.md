---
task: window-reopen-restoration
verdict: Passed
closed: 2026-10-16
---

# Window reopen and relaunch restoration

## Scope and approval

Bilal approved the [restoration clarification](../../../decisions/2026-10-16-window-reopen-and-relaunch-restoration.md) and lifecycle Unit 1 on 2026-10-16. Both X/Dock reopening and Command-Q relaunch must restore the existing ordered directories, browser mode/active identity and preferred Details width. Explicit New Window stays fresh, including after final close. Original T17 acceptance remains in its [historical evidence](remembered-directory-pair.md).

Bilal approved and accepted all three restoration units overall on 2026-10-16. The presented T17 correction is Completed/Passed; individual manual/accessibility outcomes remain unreported and full A27 remains Pending. Bilal authorised committing the restoration changes and creating a PR, including the required feature-branch push. Merge remains a separate gate.

## Unit 1: 2026-10-16

- Verified live/local main at `8f5403e` contains T17 closing head `dcf29ac`; work uses `bcinarli/t17-reopen-restoration`. macOS 27.0.1 (26A434), Apple Swift 6.4, Node 26.1.0.
- Intentional red: `node scripts/test.mjs --filter WindowRestorationTests` compiled and failed 12 expectations across repeated Dock reopening and immediate-Quit capture/relaunch. The three existing known timeout diagnostics are separate from behaviour failures. The focused green run passes all 16 restoration tests, with those three known diagnostics.
- Final `node scripts/test.mjs` passes 487 tests: 422 core and 65 app/native. The nine existing known timeout/self-test diagnostics remain expected. `node scripts/build-app.mjs` succeeds; isolated bundle plist/executable/resource checks pass. No tests mutate normal app preferences.
- Agent-observed native checks: seeded initial launch shows the visible `second` directory in One Pane with 420-point preferred Details. Closing the final window and reopening through the native app-launch route restores that configuration. Revealing Two Panes shows `second` then `first`. Explicit File → New PanePeek Window creates a separate home/home, Two Panes, compact-Details window. Keyboard Details widening changes the saved preference to 430 points. Command-Q exits the review process; its preferences retain the ordered pair, changed Two Panes mode, active identity and 430-point width. A fresh launch shows both directories and mode with the matching split allocation.
- The Dock accessibility-control call timed out. Direct Dock-icon clicking is still a manual check; native reopen-handler fixtures and app-launch reopening pass. Full VoiceOver, enlarged text, contrast/settings and dirty-document manual outcomes remain unreported. These observations do not establish an app-wide accessibility pass; subsequent overall acceptance is recorded below.
- Standard tighten reduced startup/reopen intent to one consumable restore flag and reused the existing snapshot/startup guards. Deep probe checked repeated reopen, no-op startup not consuming a reopen request, explicit fresh creation after final close, visible/miniaturised-window activation, synchronous clean and resolved-quit capture, final-close/quit/relaunch, legacy preferences and existing stale-read/native-clamp regressions. No second-model escalation was needed for this bounded correction.

## Unit 1 acceptance: 2026-10-16

Bilal reported that Unit 1 works as expected and accepted its presented lifecycle scope overall. Individual manual/accessibility outcomes remain unreported. Bilal also observed that clicking Expand Details is not restored; this is the separately planned expansion field, rather than the preferred-width snapshot implemented in Unit 1. Proposed next slice: persist the expanded state and retain its underlying preferred width through both reopen paths, while explicit New Window stays compact. Coding approval for that slice remains pending; browser proportions and window geometry remain later work. No commit/push/merge authorisation was given.

## Unit 2a: expanded Details, 2026-10-16

Bilal approved this focused addition after accepting lifecycle Unit 1. Save `detailsExpanded` independently from `detailsWidth`; restore both through Dock reopening and Command-Q relaunch. Keep Restore Previous Width, compact fresh windows and independent legacy/invalid-field defaults. Browser proportions and geometry remain Unit 2b.

- Intentional red: the two new focused tests compiled; the expansion test failed 12 expectations across Dock and relaunch cases for missing capture/restoration and incorrect native widths. Legacy/invalid expansion defaults already passed. After persistence was added, the full restoration suite isolated two remaining native narrow-to-wide failures: expanded Details stayed at the previous 800-point window's 400-point request after widening to 1400. Refreshing sizing after completed native layout makes both focused tests pass, including native 298-point clamping, 700-point expansion and Restore Previous Width at 480.
- Final `node scripts/test.mjs` passes 489 tests (422 core + 67 app/native) with the same nine known diagnostics. `node scripts/build-app.mjs` and updated isolated executable/metadata/assets checks pass. The review bundle keeps its isolated preferences.
- Agent-observed native review, with pointer activation of the remembered window: click Expand Details, close final window and reopen through the native app-launch route. Details stays expanded and exposes Restore Previous Width/Expanded. Command-Q exits the process; preferences retain `detailsExpanded = true` separately from the 374.5-point preferred width. Fresh launch remains expanded. Clicking Restore Previous Width returns the original split allocation and changes its accessible value to Preferred width. The app is left open and expanded for Bilal. Direct Dock-icon clicking and full VoiceOver/enlargement/appearance checks remain manual.
- Standard tighten reused the existing dictionary, observation, startup and sizing paths; no second persistence owner. Deep probe covers capture on expansion-only changes, both reopen paths, restoring the underlying width, compact fresh windows, missing/invalid expansion values, legacy width/directory retention and real narrow-to-wide native bounds. `git diff --check` and changed-record local links/anchors pass. Manual acceptance and full A27 remain pending.

## Unit 2a acceptance: 2026-10-16

Bilal reported that the expansion addition works as expected and accepted its presented scope overall. Individual manual/accessibility outcomes remain unreported. Bilal explicitly approved Unit 2b for browser proportions and window size/position on both reopen paths. No commit/push/merge authorisation was given.

## Unit 2b: proportions and window geometry, 2026-10-16

Persist the nominal left/right browser width ratio and full native window frame in the existing last-active snapshot. Capture deliberate browser-divider changes, window moves/resizes and the synchronous close/quit snapshot. Restore the frame once when native attachment is available, before startup can publish; explicit New Window retains fresh split preferences and platform geometry. Validate malformed fields independently, fit the frame to the screen with greatest overlap (nearest when none overlap), and apply native minimum content bounds.

- Intentional red: the two focused tests compiled; Dock/relaunch cases failed eight expectations for missing frame/ratio capture and restoration. The off-screen safety check passed against fresh defaults. After implementation, both focused tests pass.
- Focused probe: 31 tests across restoration, native splits and geometry pass. This includes real 60/40 browser dragging; frame/ratio restore on both paths; native minimums and proportion recovery after narrowing; mode/presentation-order changes and Details expansion; delayed attachment with one-time frame consumption; frame-only move capture; malformed/nonfinite fields; valid negative screen coordinates, greatest overlap, removed-screen fitting, minimum-size fitting and no-screen fallback. Geometry display-change cases use synthetic visible frames; real display disconnect/reconnect remains manual.
- Deep-probe red: a window with a larger native minimum restored below that minimum (one failing expectation). Restore now combines the shared content minimum with the attached window's native minimum before fitting. Final suite passes 497 tests (422 core + 75 app/native), with the same nine known diagnostics. `node scripts/build-app.mjs`, isolated executable/metadata/assets checks and final diff/link checks pass.
- Agent-observed native seeded review: ratio 1.5 (60/40) and full frame x=200, y=150, width=1200, height=700. Initial launch, final-close/native app-launch reopening and Command-Q/relaunch retain the unequal split (449.5/300 native browser widths with pixel rounding). Activated close/quit capture retains the exact seeded dictionary, including the actual frame. The review process exits on Command-Q. Original isolated preferences are backed up; normal preferences are unchanged.
- Live drag/AX divider attempts did not change the review layout through automation; no passing pointer-drag capture claim is made. Real native fixture notifications/setFrame verify capture, and seeded native app checks verify restoration. Direct Dock clicking, live pointer movement/resizing, real display rearrangement and full accessibility remain manual checks. The final review app is left open with the seeded geometry.
- Standard tighten keeps one shared snapshot and native delegate forwarding, one source for minimum content size, and a single pending frame on the window-owned sizing object. Deep probe covers stale/late registration, once-only frame application, ratio retention across clamping/reordering/Details expansion, malformed fields, native minima and synthetic display changes. No new persistence owner or abstraction layer. Manual acceptance and full A27 remain Pending.

## Unit 2b acceptance and publication: 2026-10-16

Bilal reported that the final restoration changes work as expected and accepted the presented Unit 2b scope overall. He requested a commit and PR for the restoration changes. This closes the presented correction scope; it does not establish individual outcomes for the unchecked native/accessibility/display cases below. Full A27 remains Pending. Implementation commit [`e210e71`](https://github.com/bcinarli/pane-peek/commit/e210e71c5a1e25822862b8baf77d7d58839d8504) is published in [PR #33](https://github.com/bcinarli/pane-peek/pull/33), targeting `main`. Merge is not authorised.

## Review fixture

Use the isolated `PanePeek T17 Reopen Review` app with its own preference domain. Generated bundle and disposable directories live under `.build/` and are ignored by Git. The normal app's preferences are unchanged. The review domain is `com.bcinarli.PanePeek.T17ReopenReview`; its current geometry-review record retains the fixture root/`second`, Two Panes, the left browser identity active, unexpanded Details at 448.5 points, browser ratio 1.5 and frame (200,150,1200,700). `first/sample.txt` and `second/sample.txt` contain disposable text.

```sh
open .build/PanePeek-T17-Reopen-Review.app
```

Use Command-L with absolute paths to `.build/t17-reopen-fixture/first` and `second` for navigation checks. To reset the original seed, quit only the review app and run:

```sh
defaults import com.bcinarli.PanePeek.T17ReopenReview .build/t17-reopen-fixture/seed.plist
open .build/PanePeek-T17-Reopen-Review.app
```

The original seed is One Pane, right browser first, 420-point preferred Details. The later `geometry-review.plist` adds the known 60/40 split/frame; `before-geometry-review.plist` preserves the previous isolated preferences and `after-geometry-quit.plist` records the exact native round trip. Generated bundle/seed references describe this review workspace while retained. Build/run commands for the maintained app remain in the [README](../../../../README.md#build-and-run).

## Manual and affected accessibility checks

- [ ] Browse different disposable directories, choose either active browser, set One Pane/Two Panes and drag or keyboard-adjust Details. Close the final window with X, click its Dock icon and verify directories, order/mode, active command target and preferred width. Repeat twice.
- [ ] Command-Q with a window open, then relaunch; verify the same configuration. Repeat after closing all windows before Quit.
- [ ] Explicit File → New Window stays home/home, Two Panes and compact Details, both with an existing window and after final close. Activating a miniaturised window must not change this behaviour for the next New Window.
- [ ] With multiple windows, change which is active and close in different orders. Reopening follows the last-active captured configuration; background changes do not replace it.
- [ ] Quit/close with a disposable dirty draft: Cancel retains it; Save/Discard continue existing safeguards. No editor buffer is restored after a completed close/relaunch.
- [ ] Verify keyboard navigation and shared-action targeting after each restoration path, hidden controls absent from keyboard/VoiceOver navigation, and visible/announced fallback status for an unavailable remembered directory. Check light/dark, long paths, enlarged text, increased contrast and reduced motion; record actual settings/mechanisms.
- [x] Manual acceptance from Bilal for Unit 1 overall on 2026-10-16; individual checks above remain unreported.

## Expanded Details manual review

- [ ] Choose a non-default Details width, click Expand Details, close the final window with X and reopen from the Dock. Verify expanded appearance and the Restore Previous Width label/value.
- [ ] Repeat with Command-Q/relaunch, including quitting with no windows open. Click Restore Previous Width and confirm the chosen width returns.
- [ ] Narrow/widen while expanded; native limits apply without losing the preferred width. Explicit New Window stays compact.
- [ ] Verify keyboard View-menu Expand/Restore, visible focus and VoiceOver value after both restoration paths. Check the retained editor/draft and affected appearance/enlargement settings; record individually observed outcomes.
- [x] Bilal accepted Unit 2a overall on 2026-10-16; individual checks remain unreported.

## Proportions and geometry manual review

- [ ] Drag the browser divider to an unequal split, move and resize the window, close the final window with X and reopen from the Dock. Verify the split, size and placement, then repeat with Command-Q/relaunch and close-all/quit/relaunch.
- [ ] Narrow/widen and expand/restore Details without losing the chosen browser proportion. Switch One Pane/Two Panes with either identity active and verify the intended widths after the presentation order changes.
- [ ] Explicit New Window stays home/home, equal browsers, Two Panes and compact Details. Change the active window and verify background moves/resizes do not replace its record.
- [ ] If multiple displays are available, restore a window placed on a negative-coordinate display and after disconnect/rearrangement; keep the window and title bar usable. Check narrow layouts, keyboard/shared-action focus, VoiceOver structure and retained editor state. Record actual display/settings outcomes; synthetic tests do not establish native multi-display acceptance.
- [x] Bilal accepted Unit 2b overall on 2026-10-16; individual checks remain unreported.

A27 remains Pending until the full corrected criterion is exercised. Overall unit acceptance does not backfill individual native/accessibility outcomes.
