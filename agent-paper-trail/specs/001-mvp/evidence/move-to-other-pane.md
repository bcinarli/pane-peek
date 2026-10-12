---
task: move-to-other-pane
verdict: Pending
closed: ""
---

# T11 Move selected items to the other pane

Status: Active. Bilal authorised implementation and accepted the presented Unit 1 on 2026-10-12, then separately authorised its commit. Unit 2 is not started or authorised; task completion and publication remain pending.

## Unit 1, 2026-10-12

- Agent-observed red/green: `node scripts/test.mjs --filter ItemMoveTests` observed six failing behaviour tests against a non-mutating API scaffold (66 issues); `--filter BrowserMoveTests` observed seven failing behaviour tests (23 issues). Probe's `--filter destinationReplacementAfterPublication` observed source removal after a replaced destination (two issues), then passed with the destination identity safeguard. Setup/compilation failures are excluded from intentional red evidence.
- Final executed checks: the full `node scripts/test.mjs` suite and final app bundle build are recorded below. Move coverage includes real contents/link fixtures, exclusive collisions, an actual permission-denied rename, forced cross-device copy/remove and cleanup failures, partial folder removal, stale targets, duplicate submission, dirty Save/Discard/Cancel, containing-folder guards, unrelated draft retention, failed Refresh and pending navigation. Injected cross-volume checks are distinct from a real second-volume check.
- Tighten then probe: reuse capture/validation, Save baselines, selection/sorting and native prompt precedent; share the existing transfer status. Probe added published-destination identity protection and affected pending-read invalidation. No generic operation framework or later-task implementation was added. Agent native launch/accessibility checks were blocked by a locked Mac. Bilal subsequently accepted the presented unit; individual native/accessibility outcomes were not supplied. Commit was separately authorised. No push or PR is claimed.

## Executed checks and limits

- Environment: macOS 27.0.1 (26A434), Swift 6.4 arm64 and Node 26.1.0; Command Line Tools compile the package and installed Xcode supplies asset compilation.
- Final `node scripts/test.mjs`: 361 tests passed (336 core and 25 native regression tests), with four existing expected timeout-diagnostic issues. Final `--filter MoveTests`: 22 tests passed. Final `node scripts/build-app.mjs`: passed and produced the development app bundle.
- `git diff --check`: passed for the final code/record diff. Relative file links in changed Markdown records checked; native launch remains pending.
- Dependency: local/live `main` at `9a669b0` contains T10 PR #23's full closing head `d06f484` and integration `526ecce`. Unit 1 uses `feature/t11-move-to-other-pane` from that baseline.
- No real second-volume move has been exercised. No second disposable writable volume was established. Namespace/content changes by other applications remain outside a transaction guarantee.

## Disposable fixture and run instructions

Quit PanePeek before rebuilding. From the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Create a fresh disposable fixture. The script prints its location:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const fixture = await mkdtemp(join(tmpdir(), 'panepeek-t11-'));
for (const name of ['source/folder', 'source/sample.app', 'destination', 'target-folder']) {
  await mkdir(join(fixture, name), { recursive: true });
}
await writeFile(join(fixture, 'source/example.txt'), 'Move me.\n');
await writeFile(join(fixture, 'source/folder/draft.txt'), 'Edit before moving the folder.\n');
await writeFile(join(fixture, 'source/sample.app/payload.txt'), 'Package contents.\n');
await writeFile(join(fixture, 'source/conflict.txt'), 'Preserve the source.\n');
await writeFile(join(fixture, 'destination/conflict.txt'), 'Preserve the destination.\n');
await writeFile(join(fixture, 'target.txt'), 'Link target stays here.\n');
await symlink('../target.txt', join(fixture, 'source/link.txt'));
await symlink('missing.txt', join(fixture, 'source/broken-link'));
await symlink('../target-folder', join(fixture, 'source/directory-link'));
console.log(fixture);
JS
```

Focus one browser and use Command-L to open `<fixture>/source`. Focus the other and open `<fixture>/destination`. Choose Move to Other Pane from a row's context menu, or Shift-F10 from the focused table (Fn may be needed). Keep fixtures for review; a fresh recipe supplies repeatable original contents.

## Manual review, 2026-10-12

Bilal accepted the presented Unit 1 and authorised its commit. This is overall unit acceptance; the agent did not observe native launch and Bilal did not supply individual checklist, accessibility-setting or real-volume outcomes. Keep those limits visible. T11 remains Active/Pending until batch Unit 2 is implemented and accepted.

## Individual manual/accessibility outcomes

- [ ] Move one file, folder, package and each listed-link kind in both directions. Check source disappearance, destination contents/link text and untouched link targets.
- [ ] Check the confirmation's complete source/destination, Cancel/Escape and Return/Move. Cancellation leaves files and any draft intact.
- [ ] Try `conflict.txt`, a same-directory target and a folder descendant reached through a directory alias. Rejection leaves existing items unchanged.
- [ ] Edit `example.txt`, then Move with Save, Discard and Cancel. Also edit a contained file before moving its folder. Check fresh destination saving and retention on a rejected/failed move.
- [ ] Check single-pane and multiple-selection Move are disabled. During a larger transfer, navigate or change layout; the captured destination remains fixed and duplicate/conflicting mutations are rejected.
- [ ] Check retained status/error text, dismissal and keyboard menu/sheet focus. Exercise VoiceOver action names, paths and result/error perception.
- [ ] Check light/dark contrast, increased contrast, reduced motion and the supported text-enlargement mechanism/size, including long paths and a narrow window. Record actual settings and sizes.
- [ ] If a disposable second writable volume is available, exercise a real cross-volume move and record its volume/filesystem. Do not report injected EXDEV coverage as this check.

Individual native/accessibility outcomes above remain unreported. Bilal’s overall Unit 1 acceptance is recorded separately. Affected criteria remain Pending; Unit 1 does not close batch scope, real second-volume validation or T16 cross-window coordination.
