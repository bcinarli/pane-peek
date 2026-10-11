> Historical detail and fixtures. The current task verdict is in [T04 evidence](../specs/001-mvp/evidence/multiple-selection-primary-item.md); current criterion status is in [MVP validation](../specs/001-mvp/validation.md). Earlier checkpoint statements below are historical.

Status: Archived

# T04 multiple selection and primary item validation

Status: Bilal accepted Unit 1 and authorised its commit/publication and merge on 2026-10-07. [PR #6](https://github.com/bcinarli/pane-peek/pull/6) merged as `dbdbc59`; live PR state and implementation commit `2e06bd4` ancestry on `main` were verified before T14. Later coding units require their own approval.

## Approved scope

Single-window selection and primary-name display in Details, following [A19](../specs/001-mvp/spec.md#multiple-selection-and-drag-and-drop), with A1/A3/A4/A30 regressions. A19 remains partial for T07 dirty guards and T16 windows; A31 remains partial for later preview/metadata/window work.

Context actions, copied paths, file operations, editor/preview content and Details width are outside this unit.

## Executed checks

Environment: macOS 27.0.1 (`26A434`), Swift 6.4, SDK 27.0, Node 26.1.0. The bundle targets macOS 26.0; no macOS 26 runtime or CI result is claimed.

| Check | Result |
| --- | --- |
| Dependency/branch | Created `bcinarli/t04-multiple-selection-primary-item` from clean `main` at verified T03 merge `77a745e`. |
| Intentional red | `node scripts/test.mjs` with compiling minimal declarations: 31 intended expectation failures across two new selection scenarios and assertions in two existing navigation scenarios; prior expectations stay green. `node scripts/test.mjs --filter SelectionTests` then exposed one primary-retention failure when Select All added the last unselected row. |
| Green | `node scripts/test.mjs`: 25 tests in three suites pass. Two new tests cover primary/focus/pane isolation and sorting/Refresh/hidden/deleted-row reconciliation. Existing failed/stale navigation tests cover selection retention. |
| Build/launch | `node scripts/build-app.mjs` and fresh-executable native launches pass. |
| Agent native selection/focus | Shift-Up/Down range extension, shrinking and reversal show the endpoint in Details. Command-A and Edit → Select All select visible rows, retaining the primary or choosing the first visible row from empty selection. Escape clears one pane/Details. Focus and sort changes retain both selections; Details follows focus. Command-A in Go to Folder selects path text. |
| Agent native reconciliation/navigation | Hiding the primary and Refresh after removing a selected fixture file prune unavailable rows while retaining surviving selections. Reveal/restore does not reselect them. Failed navigation retains selection/Details; successful navigation clears only its pane. Single-directory Return/double-click works. |
| Native regression probe | Hidden-primary/Select All/hide/Shift-Up initially retained a fallback primary. After correcting keyboard endpoint tracking, the final build reports `file1.txt`, then `file2.txt` on the next shrink. See the [state note](../notes/0003-listing-and-pane-state.md#selection-and-primary-item) for the durable gotcha. |
| Agent visual check | Long Unicode primary name wraps within Details in dark appearance. |
| Documentation/package | Local Markdown links/anchors, fixture Node syntax and `git diff --check` pass. `Info.plist` validates and declares macOS 26.0. |

## Run and disposable fixture

From the repository root, quit PanePeek before rebuilding. Preserve the generated executable using the [existing recovery instructions](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery), then:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Create the disposable fixture used for this review:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-selection-review-'));
for (const side of ['left', 'right', 'empty']) {
  await mkdir(join(root, side));
}
for (const side of ['left', 'right']) {
  await mkdir(join(root, side, 'folder2'));
  await mkdir(join(root, side, 'Sample.app'));
  await writeFile(join(root, side, 'folder2', 'inside.txt'), 'Inside folder\n');
  for (const name of ['file1.txt', 'file2.txt', 'file3.txt', 'file4.txt', 'file10.txt',
                      '.hidden.txt', 'Long Unicode ü name for primary selection.txt']) {
    await writeFile(join(root, side, name), 'Disposable selection fixture\n');
  }
  await symlink('file2.txt', join(root, side, 'file-link'));
}
console.log(`Left: ${join(root, 'left')}`);
console.log(`Right: ${join(root, 'right')}`);
console.log(`Empty: ${join(root, 'empty')}`);
JS
```

Use Command-L to enter the printed Left path. Focus the other pane, then enter Right. Select `file2.txt` in the right pane and leave it selected while reviewing the left. Use a disposable rename through Finder to make a selected fixture row disappear before Refresh; do not mutate working files. Retain fixtures until cleanup is authorised.

## Bilal's manual review (2026-10-07)

- [x] Command-click toggles selection. Deselecting the primary makes Details show the first remaining selected row in displayed order.
- [x] Shift-click selects ranges upward and downward; Details shows the clicked endpoint.
- [x] Select All/Escape and menu Select All work.
- [x] Panes are independent; Details/preview shows the primary file name.
- [x] Appearance and resizing work.
