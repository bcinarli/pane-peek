# M1 sorting ownership validation

Status: accepted. Bilal approved C1/F2 implementation, confirmed the manual validations passed and accepted the unit on 2026-10-09. Branch: `bcinarli/m1-quality-remediation`. Commit authorised; push remains separate.

## Change

`DirectoryListing.read` returns filesystem entries without sorting. `DirectoryPane` applies its current settings using the existing background comparator and publication guards. This removes the redundant default Name sort on navigation and Refresh. The reader's doc-comment records its unspecified order.

The paired filesystem test checks names and directory classification without assuming enumeration order, then checks natural folders-first ordering and empty navigation through the pane. No new helper or abstraction was added. Comparator, selection, visibility and race handling are unchanged.

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4, SDK 27.0, Node 26.1.0. The minimum macOS 26 runtime was not tested.

- `node scripts/test.mjs --filter realListingDistinguishesDirectoriesAndPaneUsesNaturalOrder`: revised test passes before removing the reader sort.
- `node scripts/test.mjs`: all 29 tests in five suites pass after removal. Existing coverage includes both sort fields/directions, date/name ties, unknown dates, metadata/links, hidden visibility, selection reconciliation and stale navigation/sort publication.
- Production caller search confirms sorting is owned by the pane; direct reader tests consume metadata or canonical locations. `git diff --check` passes.
- `node scripts/build-app.mjs` and `plutil -lint .build/PanePeek.app/Contents/Info.plist` pass. Built and bundled executable hashes match. Known non-fatal Command Line Tools search-path warnings remain.
- The rebuilt bundle launches after the documented [generated-executable recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery), preserving the previous executable.
- The documented disposable-fixture recipe executes successfully; local documentation links and anchors pass.

This preserves app behaviour, so the revised boundary test was green before and after the refactor. No artificial red test or comparator-call assertion was added. Tests/build used normal compiler-cache access through sandbox escalation.

Native smoke used disposable directories with controlled timestamps. Name ascending/descending remained folders-first with natural numeric ordering. Modified newest/oldest sorted across kinds. `file2.txt` stayed selected and supplied Details throughout; the other pane retained Name ascending and selected `right2.txt`. Adding `refresh3.txt` externally and pressing Command-R published it in the current oldest-first position without changing either selection or the other pane.

The affected accessibility smoke confirms named sort buttons expose Ascending/Descending/Not sorted values, selected rows retain their accessible state, and the focused-pane Details path stays correct. Command-L navigation and Command-R Refresh work. No fresh VoiceOver, contrast or text-enlargement result is claimed for this core refactor; app-wide validation remains T18.

Initial Home loading remained pending during this smoke; explicit fixture navigation succeeded in both panes. Home loading latency and large-directory performance were not measured.

Light tighten retained the single existing sorting owner and revised one test. Light probe checked direct consumers, real filesystem ordering, unchanged concurrency guards and the native Refresh/selection seam. No additional C1 blocker was found. C2/F1 and C3/F3 remain separate pending units.

## Manual review

The rebuilt app was presented with disposable `left` and `right` directories. Left was Modified oldest first with `file2.txt` selected; right was Name ascending with `right2.txt` selected. The private session journal records the temporary fixture path.

- [x] Toggle Name both ways, then Modified both ways; verify natural folders-first Name and global date order while retaining selection and Details.
- [x] Press Command-R in the left pane; confirm its order/selection and the right pane's independent order/selection remain intact.

Bilal confirmed: “All accepted. Validations passed.” This accepts both presented manual checks and the C1/F2 unit. C2/F1 and C3/F3 remain unimplemented.

Use the [build/run instructions](../../README.md#build-and-run) to relaunch if needed. For a fresh disposable fixture, run this from the repository and open the printed directories with Command-L:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, utimes } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-sort-review-'));
const left = join(root, 'left');
const right = join(root, 'right');
await mkdir(left);
await mkdir(right);
for (const [name, folder, modified] of [
  ['folder10', true, 1700000100], ['file2.txt', false, 1700000200],
  ['refresh3.txt', false, 1700000250], ['folder2', true, 1700000300],
  ['file10.txt', false, 1700000400]
]) {
  const path = join(left, name);
  if (folder) { await mkdir(path); } else { await writeFile(path, 'Disposable fixture.\n'); }
  await utimes(path, modified, modified);
}
for (const name of ['right10.txt', 'right2.txt']) {
  await writeFile(join(right, name), 'Disposable fixture.\n');
}
console.log(left, right);
JS
```

Expected Name ascending: `folder2`, `folder10`, `file2.txt`, `file10.txt`, `refresh3.txt`. Modified oldest first: `folder10`, `file2.txt`, `refresh3.txt`, `folder2`, `file10.txt`. Newest first reverses the date order.
