# T14 context actions and copied paths validation

Status: Bilal approved and accepted Unit 1 on 2026-10-08, including its placement before T15/T05, and authorised the test-quality cleanup below. Implementation `dd98d1f` is published in [PR #7](https://github.com/bcinarli/pane-peek/pull/7), targeting `main`. Bilal authorised the merge on 2026-10-08; the PR records the outcome.

## Approved scope

Single-window context targeting, absolute/relative selection copies, focused shared directory copy and the full primary selected path with a small copy control in Details. Reuse pane-owned selection and one plain path format across these controls. [A17/A18](../specs/001-mvp/spec.md#favourites-and-context-menus) and [A33](../specs/001-mvp/spec.md#sidebar-details-and-preview-mode) stay partial for later dirty guards, operation handlers and metadata. No file mutations, preview/editor, favourites or Details-width change is included.

## Executed checks

Environment: macOS 27.0.1 (`26A434`), Swift 6.4, SDK 27.0, Node 26.1.0. The bundle targets macOS 26.0; no macOS 26 runtime or CI result is claimed.

| Check | Result |
| --- | --- |
| Dependency/branch | T04 PR #6 verified merged; local/live `main` at `dbdbc59` contains `2e06bd4`. Created `bcinarli/t14-context-actions-copied-paths` from clean, current `main` after Unit 1 approval. |
| Initial intentional red | `node scripts/test.mjs --filter PathCopyTests` with compiling minimal declarations: 13 intended expectation failures across two scenarios. An earlier compiler-cache access failure is excluded from behavioural red. |
| Green | Final `node scripts/test.mjs`, rerun after the approved cleanup: 27 tests in four suites pass. The two new scenarios cover context focus/primary/selection/pane isolation, obsolete-row rejection and actual temporary listing path bases/order/Unicode/spaces/file and folder links. |
| Build/launch | Final `node scripts/build-app.mjs`, fresh native launch and `plutil -lint .build/PanePeek.app/Contents/Info.plist` pass. Known CLT linker search-path warnings are non-fatal. |
| Agent native targeting | Context-clicking an unselected row in the other pane updates its selection, focus cue and Details before the menu opens. The other selection survives. Context-clicking within Select All preserves the set and updates primary. After dismissing the menu, Command-A affects that listing. |
| Agent clipboard | Actual TextEdit pastes: single relative context path, multiple absolute context paths in ascending displayed order, multiple relative paths via Command-Option-Shift-C in descending displayed order. Plain spaces/Unicode and file/folder link names are preserved. |
| Agent directory/Details | Toolbar directory copy follows a pane switch with empty selection; Go menu copy works in an empty directory. Details copies complete single and long Unicode absolute paths. Dark appearance shows a wrapped full path. Clearing selection hides the path/control and disables item-copy commands. |
| Agent native regression | Ordinary click collapses selection; blank-area right-click offers no item actions. Return opens a sole selected directory. |
| Tighten then probe | Removed an unused explicit-selection input and reused core selection/formatter/clipboard ownership. Probe exposed menu-open timing and native keyboard-focus failures; the final native seam passes those checks. No remaining Unit 1 code blocker found. |
| Approved test cleanup | Removed the reconstructed shared-directory caller assertion and its unused focus call, plus redundant directory/root formatter assertions. Both behaviour scenarios and the singleton link-format check remain. Tighten then probe confirms required coverage is retained; shared-action targeting has native clipboard evidence. Production code and the reviewed app are unchanged. |
| Documentation/package | All 82 local links/anchors in changed documentation, the fixture's Node syntax, `git diff --check` and final bundle plist lint pass. |

The agent's Details-divider drag did not change the width, and Bilal did not individually report a narrower layout. The [existing width proposal](../notes/0005-details-width-follow-up.md) remains separately gated.

## Run and disposable fixture

Quit PanePeek before rebuilding. Follow the [generated-executable recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery) when needed, then from the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Create a disposable fixture:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-path-review-'));
const left = join(root, 'left ü with spaces');
const right = join(root, 'right');
const targets = join(root, 'targets');
for (const path of [left, right, targets, join(root, 'empty')]) {
  await mkdir(path);
}
await mkdir(join(left, 'folder2'));
await mkdir(join(left, 'Sample.app'));
for (const name of ['item2 ü % #.txt', 'item10 with space.txt', '.hidden.txt',
                    'Long Unicode ü name with spaces and enough length to wrap in Details.txt']) {
  await writeFile(join(left, name), 'Disposable path fixture\n');
}
await writeFile(join(right, 'right only.txt'), 'Right pane fixture\n');
await writeFile(join(targets, 'target.txt'), 'Link target\n');
await symlink(join(targets, 'target.txt'), join(left, 'file link.txt'));
await symlink(targets, join(left, 'folder link'));
console.log(`Left: ${left}\nRight: ${right}\nEmpty: ${join(root, 'empty')}`);
JS
```

Enter Left with Command-L, then focus the other pane and enter Right. Keep `right only.txt` selected while testing the left. Retain the fixture until cleanup is authorised.

## Bilal's manual review (2026-10-08)

Bilal reported OK for all five presented checks:

- [x] Right-click and Control-click outside/inside a multi-selection.
- [x] Paste single/multiple paths in both sort directions, including links and Unicode.
- [x] Switch panes and copy the directory with no selection.
- [x] Copy Details paths for files, folders, packages and links; inspect long paths and light/dark layouts.
- [x] Confirm selection gestures, keyboard ranges and directory opening still work.

Unit 1 implementation/manual acceptance is complete. Later coding units and source-control actions retain separate approval gates. M1 still requires T15; no milestone quality checkpoint is claimed.
