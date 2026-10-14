---
task: remembered-directory-pair
verdict: Passed
closed: "2026-10-14"
---

# T17 Restore the remembered directory pair

## Unit 1: 2026-10-14

Bilal approved the plan and requested the first unit on 2026-10-14. One coding unit implements A27: the ordered pair, retained browser identities, mode/active browser and preferred Details width from the last-active window, with initial-window-only restoration and fresh New Window defaults. Local/live `main` at `2e58eb5` contains T16 PR #29's full closing head `9882a8b`; implementation uses `feature/t17-remembered-directory-pair`. Bilal accepted the presented unit overall on 2026-10-14 and authorised commit/PR publication. Individual live/native/accessibility outcomes remain unreported; publication is recorded below.

- Red/green: `node scripts/test.mjs --filter WindowRestorationTests` first compiled and failed six tests with 26 intentional behaviour failures against home-only startup, then passed. Probe added a malformed-order case; its targeted run failed three expectations before decoding was corrected. Final 11 restoration tests pass, including real temporary directories, isolated preferences, unavailable/denied hidden paths, last-active capture/final close, background-window exclusion, legacy/invalid fields, nonfinite widths, repeated startup, delayed/stale reads, native guard replacement and actual native 298-point clamping/620-point recovery. Sandbox/cache and intermediate Swift capture compilation failures are excluded from red evidence.
- `node scripts/test.mjs` passes 464 tests: 410 core and 54 app/native, with the same four intentional known gate diagnostics. The executable build and isolated review packaging pass; plist/executable/resource checks and `open`/matching-process verification pass. macOS 27.0.1 (26A434), Apple Swift 6.4, Node 26.1.0. Generated review metadata initially named the wrong executable; corrected before launch. Interactive inspection reports a locked Mac. A live fallback-record publication attempt observed the original seeded record while the Mac was locked; window activation was unverified; production startup/fallback is unverified. No live/native accessibility pass is claimed.
- Standard tighten retained the existing navigation, status UI and native sizing constraints, removed unchecked order decoding and uses the shared compact-width default. Deep probe covered coherent startup capture, later active windows, stale reads, replaced guards, final close, malformed preferences and native width bounds. No further product decision or coding unit is proposed. Bilal subsequently accepted the unit overall; publication and milestone review remain separate.

## Acceptance and remaining checks

A27 remains Pending. Automated/native fixture evidence covers its restore/capture/fallback/default contracts. A26/A34/A35 regressions check fresh windows, retained identities/order and preferred-width clamping. Bilal accepted the presented unit overall on 2026-10-14. Individual live activation, quit/relaunch, final-close relaunch, visible fallback status and affected accessibility outcomes remain unreported. Combined M3/M4 quality review is still pending; it is separate from this unit and precedes T18.

## Disposable fixture and run instructions

The running `PanePeek T17 Review` bundle is `.build/PanePeek-T17-Review.app`; its preference domain is `com.bcinarli.PanePeek.T17Review`. It does not replace the normal bundle or its preferences. The generated `.build/build-t17-review.mjs` uses the normal bundler with a separate destination, bundle name and identifier. Build output and fixture preferences are ignored by Git.

From the repository root, reopen the already built review bundle:

```sh
open .build/PanePeek-T17-Review.app
```

The prepared `.build/t17-fixture/first` and `second` directories each contain disposable `sample.txt`. Use Go to Folder (Command-L) with their absolute paths. The initial review preferences retain `first` as the visible browser and an unavailable `missing` directory as the hidden browser, One Pane mode, the right browser identity first, and a 620-point preferred width. The fallback should be visible in the shared selectable status area, including while its browser is hidden.

To reproduce that seed, quit only the review app before importing its prepared preferences, then reopen:

```sh
defaults import com.bcinarli.PanePeek.T17Review .build/t17-review-preferences.plist
open .build/PanePeek-T17-Review.app
```

A normal build remains available through the [README instructions](../../../../README.md#build-and-run). Quit that bundle before rebuilding it. For an unavailable-directory relaunch check, rename a disposable fixture directory while the review app is quit; retain it for recovery rather than deleting personal files.

## Manual review checklist

Bilal accepted the presented unit overall on 2026-10-14. The unchecked items below preserve individually unreported outcomes; they do not reverse that task acceptance.

- [ ] Initial seeded launch shows `first`; the missing hidden path falls back only to home and the full failure/fallback status is selectable, accessible and dismissible.
- [ ] Reveal the other browser, navigate to `second`, make either identity active and switch One Pane/Two Panes. Quit/relaunch restores the ordered pair, visible/active browser and shared-command target. Selection, sorting, visibility and editor state start fresh.
- [ ] Drag/keyboard-adjust Details, temporarily narrow/widen the window and quit while clamped or expanded. Relaunch uses the preferred width before clamping, with native A35 bounds; transient expansion is not persisted.
- [ ] Create a second window: both browsers start home, Two Panes and compact Details. Change window activation and verify relaunch follows the most recently active window. Background navigation does not replace its record.
- [ ] Close the final window, quit without opening another window, then relaunch. The remembered configuration survives. Repeat unavailable-path fallback after renaming a disposable directory.
- [ ] Check keyboard/focus and shared-action targeting after restore, hidden controls absent from keyboard/VoiceOver navigation, and VoiceOver error/status announcements. Check status dismissal, enlarged text/long paths in narrow windows, light/dark contrast, increased contrast and reduced motion. Record actual mechanisms/settings/sizes; app-wide acceptance remains T18.
- [ ] Directory-only and malformed preference forms retain usable paths and default only invalid fields. Automated coverage passes; individual native outcomes remain unreported.

## Review and publication

Unit manual acceptance: Passed overall on 2026-10-14. Bilal authorised commit and PR creation in the same instruction, including the required feature-branch push. Publication is in progress; merge is not authorised.
