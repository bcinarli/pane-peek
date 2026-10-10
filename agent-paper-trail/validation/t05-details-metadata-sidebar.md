# T05 Details metadata sidebar

## Unit 1 scope and review state

Bilal approved implementation on 2026-10-09, confirmed all five manual checks and accepted Unit 1 on 2026-10-10. T05 is `done`. Bilal authorised commit, push and PR creation, then merge and local workspace cleanup on 2026-10-10.

Implementation `540b72b` is committed and pushed. [PR #12](https://github.com/bcinarli/pane-peek/pull/12) targets `main` and records its merge state.

Details reads the focused primary item's creation/modified dates, permissions, owner/group, type and available byte size below the preview placeholder. Missing fields say `Unavailable`. Links show their own attributes and stored target separately, including relative/broken targets. Folder/package aggregate size is unavailable. Existing displayed-path formatting and clipboard actions are retained.

A31/A33 are partially validated: this unit covers single-window metadata, latest selection and manual Refresh. T06 content, T16 independent windows and later save/mutation refresh remain outstanding. A17/A19 behaviour is preserved. No Details width change or recursive size calculation is included.

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4, SDK 27.0, Node 26.1.0. Command Line Tools build/test; installed Xcode asset compiler packages the bundle. No macOS 26 runtime claim.

| Check | Result |
| --- | --- |
| `node scripts/test.mjs --filter MetadataTests`, compiling stubs | Intentional red: 26 issues across five tests for missing formatting/real metadata, stale success/error, clear/failure and same-item Refresh. Sandbox-cache and unsupported-constant build failures are excluded from red evidence. |
| `node scripts/test.mjs`, final files | Pass: 45 tests in six suites. Four deliberate known issues belong to the existing test-gate failure tests. |
| Metadata behaviour | Real file/relative link/broken link/folder/package reads; special permission bits; explicit unavailable permission/size; missing read; superseded success/error; clear/failure; cancellation/retry; unchanged-listing Refresh and pane focus. |
| `node scripts/build-app.mjs` | Pass; bundle plist validates and native app launches. The documented fresh-executable recovery was needed for one relaunch. |
| `git diff --check` | Pass. |

Tighten removed assertions that repeated optional-property initialisation and retained local async/state conventions. Probe added cancellation/retry coverage, checked bounded test-gate failure state, and exercised real Refresh/error/clipboard seams. Native inspection prompted explicit name/value accessibility elements for each field: GridRow grouping alone did not reliably associate labels with selectable values. No remaining implementation blocker was identified. Bilal accepted the manual checks below.

## Native observations

- File metadata matched `stat`: five bytes, `0640 · rw-r-----`, owner/group and full creation/modified timestamps. Folder/package kinds and unavailable size remained visible without content preview.
- Valid relative/absolute links and the broken link retained link-own byte sizes/dates/permissions. `readlink` confirmed stored target text. Broken-link fields were available despite the missing target.
- Switching panes retained each selection and changed Details to the focused primary. Shift range selection and Command-click primary deselection showed the expected item; rapid changes ended on the latest item. Escape cleared Details while retaining the other pane's selection.
- Changing only file permissions, retaining size/modified date, then Command-R updated Details for the same selected URL. A file moved outside the listing produced an explicit error and unavailable fields without old values. Restoring it and Refresh cleared the error and loaded its metadata. Fixture changes were restored.
- Actual clipboard pastes verified the adjacent copy control and keyboard absolute-path action. Listed link paths and long paths with spaces/Unicode copied as displayed. The long name/path and metadata wrapped at the current 300-point sidebar width in dark appearance.
- The final native accessibility tree exposes each metadata field name and value, the selected path/copy action and separate link target. Keyboard path copy works. Bilal confirmed long-path copying, narrow layout, light/dark appearance, enlarged text and VoiceOver on 2026-10-10. No contrast measurements or comprehensive accessibility audit are claimed.

## Run and fixture

From the repository root, quit the app before rebuilding:

```sh
node scripts/test.mjs
node scripts/build-app.mjs
open .build/PanePeek.app
```

Create an isolated fixture. Copy the printed assignment into the shell for the optional checks below. Use Command-L to open its `left` and `right` folders in the corresponding panes. Existing test fixtures and temporary backups stay outside version control.

```sh
node --input-type=module <<'JS'
import { chmod, mkdir, mkdtemp, realpath, symlink, utimes, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await realpath(await mkdtemp(join(tmpdir(), 'panepeek-t05-review-')));
for (const name of ['left', 'right', 'left/folder', 'left/Example.app']) {
  await mkdir(join(root, name));
}
for (const [name, content] of [
  ['left/file2.txt', 'hello'],
  ['left/file10.txt', 'second metadata fixture\n'],
  ['left/unavailable.txt', 'read failure fixture'],
  ['left/Long filename with spaces and Unicode İstanbul 日本語 for metadata wrapping.txt', 'long path fixture'],
  ['right/right2.txt', 'other pane']
]) {
  await writeFile(join(root, name), content);
}
await chmod(join(root, 'left/file2.txt'), 0o640);
await utimes(join(root, 'left/file2.txt'), 1700000000, 1700000000);
for (const [name, target] of [
  ['relative-link', 'file2.txt'],
  ['absolute-link', join(root, 'left/file2.txt')],
  ['folder-link', 'folder'],
  ['broken-link', 'missing.txt']
]) {
  await symlink(target, join(root, 'left', name));
}
console.log(`PANEPEEK_T05_FIXTURE='${root}'`);
JS
```

Compare own attributes without following links. The `stat` modes include the file-type prefix; Details shows only the four permission digits and nine access/special-bit symbols.

```sh
stat -f 'kind=%HT bytes=%z symbolic=%Sp octal=%Op owner=%Su group=%Sg created=%SB modified=%Sm' \
  -t '%Y-%m-%d %H:%M:%S %Z' \
  "$PANEPEEK_T05_FIXTURE/left/file2.txt" "$PANEPEEK_T05_FIXTURE/left/broken-link"
readlink "$PANEPEEK_T05_FIXTURE/left/broken-link"
chmod 600 "$PANEPEEK_T05_FIXTURE/left/file2.txt"
```

Keep `file2.txt` selected, then Command-R: expect `0600`. Restore its permissions below and Refresh again:

```sh
chmod 640 "$PANEPEEK_T05_FIXTURE/left/file2.txt"
```

For a read failure, move `unavailable.txt` aside after its row has loaded, select the stale row before Refresh, then restore it and Refresh:

```sh
mv "$PANEPEEK_T05_FIXTURE/left/unavailable.txt" "$PANEPEEK_T05_FIXTURE/held-unavailable.txt"
```

Inspect the stale row before running the restore, then Refresh:

```sh
mv "$PANEPEEK_T05_FIXTURE/held-unavailable.txt" "$PANEPEEK_T05_FIXTURE/left/unavailable.txt"
```

## Bilal's manual checklist

- [x] Compare file fields with file information; check folder/package unavailable size and metadata without preview.
- [x] Check relative/absolute/broken links: link-own metadata, separate stored target, copied listed path.
- [x] Switch panes, range/toggle the primary, change selections rapidly and clear. Details always describes the focused primary or clears.
- [x] Change fixture permissions and Refresh; exercise the moved-file error and recovery. Old fields never remain under a new selection/error.
- [x] Check long-path copy by button/keyboard, narrow layout/scrolling, light/dark contrast, native text enlargement and VoiceOver field names/values, loading/errors and focus.

Bilal reported all five presented checks as “OK” and explicitly approved the unit on 2026-10-10. Acceptance outcome: accepted. A31/A33 remain partial for their later-task integrations. No further coding unit is authorised.
