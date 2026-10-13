---
task: drag-and-drop-finder
verdict: Passed
closed: 2026-10-13
---

# T13 Drag and drop with Finder

## Unit 1: incoming local-file drops (2026-10-13)

Bilal approved Unit 1 on 2026-10-13. T12 PR #26 full closing head `134e517` was verified on local/live `main` at merge `78b6a48`; implementation uses `feature/t13-drag-and-drop-finder`. Bilal accepted Unit 1 overall on 2026-10-13 and authorised its commit followed by Unit 2 implementation. Individual native/accessibility outcomes were not separately reported. Publication approval was supplied after Unit 2 acceptance; merge remains separate.

- Red: `node scripts/test.mjs --filter 'FileDropTests|DropTransferTests'` compiled and failed on missing local-file decoding, copy/Command-move choice, incoming mutation/confirmation and affected dirty prompts against compilable stubs. Initial sandbox-cache and test setup errors were corrected before observing this behavioural red.
- Green: targeted drop and existing copy/move regressions passed (72 tests before the added probe coverage). Final `node scripts/test.mjs` passed 418 tests: 30 app and 388 core, with four expected known gate-timeout diagnostic issues. `node scripts/build-app.mjs` and `git diff --check` passed. The built bundle launched and its executable remained running; live UI observation was unavailable because the Mac was locked.
- Tighten then probe: reused the existing transfer execution/dirty/outcome flow, simplified URL validation and retained indexed move metadata. Added native table-callback validation for directory targeting/hidden rejection and destination metadata recovery for external packages/directory links/broken links when Refresh fails. Real Finder gesture, cursor, visual and accessibility results remain unexecuted.

Environment: macOS 27.0.1 (`26A434`), arm64, Apple Swift 6.4 and Node.js 26.1.0. Command Line Tools are selected; the bundler used installed Xcode for asset compilation. Existing compiler/linker warnings did not prevent the build or tests.

## Unit 2: outgoing selections and pane-to-pane drags (2026-10-13)

Bilal accepted Unit 1 and authorised its commit and Unit 2 implementation on 2026-10-13. Unit 1 is committed as `f92a12d`. Bilal accepted Unit 2 overall on 2026-10-13 and authorised its commit and PR publication. Individual native/accessibility outcomes were not separately reported.

- Red: `node scripts/test.mjs --filter OutgoingDragTests` compiled and failed on absent source capture/locks, dirty resolution and local handoff (6 test declarations, 48 issues). `node scripts/test.mjs --filter FileDropTests` then failed on native initiation and dirty-source guarding (2 issues) before the writer callbacks were connected. A later probe observed repeated native preparation after sorting reverse the exported order; the regression failed, then passed after mapping writers to the original captured sequence.
- Green: targeted source/drop/editor/transfer checks passed; final `node scripts/test.mjs` passed 426 tests (32 app, 394 core) with four expected existing gate-timeout diagnostic issues. Final `swift build --product PanePeek`, asset compilation, review-bundle plist/executable-integrity checks, launch/process checks and `git diff --check` passed. The standard bundle was left unchanged while its Unit 1 process remained running; a separate review bundle with isolated preferences was launched.
- Tighten then probe: reuse the existing Save/Discard/Cancel path and transfer destination flow; share an immutable source selection between capture and preview locks. Validate whole native row sets, retain row URLs through reordering, reject writers outside the captured set and release aborted preparations. Include package descendants without traversing listed symlink targets; disable creation menus during a source drag. Live gestures/cursors and accessibility outcomes remain unexecuted by the agent.

Clean selected rows export local file URL writers in captured displayed order. Dirty selected files or descendants of selected folders/packages prompt before a writer is exported. Cancel and failed Save export nothing and retain the draft. Successful Save/Discard requires a fresh drag gesture; a visible status explains the retry. Native source callbacks are synchronous, so the implementation does not resume an old mouse event after a sheet.

Source locks prevent edits to affected documents and conflicting current-window context mutations during the native drag. Unrelated drafts stay editable. A local receiving pane can still accept the captured drag and runs Unit 1's guarded copy/Command-move flow. Outgoing Finder/other-app results remain externally controlled: the source callback never deletes/copies an item or declares filesystem success. After handoff, use Refresh to reconcile external changes.

