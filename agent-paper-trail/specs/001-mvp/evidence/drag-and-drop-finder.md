---
task: drag-and-drop-finder
verdict: Pending
closed: ""
---

# T13 Drag and drop with Finder

## Unit 1: incoming local-file drops (2026-10-13)

Bilal approved Unit 1 on 2026-10-13. T12 PR #26 full closing head `134e517` was verified on local/live `main` at merge `78b6a48`; implementation uses `feature/t13-drag-and-drop-finder`. Bilal accepted Unit 1 overall on 2026-10-13 and authorised its commit followed by Unit 2 implementation. Individual native/accessibility outcomes were not separately reported. Push and merge remain unauthorised; publication is not started.

- Red: `node scripts/test.mjs --filter 'FileDropTests|DropTransferTests'` compiled and failed on missing local-file decoding, copy/Command-move choice, incoming mutation/confirmation and affected dirty prompts against compilable stubs. Initial sandbox-cache and test setup errors were corrected before observing this behavioural red.
- Green: targeted drop and existing copy/move regressions passed (72 tests before the added probe coverage). Final `node scripts/test.mjs` passed 418 tests: 30 app and 388 core, with four expected known gate-timeout diagnostic issues. `node scripts/build-app.mjs` and `git diff --check` passed. The built bundle launched and its executable remained running; live UI observation was unavailable because the Mac was locked.
- Tighten then probe: reused the existing transfer execution/dirty/outcome flow, simplified URL validation and retained indexed move metadata. Added native table-callback validation for directory targeting/hidden rejection and destination metadata recovery for external packages/directory links/broken links when Refresh fails. Real Finder gesture, cursor, visual and accessibility results remain unexecuted.

Environment: macOS 27.0.1 (`26A434`), arm64, Apple Swift 6.4 and Node.js 26.1.0. Command Line Tools are selected; the bundler used installed Xcode for asset compilation. Existing compiler/linker warnings did not prevent the build or tests.

## Recorded scope and limits

Incoming file URL selections target the receiving visible browser's current directory, including single-pane mode and empty lists. Dropping over a folder row does not redirect the request into that folder. The native table callback is exercised with a real pasteboard and a controlled dragging-info object; this is not a live Finder gesture.

Default copy requires source copy permission. Command chooses move only when permitted; a copy-only source still advertises copy, and an unsupported source operation is rejected. This uses [AppKit's source operation mask](https://developer.apple.com/documentation/appkit/nsdragginginfo/draggingsourceoperationmask). Empty, mixed unsupported, duplicate, service and non-local file URL payloads are rejected as a whole. Promised files are not received.

The submission reserves the operation and snapshots ordered source URLs/destination before queued work. Copy/move reuse whole-request preflight, identity/ancestry/collision checks, move confirmation, current-window dirty Save/Discard/Cancel, background execution, structured partial outcomes and matching-pane recovery. The drop callback accepts a queued request; application status reports filesystem success only after execution. Cancel or failed Save can still abort that accepted request without mutation.

Automated coverage includes single mode from either browser, hidden/invalid/duplicate submission rejection, immediate destination capture across navigation, move confirmation/cancellation, whole-batch collision rejection, partial copy reporting, affected source dirty choices/failed Save, moved-folder browsing recovery and destination classification through failed Refresh. Existing copy/move regressions cover their unchanged filesystem safeguards.

Acceptance mapping: incoming portion of A21 and drag-batch A20; current-window A5–A9 and A34 safeguards. Full criteria remain Pending. Unit 2 will separately add outgoing selection export/dirty preparation and enable pane-to-pane/outgoing Finder drags. Cross-window coordination stays in T16. The M3 quality checkpoint follows completion of T13's remaining unit and review gates.

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
for (const name of ['destination', 'single-destination', 'collision-destination', 'other']) {
  await mkdir(join(root, name));
}
await writeFile(join(root, 'collision-destination', 'space ü.txt'), 'Existing destination must survive\n');
console.log(root);
JS
```

Open `copy-source` in Finder. In PanePeek, navigate a browser to `destination`; use `single-destination` for a fresh single-mode check. Use `move-source` for move checks. Do not remove working files or empty Trash for this review.

## Pending manual and accessibility checklist

- [ ] Drag a file, nested folder, package, listed links and a multiple-item selection from Finder into each visible browser. Default copy retains sources and link targets. Verify empty-list and folder-row drops use the receiving directory.
- [ ] Repeat with Command into a fresh destination. Inspect the intended cursor/operation, captured source count/list and destination in confirmation. Cancel first, then confirm a move; verify source removal and destination contents only on success.
- [ ] Drop a conflicting batch into `collision-destination`: no source/destination changes. Attempt plain text or a service URL: reject the whole unsupported payload. Review actionable errors and completed/failed/unattempted status for an available failure fixture.
- [ ] Repeat in One Pane. During a prompt or sufficiently large transfer, navigate the receiver or switch layout; the captured destination stays fixed and later navigation is retained.
- [ ] In PanePeek, preview/edit a source file (or a child of a dragged folder) while Finder supplies the drag. Exercise Save/Discard/Cancel and a failed Save; cancellation/failure retains edits and changes no selected source. Check preview/browser recovery after moving the source folder.
- [ ] Check keyboard/context alternatives by browsing the source in the other pane and using Copy/Move to Other Pane (Shift-F10 opens its menu). Check focus and no traps, VoiceOver table help/roles and status announcements, readable long paths/confirmation lists and supported text enlargement.
- [ ] Inspect drag feedback and errors in light/dark, narrow layouts, increased contrast and reduced motion. Record actual settings and sizes rather than assuming native defaults establish compliance.

## Review and publication

Agent-observed automated/build/process checks are recorded above. Bilal accepted the presented Unit 1 result on 2026-10-13, authorised its commit and approved continuation to Unit 2. The unchecked individual native/accessibility outcomes remain unreported; no agent-observed Finder gesture is claimed. Unit 2 retains its own manual review and commit gate. Publication is not started.
