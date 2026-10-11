> Historical detail and fixtures. Current verdict: [M1 selection interaction validation](../specs/001-mvp/evidence/m1-selection-interaction.md). Earlier publication/checkpoint statements below are historical.

Status: Archived

# M1 selection interaction validation

Status: accepted. Bilal confirmed all manual checks passed and authorised the C2/F1 commit on 2026-10-09. Implementation and agent checks are complete. The unit belongs to `bcinarli/m1-quality-remediation` alongside C1/F2.

## Change

The list's existing keyboard endpoint and removed-row position calculations now live in two stateless `SelectionInteraction` functions in the core. The view calls these functions while retaining its interacted URL, native gestures and deferred selection report with the directory-change guard. `DirectoryPane` still owns selected URLs and the primary item.

Three regressions cover arrow reversal/clamping and primary fallback, removal at first/middle/last positions followed by another range step, and the [previous hidden-primary failure](t04-multiple-selection-primary-item.md#executed-checks). The last test verifies Details can follow an endpoint even when the selected set stays unchanged. This closes an automated coverage gap in app-owned calculations; it does not claim a newly discovered product defect or automate native selection mechanics.

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4, SDK 27.0, Node 26.1.0. Minimum macOS 26 runtime remains untested.

- Red: `node scripts/test.mjs --filter SelectionTests` compiled with minimal function declarations, then failed with 18 intended expectation/requirement failures in the three new tests. The two existing selection tests passed.
- Green: after moving the calculations and wiring both view callers, `node scripts/test.mjs` passes all 32 tests in five suites. Existing navigation, sorting, visibility, selection and copied-path coverage stays green.
- Build/package and `Info.plist` lint pass; built and bundled executable hashes match. The bundle launches after preserving the previous generated executable through the [documented recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery). Known non-fatal CLT search-path warnings remain. Tests/build used normal compiler-cache access through escalation.
- Source/caller and whitespace checks confirm the view uses both tested functions and retains its native/deferred dispatch and navigation guard.
- The documented fixture recipe executes successfully; local documentation links and anchors pass.

Native checks in disposable directories:

- Shift-Down from `file2.txt` follows `file3.txt`; repeated Shift-Up shrinks to `file2.txt`, then reverses to `file1.txt`. Shift-click follows its endpoint. Command-click deselecting the primary falls back to the first remaining selected row.
- Name descending, select `.hidden.txt`, Select All, then hide: the fallback primary is `file4.txt`. Subsequent Shift-Up steps correctly report `file2.txt`, then `file3.txt`.
- Name ascending, select `file2.txt`, Select All, move it outside the fixture listing and Refresh: surviving rows stay selected, primary falls back to `file1.txt`. Shift-Down reports `file4.txt` while the selected set stays unchanged. Restoring and refreshing the file does not reselect it.
- The right pane retains selected `right2.txt` and its independent Name order. Escape clears only the left selection and Details.

Accessibility smoke confirms meaningful pane/row names and selected states, the visible focus cue, keyboard range/Select All/Escape/Refresh operation, and the correct full primary path in Details. No fresh VoiceOver, contrast measurement or text-enlargement result is claimed; app-wide validation remains T18. Initial Home loading remained pending; both explicit fixture navigations succeeded.

Standard tighten kept two pure calculations, following the existing stateless helper style, with no selection controller or new state owner. Removed-row test expectations use explicit examples rather than reproducing the calculation. Standard probe checked empty/stale inputs, unchanged-row sorting, removed-row clamping, primary fallback and native event ordering. No further C2 blocker was found.

## Manual review

At handoff, the rebuilt app was running with restored disposable files. Both panes use Name ascending and hide hidden files. Left selects `file2.txt` and `file3.txt`, with `file2.txt` primary; right selects `right2.txt`.

- [x] Check Shift-click, Command-click and Shift-Up/Down extension/shrinking/reversal; Details follows the endpoint or fallback, and the other pane retains selection.
- [x] Sort left Name descending, show hidden files, select `.hidden.txt`, Select All, then hide. Shift-Up should follow `file2.txt`, then `file3.txt`.
- [x] Restore Name ascending, select `file2.txt` and Select All. Move fixture `file2.txt` to its fixture parent, Refresh and press Shift-Down; Details should follow `file4.txt`. Restore the file and Refresh without automatically reselecting it.

Use the [build/run instructions](../../README.md#build-and-run) to relaunch. The private journal records the current temporary paths. For a fresh fixture, run this and open the printed paths with Command-L:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-selection-review-'));
for (const side of ['left', 'right']) { await mkdir(join(root, side)); }
for (const name of ['file1.txt', 'file2.txt', 'file3.txt', 'file4.txt', '.hidden.txt']) {
  await writeFile(join(root, 'left', name), 'Disposable selection review.\n');
}
for (const name of ['right2.txt', 'right10.txt']) {
  await writeFile(join(root, 'right', name), 'Disposable independent pane.\n');
}
console.log(join(root, 'left'), join(root, 'right'));
JS
```
