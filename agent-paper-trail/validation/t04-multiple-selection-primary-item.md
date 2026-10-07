# T04 multiple selection and primary item validation

Status: Bilal accepted Unit 1 and authorised its local commit on 2026-10-07, on `bcinarli/t04-multiple-selection-primary-item` based on verified T03 merge `77a745e`. Automated checks and bounded native verification pass. Push, PR creation, merge and later coding units remain unapproved.

## Approved scope

Bilal approved the Unit 1 proposal on 2026-10-07 and required essential, high-value tests without redundant or native-framework replicas. Each pane owns its selected URL set and explicit primary item. Native Command/Shift selection and Select All feed that state; Details shows the focused pane's primary name. [A19](../specs/001-mvp/spec.md#multiple-selection-and-drag-and-drop) owns the accepted primary/fallback and reconciliation rules.

Coverage is single-window A19 and primary-selection input to A31, with A1/A3/A4/A30 regressions. A19 remains partial for T07 dirty guards and T16 windows; A31 remains partial for later preview/metadata/window work. Context actions, copied paths, file operations, editor/preview content and Details width are outside this unit.

## Executed checks

Environment: macOS 27.0.1 (`26A434`), Swift 6.4, SDK 27.0, Node 26.1.0. The bundle targets macOS 26.0; no macOS 26 runtime or CI result is claimed.

| Check | Result |
| --- | --- |
| Dependency/branch | Live GitHub PR #5 is closed/merged as `77a745e`, with reviewed head `d45bd8f` contained in `main`. Local/upstream/live main match. Created the separate T04 branch from that clean baseline. |
| Intentional red | `node scripts/test.mjs` with compiling minimal selection declarations produced 31 intended expectation failures. Two new selection scenarios and selection assertions in two existing navigation scenarios fail; prior expectations remain green. The initial sandbox compiler-cache failure was setup failure, not red evidence. |
| Select All regression red | Tightening the same selection scenario to add one remaining row exposed one failing primary-retention expectation with `node scripts/test.mjs --filter SelectionTests`. No additional test definition was needed. |
| Green | `node scripts/test.mjs`: all 25 tests in three suites pass. Two new tests cover primary/focus/pane isolation and real sorting/Refresh/hidden/deleted-row reconciliation. Existing failed/stale navigation tests gained selection assertions. |
| Build/launch | Initial and final `node scripts/build-app.mjs` pass with the existing non-fatal CLT linker search-path warnings. Fresh-executable native launches pass. Previous generated executables are preserved under ignored build backups. |
| Native selection/focus | Both panes loaded disposable fixtures. Shift-Up/Down extended/shrank ranges with the endpoint name in Details, including reversing direction. Command-A and Edit → Select All select visible rows; an existing primary is retained, or the first visible row is chosen from empty selection. Escape clears one list/Details. Focus and sort changes retain both panes' selections and Details follows the focused pane. Command-A in Go to Folder selects path text. |
| Native reconciliation/navigation | Selecting a hidden primary, Select All and hiding it prunes that row and chooses the first remaining selected row. Revealing leaves it unselected. Refresh after moving a disposable selected file out of the listing retains surviving selections; restoring the file does not restore its selection. Failed navigation retains selection/Details; successful navigation clears one pane while the other remains selected. Single-directory Return and double-click both open the directory. |
| Native regression probe | The initial hidden-primary/Select All/hide/Shift-Up sequence retained the fallback primary instead of reporting the new endpoint. Tracking the removed keyboard row's surviving visible position fixes this: the final build reports `file1.txt`, then `file2.txt` on the next shrink. No core behaviour changed after the passing suite. |
| Visual check | The long Unicode name wraps within Details in the running dark appearance. Bilal confirmed appearance and resizing work; individual light/dark checks were not separately reported. |
| Documentation/package | `git diff --check` passes; 182 local Markdown links/anchors and the published fixture's Node syntax pass. `Info.plist` validates and declares macOS 26.0. |

The app retains SwiftUI's native list and Edit Select All command; no AppKit bridge or app-command rewrite was needed. Click/keyboard reporting follows native selection completion. Tighten reused one interaction helper and kept one core selection owner. Probe removed selection-observer focus changes so programmatic pruning cannot activate an unfocused pane, and corrected keyboard endpoint tracking after a row disappears.

Bilal confirmed on 2026-10-07 that Command-click toggles selection and Shift-click selects ranges. Bilal also confirmed Select All/Escape, menu Select All (reported as the File menu), independent panes, appearance/resizing and the selected file name in the Details/preview pane. Individually unreported checklist details remain explicit below. Modifier-click checks were performed by Bilal because the native UI tool cannot hold a modifier during a click.

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

## Bilal's manual checklist

- [x] Command-click toggles selection, confirmed by Bilal on 2026-10-07.
- [ ] Verify toggles in both panes and that removing the primary chooses the first remaining selected row in displayed order.
- [x] Shift-click selects ranges, confirmed by Bilal on 2026-10-07.
- [ ] Verify ranges in both directions and that keyboard extension/shrinking follows the endpoint in Details.
- [x] Select All/Escape and menu Select All work, confirmed by Bilal on 2026-10-07.
- [ ] Verify visible-only selection, retaining an existing primary, first-visible primary from empty selection and Command-A in Go to Folder selecting path text.
- [x] Panes are independent and the selected file name appears in Details/preview, confirmed by Bilal on 2026-10-07.
- [ ] Verify focus changes retain selections and sorting retains all selected URLs and the primary.
- [ ] Reveal/select/hide a hidden row, then Refresh after renaming a selected disposable file. Surviving selections remain; unavailable rows are pruned; revealing does not restore old selection.
- [ ] Failed navigation retains selection; successful directory navigation clears it. Directory double-click/Return still works for one directory. Check empty panes and long Unicode names.
- [x] Appearance and resizing work, confirmed by Bilal on 2026-10-07.

An unchecked outcome was not individually reported by Bilal. Overall acceptance does not claim those reports or complete criteria spanning later tasks.

## Acceptance and commit approval (2026-10-07)

After the manual confirmations above, Bilal instructed "commit the changes". This accepts the reviewed Unit 1 result and separately authorises its local commit. T04 implementation/manual review is complete; A19 remains partial for dirty-preview guards and independent windows, and A31 for later content/metadata/window work. No code changed after the executed checks, so no project test/build/native run was repeated for this acceptance update. Push, PR creation, merge and later coding units require separate approval.
