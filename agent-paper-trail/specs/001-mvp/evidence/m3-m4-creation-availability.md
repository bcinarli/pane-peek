---
task: m3-m4-creation-availability
verdict: Passed
closed: "2026-10-14"
---

# M3/M4 creation availability

C2.2 addresses reviewed finding F2. Bilal approved this final planned unit on 2026-10-14 after accepting C2.1. Bilal accepted the presented unit overall and requested its commit and PR publication on 2026-10-14. That instruction covers the presented timeout self-test correction and final validation. Committed as `f78fc8c` and published in [PR #31](https://github.com/bcinarli/pane-peek/pull/31), targeting `main`. Individual native/accessibility outcomes remain unreported; merge retains separate approval.

## Change

`BrowserState.canCreate(in:)` owns creation availability. The core entry, focused File/toolbar actions and pane-specific background menus use it. The predicate includes visible-pane targeting, shared mutation/drag reservations, active operations/name prompts, Save and pending dirty decisions. A dirty draft alone still permits the existing Save/Discard/Cancel workflow. Captured navigation identity and submission validation remain in place.

The regression exposed a core overlap: if the draft returned to its original text while a dirty decision remained unanswered, a second creation could open a name prompt. Pending decisions now block new creation until resolved.

## Checks

- 2026-10-14, baseline: 23 existing creation tests passed. Intentional red: `pendingDirtyDecisionBlocksAnotherCreationEvenIfTheDraftBecomesClean` failed because a second request opened while the first dirty decision was pending. The run exited 1 with one behaviour issue.
- 2026-10-14, green: 114 targeted tests across 11 suites passed. Coverage includes visible/hidden panes, name prompt/cancellation, active creation and rename, shared Save, Move/Trash confirmation, outgoing drag, dirty Save/Discard/Cancel and stale captured requests.
- Initial full run: 56 native tests passed; 416 core tests ran, with failure confined to C1.1's `missingRequestOrReleaseReportsTimeout` self-test. Its one-second poll could reach cleanup before the scheduled zero-timeout failure. The presented test-only correction now awaits the expected timeout directly instead of racing a one-second poll. Production gate behaviour is unchanged; [C1.1 evidence](m3-m4-test-gate-diagnostics.md#final-diagnostic-correction) records the correction.
- 2026-10-14, final green: all three gate self-tests passed with two expected diagnostics. The full suite passed 416 core tests across 48 suites and 56 native tests across ten suites (472 total), with nine expected timeout-diagnostic issues.
- 2026-10-14: app build, isolated packaging, launch/process and diff checks pass on macOS 27.0.1 with Swift 6.4. Bilal accepted the unit overall; individual native menu/accessibility observations remain unreported.

Reproduce:

```sh
node scripts/test.mjs --filter 'ItemCreationTests|BrowserCreationTests|BrowserRenameTests|BrowserCopyTests|BrowserMoveTests|BrowserTrashTests|OperationCoordinationTests|WindowRecoveryTests|OutgoingDragTests|DropTransferTests|SaveTests'
node scripts/test.mjs
swift build --product PanePeek
```

Tighten uses one local capability and existing fixtures, with no capability framework. Probe checks the Save/Discard resume boundary, captured pane identity, shared reservations and nil focused-window handling. The diagnostic correction removes polling scaffolding while retaining typed timeout and sticky-failure assertions. Individual native menu/accessibility outcomes remain unreported.

## Running app and disposable fixture

From the repository root, activate the isolated app and print its disposable directories:

```sh
node --input-type=module <<'JS'
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const review = JSON.parse(readFileSync('.build/quality-c2-2-review.json', 'utf8'));
execFileSync('open', [review.bundle]);
console.log(`Left: ${review.left}\nRight: ${review.right}`);
JS
```

Use Command-L for the printed directories. Left contains `existing.txt`; Right starts empty. Use only these disposable directories for review.

- Compare New Text File/New Folder in File, Directory actions and blank-space menus. Shared actions target the focused pane; a background menu targets its own pane. Create both item types and check the selected result; repeat in One Pane mode.
- Edit `existing.txt`, then start creation. Cancel retains the draft; Save/Discard opens the captured name prompt. While a dirty decision, creation prompt or inline Rename is active, another creation request must be unavailable. Cancel and verify availability returns. Move/Trash confirmation and shared drag/Save reservations must also exclude creation; controlled tests cover short-lived Save and mutation phases.
- Switch windows and check that File commands follow the focused window. Verify creation shortcuts, Escape cancellation and focus recovery. Check VoiceOver's enabled/disabled menu states and keyboard access to all three entry points. Individual native/accessibility outcomes remain unreported; app-wide acceptance remains T18.