Automated coverage includes displayed selection order, listed-link identity, stale/hidden/partial-set rejection, source edit/mutation locks and cleanup, file/folder/package dirty choices, failed Save, unrelated link-target drafts, local copy/move handoff and native URL writers surviving reordering. Native adapter tests exercise controlled callback paths and real pasteboards, not live Finder dragging or OS event ordering.

Acceptance mapping: within-window/Finder A21 and drag-batch A20, with current-window A8/A9 and A34 guards. Cross-window A8/A9/A21 remains T16. Both planned T13 units are implemented and accepted overall. The M3 quality checkpoint remains outstanding; no quality analysis or remediation is claimed. Commit and PR publication are authorised; merge remains separate.

## Recorded scope and limits

Incoming file URL selections target the receiving visible browser's current directory, including single-pane mode and empty lists. Dropping over a folder row does not redirect the request into that folder. The native table callback is exercised with a real pasteboard and a controlled dragging-info object; this is not a live Finder gesture.

Default copy requires source copy permission. Command chooses move only when permitted; a copy-only source still advertises copy, and an unsupported source operation is rejected. This uses [AppKit's source operation mask](https://developer.apple.com/documentation/appkit/nsdragginginfo/draggingsourceoperationmask). Empty, mixed unsupported, duplicate, service and non-local file URL payloads are rejected as a whole. Promised files are not received.

The submission reserves the operation and snapshots ordered source URLs/destination before queued work. Copy/move reuse whole-request preflight, identity/ancestry/collision checks, move confirmation, current-window dirty Save/Discard/Cancel, background execution, structured partial outcomes and matching-pane recovery. The drop callback accepts a queued request; application status reports filesystem success only after execution. Cancel or failed Save can still abort that accepted request without mutation.

Automated coverage includes single mode from either browser, hidden/invalid/duplicate submission rejection, immediate destination capture across navigation, move confirmation/cancellation, whole-batch collision rejection, partial copy reporting, affected source dirty choices/failed Save, moved-folder browsing recovery and destination classification through failed Refresh. Existing copy/move regressions cover their unchanged filesystem safeguards.

Acceptance mapping for Unit 1: incoming portion of A21 and drag-batch A20; current-window A5–A9 and A34 safeguards. Full criteria remain Pending. Unit 2 adds the outgoing source described above. Cross-window coordination stays in T16. The M3 quality checkpoint follows T13's manual review gates.

## Disposable fixture and run instructions

From the repository root, quit PanePeek before rebuilding:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Create a fresh fixture for each destructive review pass. This prints its root path; use it in Finder and PanePeek's Go to Folder (Command-L).

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-t13-review-'));
for (const name of ['copy-source', 'move-source']) {
  const source = join(root, name);
  await mkdir(join(source, 'folder', 'nested'), { recursive: true });
  await mkdir(join(source, 'Sample.app', 'Contents'), { recursive: true });
  await writeFile(join(source, 'space ü.txt'), 'Original review text\n');
  await writeFile(join(source, 'folder', 'nested', 'child.txt'), 'Nested review text\n');
  await writeFile(join(source, 'Sample.app', 'Contents', 'fixture.txt'), 'Disposable package fixture\n');
  await symlink('space ü.txt', join(source, 'file-link'));
  await symlink('folder', join(source, 'directory-link'));
  await symlink('missing-target', join(source, 'broken-link'));
}
for (const name of ['destination', 'single-destination', 'collision-destination', 'other', 'finder-destination']) {
  await mkdir(join(root, name));
}
await writeFile(join(root, 'collision-destination', 'space ü.txt'), 'Existing destination must survive\n');
console.log(root);
JS
```

Open `copy-source` in Finder. In PanePeek, navigate a browser to `destination`; use `single-destination` for a fresh single-mode check. Use `move-source` for move checks. Do not remove working files or empty Trash for this review.

## Unit 1 individual checks (outcomes unreported)

- [ ] Drag a file, nested folder, package, listed links and a multiple-item selection from Finder into each visible browser. Default copy retains sources and link targets. Verify empty-list and folder-row drops use the receiving directory.
- [ ] Repeat with Command into a fresh destination. Inspect the intended cursor/operation, captured source count/list and destination in confirmation. Cancel first, then confirm a move; verify source removal and destination contents only on success.
- [ ] Drop a conflicting batch into `collision-destination`: no source/destination changes. Attempt plain text or a service URL: reject the whole unsupported payload. Review actionable errors and completed/failed/unattempted status for an available failure fixture.
- [ ] Repeat in One Pane. During a prompt or sufficiently large transfer, navigate the receiver or switch layout; the captured destination stays fixed and later navigation is retained.
- [ ] In PanePeek, preview/edit a source file (or a child of a dragged folder) while Finder supplies the drag. Exercise Save/Discard/Cancel and a failed Save; cancellation/failure retains edits and changes no selected source. Check preview/browser recovery after moving the source folder.
- [ ] Check keyboard/context alternatives by browsing the source in the other pane and using Copy/Move to Other Pane (Shift-F10 opens its menu). Check focus and no traps, VoiceOver table help/roles and status announcements, readable long paths/confirmation lists and supported text enlargement.
- [ ] Inspect drag feedback and errors in light/dark, narrow layouts, increased contrast and reduced motion. Record actual settings and sizes rather than assuming native defaults establish compliance.

## Unit 2 individual checks (outcomes unreported)

Use the running **PanePeek T13 Review** app for the isolated review build. The earlier app windows were preserved; their existing bundle/preferences were not replaced. A normal build after quitting PanePeek uses the standard commands above. Review-bundle and current fixture paths are provided with the handoff, rather than stored as machine-specific paths here.

Create a fresh fixture with the recipe above. Navigate the review app's source browser to `copy-source`, and the receiving browser to `destination`. Open `finder-destination` in Finder. Use `move-source` and fresh empty destinations for move checks.

- [ ] Drag one item and a mixed selection between panes in either direction. Verify default copy and Command-move, source/destination confirmation and cancellation, collisions, listed links/packages and accurate outcomes. Try dropping over a folder row; the receiving directory remains the target.
- [ ] Drag selected file URLs from PanePeek to Finder, including from One Pane. Check Finder's chosen operation and its own failure/collision behaviour. Refresh PanePeek after an external move and confirm listings/preview recover; PanePeek must not independently remove a source or claim the external operation succeeded.
- [ ] Dirty a selected text file or a child of a selected folder/package before dragging. The first gesture prompts without exporting a URL. Exercise Save/Discard, then retry the gesture; Cancel and failed Save retain edits and start no drag.
- [ ] Cancel a clean native drag and check that the source editor, creation/rename/Trash/context actions and selection recover. Check that dragging a listed link leaves an unrelated dirty target draft intact. Sort/navigate or change layout during a controllable drag and confirm that the exported URLs remain captured.
- [ ] Verify native selection/primary behaviour, pointer feedback, focus and text/undo retention, VoiceOver help/status announcements, keyboard/context transfer alternatives, readable long paths and confirmation lists, enlarged text, light/dark/increased-contrast and reduced motion. Record actual settings/sizes. Context Copy/Move to Other Pane can target a directory shown in Finder without requiring a drag.

## Review and publication

Agent-observed automated/build/process checks are recorded above. Bilal accepted both presented units overall on 2026-10-13 and authorised Unit 2 commit and PR publication. T13 is Completed/Passed for that accepted scope. Individual native/Finder/accessibility outcomes remain unreported; the unchecked lists retain those evidence gaps. No agent-observed Finder gesture is claimed. Published on 2026-10-13 in [PR #27](https://github.com/bcinarli/pane-peek/pull/27), targeting `main`, with [Unit 1 commit `f92a12d`](https://github.com/bcinarli/pane-peek/commit/f92a12d739a3c30afc85d3812f50b6f9180470ee) and [Unit 2 commit `ebfba94`](https://github.com/bcinarli/pane-peek/commit/ebfba947248e5aa818c1e17da8d111382ff23f43). Live `main` remained `78b6a48` at publication. The PR is open; merge is not authorised. Full cross-window criteria remain T16, and the M3 quality checkpoint remains outstanding.
