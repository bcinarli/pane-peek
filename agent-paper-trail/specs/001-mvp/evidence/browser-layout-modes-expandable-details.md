---
task: browser-layout-modes-expandable-details
verdict: Passed
closed: 2026-10-11
---

# T19 evidence

## Unit 1: Details sizing

- 2026-10-11: Bilal explicitly approved Unit 1. Reviewed the accepted [compact light / expanded dark references and editable source](../../../design/001-mvp/README.md#layout-revision-2026-10-11). Implemented whole-column native sizing, header/View Expand/Restore and keyboard adjustments while retaining the existing hosts and preview height. T07's merged `468afc1` was verified on refreshed `origin/main`; branch starts at `8b17cee`.
- Agent checks: five sizing tests observed red (13 issues), then green; native regression checks exposed and corrected stale keyboard geometry, browser-divider cancellation of expansion and TextKit scroll movement during narrowing. `node scripts/test.mjs` passed 248 tests across 30 suites, including eight new sizing/split tests. Four known issues are intentional timeout-diagnostic cases. Standard tighten followed by standard probe completed; [native sizing notes](../../../notes/0007-native-details-sizing.md) retain the relevant gotchas.
- Agent-observed app: header expansion, View-menu Restore, both keyboard directions, Edit without expansion, dirty buffer through sizing without a prompt, and Undo returning to the original text passed. Long Unicode path/metadata stayed visible; AX exposed header action/state and native View actions. Bilal accepted the corrected Unit 1 below. Unit 2 was unapproved at this checkpoint; no publication occurred.

Environment: macOS 27.0.1 (26A434), Apple Swift 6.4, selected Command Line Tools; Xcode 27.0 asset compiler used by the bundler. Debug build/package passed and the local bundle launched. Existing deprecated-string/linker search-path warnings remain. Final bundle: `.build/PanePeek.app`, following [build/run instructions](../../../../README.md#build-and-run).

Coverage is partial A35 for the current dual-browser layout, with A11/A12/A32 regression checks. Mode changes (A34/remaining A35), independent windows and restoration remain later units/tasks. Agent checks are not Bilal's manual acceptance or publication.

### Manual correction: repeated Expand/Restore

- 2026-10-11: Bilal's recording showed the browsers receiving different widths on repeated button resizing. Unit 1 was unaccepted at this feedback checkpoint. Reviewed the supplied video locally; native regression reproduced the issue with 11 failed expectations.
- Retained the browser proportion using a native constraint below the Details width preference, updated only by user dragging of the browser divider. Equal and custom splits now survive repeated expansion/restoration and narrow/wide clamping. The native regression passed, followed by all 249 tests across 30 suites (the same four intentional known diagnostic issues). Light tighten followed by standard probe retained native ownership and checked minimums, custom dragging and editor regressions.
- Corrected debug build/package/launch passed. In the running app with `01-layout.swift`, the agent clicked the header ten times: all five expanded states showed 449/449-point browser widths and all five restored states showed 749/749. This closed the agent's repeated-button reproduction before Bilal's review.
- 2026-10-11: Bilal reported “all checks passed” after the corrected build was presented. Unit 1 manual review: Passed, including the affected accessibility checklist below. This is reviewer-reported acceptance; individual settings, sizes and VoiceOver observations were not separately supplied. Unit 2 and commit/push were not approved at this checkpoint.

## Unit 2: Browser modes and visible targets

- 2026-10-11: Bilal explicitly approved continuing Unit 2. Reviewed the accepted single-pane reference and editable toolbar/layout source. Added One Pane / Two Panes in the shared toolbar and View menu, retained browser identities and presentation order, hidden-target rejection, mode-dependent Details bounds and retained hidden list/breadcrumb scroll. Continued the verified T19 branch with accepted Unit 1 intact.
- Red/green: four core behaviour tests (including both starting identities) observed 26 failed expectations before implementation, then passed. Native mode/order/bounds and single-divider capture checks observed red, then green. A real SwiftUI List test exposed a post-reattachment scroll shift from 400 to 428 points; restoration after the layout transaction passed. Test compilation/setup errors were corrected and do not count as behavioural red. Standard tighten retained the existing hosts and window-local state; standard probe checked both mode directions, hidden targets, native scroll/focus/undo and width recovery.
- Required checks: `node scripts/test.mjs` passed 255 tests across 31 suites (14 app, 241 core), with the same four intentional timeout-diagnostic known issues. `node scripts/build-app.mjs` passed; the final bundle launched. Existing deprecated-string/linker warnings remain. `git diff --check` passed. No commit, push or PR.
- Agent-observed app: independent A/B fixture directories; the active right browser became single and returned on the left, with A restored on the right at its retained scroll position. Four complete toolbar cycles retained the dirty B draft without a prompt, consistent browser widths and native editor focus; Undo restored the original text. View-menu One Pane, shared hidden-file targeting while editing, expanded Details across mode changes and switching with A active passed. Hidden browser controls were absent from AX; radio controls exposed selected mode and accessible browser names followed displayed sides. Disposable edits were undone, both disk files retained their original bytes, and the app was left dual/compact with clean B selected.
- 2026-10-11: Bilal reported “all passed” after Unit 2 was presented. Unit 2 manual review: Passed, including all four affected manual/accessibility groups below. This is reviewer-reported acceptance; individual settings, sizes and VoiceOver observations were not separately supplied. Both approved units satisfy the T19 exit gate. Task acceptance is closed; no commit, push, PR or merge has occurred.

Coverage adds the current-window A34 mode/state/target contract and A35 bounds in both modes, with A1/A17 and A11/A12/A32 regressions. `transferDestination` rejects a new other-pane destination in single mode; real transfer menu/operation handlers and submitted snapshots remain T10/T11/T13. Independent windows and restoration remain T16/T17, so full A34/A35 verdicts stay Pending. T19 is Completed/Passed. Bilal confirmed the existing post-T07 quality review satisfies the [M2 checkpoint](../tasks.md#m2-quality-remediation); no additional analysis is claimed.

## Publication

- 2026-10-11: Bilal approved committing T19 and creating its PR. Both implementation units are complete; this authorises the feature-branch push needed for the requested PR. Feature commit [1683169](https://github.com/bcinarli/pane-peek/commit/168316911a7363ef3d14e984257df48d749d9222) was pushed, and [PR #18](https://github.com/bcinarli/pane-peek/pull/18) was created targeting `main` and attached to the working chat. Merge remains a separate gate. Only publication records changed after the accepted implementation; no build/test rerun was needed.

### Unit 2 fixture and review

Create a fresh two-directory fixture from the repository root, then launch the built app:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
const root = await mkdtemp('.build/t19-unit2-review-');
for (const name of ['A preserved browser café', 'B active browser café']) {
  const directory = join(root, name);
  await mkdir(directory);
  const text = '// Browser layout review\n' + Array.from({ length: 100 }, (_, i) =>
    `let sample${i} = "Line ${i}: long readable text for selection, scrolling and width checks"\n`).join('');
  await writeFile(join(directory, '01-layout.swift'), text);
  for (let i = 2; i <= 100; i++) {
    await writeFile(join(directory, `${String(i).padStart(3, '0')}-sample.txt`), `Fixture ${i}\n`);
  }
  await writeFile(join(directory, '.hidden.txt'), 'Hidden fixture\n');
}
console.log(resolve(root));
JS
open .build/PanePeek.app
```

Use Command-L to open A in one browser. Focus the other through its list/sort control, then open B with Command-L. Set different sort/hidden settings, select items and scroll each listing. Use `01-layout.swift` for disposable editor checks; undo/discard changes before leaving. Keep the fixture until cleanup is authorised.

All groups below are Passed based on Bilal's 2026-10-11 report. Agent-observed checks are recorded separately above.

- [x] Starting with either browser active, including with editor/toolbar focus elsewhere, switch One/Two Panes repeatedly. The visible browser stays left on return; hidden directory, selection/primary item, sorting, hidden visibility and scroll return unchanged.
- [x] Make a dirty edit, position caret/selection and scroll away. Switch modes, resize, Expand/Restore and use Details keyboard adjustments. Verify exact buffer, caret/selection, scroll, Undo and no layout-only dirty prompt. Recheck minimum/maximum physical dragging at narrow/wide/fullscreen sizes; metadata/path/copy remain usable and preview height stays unchanged.
- [x] Check toolbar/View parity, shared Go to Folder, favourites, Refresh, hidden visibility and path copying target the visible browser. Hidden controls cannot receive focus or commands.
- [x] Check keyboard traversal/focus and no traps, VoiceOver mode/role/state and visible-only structure, pointer targets/drag alternatives, light/dark contrast, text enlargement/long paths, increased contrast and reduced motion.

## Disposable fixture and run

From the repository root, create a new fixture without touching existing files:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
const root = await mkdtemp('.build/t19-review-');
const folder = join(root, 'A long directory name with spaces and Unicode café', 'Nested metadata and path review');
await mkdir(folder, { recursive: true });
const text = '// PanePeek Details sizing review\n' + Array.from({ length: 100 }, (_, i) =>
  `let sample${i} = "Line ${i}: long readable text for width, selection and scroll checks"\n`).join('');
await writeFile(join(folder, '01-layout.swift'), text);
await writeFile(join(folder, '02-other.txt'), 'Other selection for review\n');
console.log(resolve(folder));
JS
open .build/PanePeek.app
```

Use Command-L with the printed directory, then select `01-layout.swift`. Quit before rebuilding. Changes to this fixture may be undone/discarded; retain it until cleanup is authorised.

## Unit 1 manual and accessibility review

All groups below are Passed based on Bilal's 2026-10-11 report. Agent-observed checks are recorded separately above.

- [x] Repeat Expand/Restore at least five times with equal browsers, then with a custom browser-divider position. Their proportions should stay consistent, subject to minimum widths. Drag Details continuously to its minimum/maximum, including at a narrow window and fullscreen. Resize narrow/wide and verify both preferences recover. Expand then Restore should return to the Details preference before temporary clamping; dragging the browser divider should leave expansion intact.
- [x] Compare header and View actions. Use Control-Command-Left/Right to widen/narrow from the visible width, including when clamped. Entering Edit must keep the chosen width; preview height stays unchanged.
- [x] In Edit, change text, position the caret/select a range and scroll away from it. Drag, expand/restore and resize. Verify exact buffer/selection/caret, retained scroll/Undo and no layout-only dirty prompt; metadata and full path/copy stay accessible.
- [x] Check keyboard focus/access and absence of traps, VoiceOver action/state reading, usable pointer targets and the menu alternative to dragging. Check light/dark contrast, enlarged text and long paths at narrow widths, increased contrast and reduced motion.

Both units are accepted. The publication record above owns commit/push/PR state; merge remains separately gated and full app-wide accessibility acceptance remains T18. The closure date above records task acceptance, not publication.
