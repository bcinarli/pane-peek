---
task: delete-to-trash
verdict: Passed
closed: "2026-10-13"
---

# T12 Delete to Trash

## Unit 1, 2026-10-12

Bilal approved confirmed single-item Trash on 2026-10-12. Implemented on `feature/t12-delete-to-trash` from verified local/live `main` at `fe6517b`, containing T11 PR #25 closing head `09c5c16` and both feature commits. Bilal accepted the presented Unit 1 result and authorised its local commit on 2026-10-12. Individual native/accessibility outcomes were not separately reported; at Unit 1 delivery, batch Trash was disabled until separately reviewed Unit 2. Cross-window coordination remains T16.

- Agent-observed red/green: `node scripts/test.mjs --filter ItemTrashTests` first failed on contents/link transfer and source-specific errors, then passed. `--filter BrowserTrashTests` first failed on the absent action, guards and recovery, then passed. A reproduced stale-file-to-folder case failed under `--filter aStaleListedFileCannotBecomeATrashFolder` before the type guard and passed afterwards. `--filter failedNewerNavigationRetainsAnAccessibleTrashFallback` reproduced an unusable fallback when newer navigation failed and the trashed folder’s parent was inaccessible; it passed after recovery preserved the pending request while loading a usable fallback. Import/compiler setup failures were excluded from red evidence.
- Final `node scripts/test.mjs`: 366 core tests plus 25 native tests passed (391 total). Four known issues are the existing intentional listing/sort timeout-diagnostic cases. Coverage includes confirmation and dirty cancellation, saved identity replacement, deferred Discard on failure, failed-Save abort, duplicate/conflicting requests, hidden/stale/multiple-selection rejection, matching-pane refresh, retained unrelated drafts, ancestor recovery and affected/unrelated pending reads.
- `node scripts/build-app.mjs` built successfully. The documented generated-executable recovery resolved the initial launch failure. Production `ItemTrash.trash()` also passed a disposable system Trash/restore harness for a file, folder, package, file link, broken link and directory link, verifying contents/link text and preserving targets. Every harness item was restored; no Trash was emptied. macOS 27.0.1 (26A434), Swift 6.4, Node 26.1.0. A fresh final review bundle uses the same bundler with only its generated destination, bundle name and identifier changed, avoiding replacement of a running app. Its launch result is recorded below.

Tighten reused the move confirmation's selectable source-list control and existing mutation/dirty/selection behaviour. Probe added stale-type rejection, failure-after-removal reporting and recovery checks, including a failed newer navigation retaining an accessible fallback. No new product decision was needed. [Trash notes](../../../notes/0012-item-trash.md) own the durable implementation limits.

## Visible result and acceptance scope

Move to Trash… appears in row context menus and the File menu. Shift-F10 reaches the existing row menu; the row also exposes a Trash accessibility action. Confirmation shows one item and its selectable full path. It precedes the affected dirty prompt. Results persist in the shared operation status until dismissed. The action works in one/two-pane mode and rejects multiple selection in this unit.

A22 is verified for the automated/system single-item scope. Current-window portions of A9, A18 and A25, plus A33 refresh regressions, are exercised above. Full criteria remain Pending for batches, cross-window scope or individually unreported checks. Unit 1 does not complete T12 or the M3 milestone.

## Disposable fixture and run instructions

The current generated review app is `.build/t12-final-review/PanePeek.app`, named **PanePeek T12 Final Review**. To open this exact build:

```sh
open .build/t12-final-review/PanePeek.app
```

`open .build/t12-final-review/PanePeek.app` succeeded and the matching app process was verified. Touched Markdown file links, criterion table structure and `git diff --check` pass. These checks are agent-observed; native UI inspection at delivery was blocked by the locked Mac. The ordinary build recipe below reproduces the shipped source with the normal bundle identity.

