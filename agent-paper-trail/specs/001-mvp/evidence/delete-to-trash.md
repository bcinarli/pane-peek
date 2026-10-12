---
task: delete-to-trash
verdict: Pending
closed: ""
---

# T12 Delete to Trash

## Unit 1, 2026-10-12

Bilal approved confirmed single-item Trash on 2026-10-12. Implemented on `feature/t12-delete-to-trash` from verified local/live `main` at `fe6517b`, containing T11 PR #25 closing head `09c5c16` and both feature commits. Bilal accepted the presented Unit 1 result and authorised its local commit on 2026-10-12. Individual native/accessibility outcomes were not separately reported; task completion and publication remain pending; batch Trash is disabled until separately reviewed Unit 2. Cross-window coordination remains T16.

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

Bilal authorised the Unit 1 local commit on 2026-10-12. Push and PR creation remain gated because Unit 2 is still outstanding. No push or PR has occurred.