Quit PanePeek before the normal build. From the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Generate a fresh fixture and use the printed path with Go to Folder (Command-L):

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { join } from 'node:path';
const root = await mkdtemp('/private/tmp/panepeek-t12-review-');
await mkdir(join(root, 'folder', 'nested'), { recursive: true });
await mkdir(join(root, 'sample.app', 'Contents'), { recursive: true });
for (const [name, text] of [
  ['file.txt', 'Disposable text\n'], ['dirty.txt', 'Edit before Trash\n'],
  ['target.txt', 'Keep this link target\n'], ['folder/nested/child.txt', 'Child\n'],
  ['sample.app/Contents/payload.txt', 'Package\n'],
]) { await writeFile(join(root, name), text); }
await symlink('target.txt', join(root, 'file-link'));
await symlink('folder', join(root, 'folder-link'));
await symlink('missing.txt', join(root, 'broken-link'));
console.log(root);
JS
```

Use only these disposable items. Inspect/restore them in Finder's Trash as needed; leave Trash emptying outside this review. Automated unavailable-Trash and failure paths use an isolated recycle seam, without changing the user's Trash configuration.

## Manual and accessibility review

- [ ] Confirm the item count/name/path; Cancel/Escape retains selection and files. Confirm Trash for each supported kind, inspect contents and verify link targets remain.
- [ ] Edit `dirty.txt`, then exercise Save/Discard/Cancel. Cancel retains the draft; successful deletion closes it. Multiple selection disables/rejects Trash.
- [ ] Put one pane inside `folder/nested` and select `folder` in the other. Confirm Trash; the descendant pane recovers to an accessible parent and explains the change. Repeat in single-pane mode with retained hidden-browser state.
- [ ] Reach the action through File and Shift-F10; check visible focus after both prompts and absence of traps. Check VoiceOver names, source path/count, controls and result/error announcements.
- [ ] Check light/dark appearance, contrast/non-colour cues, narrow windows and long paths. Record the enlargement mechanism/sizes and outcomes under increased contrast/reduced motion.

Native UI inspection at delivery was unavailable because the Mac was locked. Bilal accepted the presented Unit 1 result on 2026-10-12. The individual checklist observations/settings were not separately supplied, so the unchecked entries do not assert individual outcomes. No additional agent-observed confirmation/focus/VoiceOver/appearance or enlargement pass is claimed.

## Publication

Bilal accepted Unit 1 on 2026-10-12 and Unit 2 on 2026-10-13, authorising the Unit 2 commit and PR creation. Feature commits [bd9b236](https://github.com/bcinarli/pane-peek/commit/bd9b2369ba5a301960dddeb3546ac8ba9e87754e) and [f7ee6a5](https://github.com/bcinarli/pane-peek/commit/f7ee6a543151c282c68eb4125943636dcdd1975f) are pushed on `feature/t12-delete-to-trash` in closing [PR #26](https://github.com/bcinarli/pane-peek/pull/26), targeting `main`. No planned coding units remain. Bilal authorised PR #26 merge on 2026-10-13. The linked PR records its live merge result. T13 remains blocked until the full closing head is verified on `main`.


## Unit 2, 2026-10-13

Bilal authorised continuation to Unit 2 on 2026-10-12. Batch Trash is implemented on the existing task branch after local Unit 1 commit `bd9b236`. Bilal accepted the presented Unit 2 result on 2026-10-13 and authorised commit/PR publication. Both units are accepted; T12 is Completed/Passed. Individual native/accessibility observations were not separately reported.

- Agent-observed red/green: `node scripts/test.mjs --filter 'BatchTrashTests|BrowserBatchTrashTests'` failed with 41 behaviour issues before implementation, covering the absent batch action, execution order, whole-request rejection and partial results. The expanded Trash tests passed after implementation; compiler setup failures were excluded from red evidence.
- Final `node scripts/test.mjs`: 378 core tests plus 25 native tests passed (403 total). The four known issues remain the existing intentional listing/sort timeout diagnostics. Checks cover captured mixed selections, stale last-item rejection before the first write, stop-on-first-failure completed/failed/unattempted outcomes, confirmed successes versus disappeared sources, cancelled batch confirmation, dirty Save/Discard/Cancel before mutation, failed Save, union edit locks, in-flight navigation/selection/layout, failed Refresh retaining partial outcomes and drafts, and selected-folder dirty descendants.
- The production `ItemTrash.Batch.trash()` system Trash/restore harness passed one six-item batch (file, folder, package, file link, broken link and directory link), verifying captured-order outcomes, contents/link text and an untouched target. Every disposable item was restored; no Trash was emptied. The fresh batch review bundle built and `open` succeeded; its matching process was verified. macOS 27.0.1 (26A434), Swift 6.4, Node 26.1.0. Native UI inspection was unavailable because the Mac was locked.

Tighten reused the existing single-item identity validation, source-list confirmation and pane recovery. Probe verified late revalidation, per-item draft retention and recovery despite Refresh failure. Known conflicts reject the whole request before mutation; execution failures retain earlier successes. Cross-window coordination remains T16. This covers the batch portion of A22 and current-window A9/A18/A25, with A33 refresh regressions. Full criterion verdicts remain Pending where individual checks or later scope remain.

## Unit 2 disposable fixture

The current generated app is `.build/t12-batch-review/PanePeek.app`, named **PanePeek T12 Batch Review**. It uses the normal bundler with only the generated destination/name/identifier changed, preserving older running bundles. Open the exact build:

```sh
open .build/t12-batch-review/PanePeek.app
```

For a clean reproduction, quit PanePeek and use the normal build/run recipe above. Generate a fresh batch fixture and open its printed path with Command-L:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { join } from 'node:path';
const root = await mkdtemp('/private/tmp/panepeek-t12-batch-review-');
await mkdir(join(root, 'folder', 'nested'), { recursive: true });
await mkdir(join(root, 'sample.app', 'Contents'), { recursive: true });
for (const [name, text] of [
  ['a.txt', 'Disposable A\n'], ['b.txt', 'Disposable B\n'],
  ['c.txt', 'Edit this later item\n'], ['target.txt', 'Keep the link target\n'],
  ['folder/nested/child.txt', 'Child\n'], ['sample.app/Contents/payload.txt', 'Package\n'],
]) { await writeFile(join(root, name), text); }
await symlink('target.txt', join(root, 'file-link'));
await symlink('folder', join(root, 'folder-link'));
await symlink('missing.txt', join(root, 'broken-link'));
console.log(root);
JS
```

Unavailable Trash, partial failure and Refresh failure are covered by isolated test seams. To inspect those checks without changing Trash configuration:

```sh
node scripts/test.mjs --filter 'firstFailureReportsCompletedFailedAndUnattempted|failedRefreshKeepsPartialOutcomeAndUnattemptedDraft|discardOnlyClosesTheDraftWhoseSourceWasTrashed'
```

## Unit 2 manual/accessibility checklist

- [ ] Select a mixed batch, check every captured path and count, then Cancel/Escape. Confirm the batch in one/two-pane mode and inspect/restore the disposable items in Finder's Trash. Trash links alone to verify their targets survive.
- [ ] Select `a.txt`, `b.txt` and edited `c.txt`; exercise Save/Discard/Cancel. Repeat with an edited child inside selected `folder`. Cancel and failed Save must precede all Trash calls; successful removal closes only affected previews.
- [ ] Review the automated partial-failure checks above: earlier successes remain, failed/unattempted drafts remain editable, paths are reported honestly and Refresh errors preserve the operation outcome. No permanent-deletion fallback exists.
- [ ] Check row context/File/Shift-F10 access, count/path visibility and scrolling, prompt focus recovery and no traps. Check VoiceOver names, roles, source list and result/error announcements.
- [ ] Check narrow windows/long paths, text enlargement mechanism/sizes, light/dark contrast and relevant increased-contrast/reduced-motion settings.

Bilal accepted the presented Unit 2 result on 2026-10-13. Individual checklist observations/settings were not separately supplied; unchecked entries do not assert individual outcomes. No additional agent-observed native confirmation/focus/VoiceOver/appearance or enlargement pass is claimed.
