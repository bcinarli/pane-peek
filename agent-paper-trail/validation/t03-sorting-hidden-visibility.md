# T03 sorting and hidden visibility validation

Status: Bilal accepted Unit 1, its presentation revision and stationary Modified heading on 2026-10-06, and authorised its local commit. All 16 tests and the bundle build pass. Unit 2 hidden visibility/Refresh and push/merge remain unapproved; T03 is incomplete. T02 PR #4 is confirmed merged as `50b3c4a`, with its dependency commits present on `main`.

## Manual feedback

On 2026-10-05, Bilal reported that placing the sort picker and direction button at opposite pane edges makes sorting cumbersome. Bilal prefers the accepted draft's Name/Modified column headings and relative recent dates with exact older dates. Bilal approved the bounded revision on 2026-10-06, including first-click directions and the date ranges in A2/A30. Future/unavailable values remain small display fallbacks; no creation/editing policies or special workflows were added. Bilal subsequently accepted Unit 1 including its revisions.

## Unit 1 scope and acceptance

Each pane has aligned clickable Name/Modified headings with an arrow beside the active heading. Switching to Name starts ascending; switching to Modified starts newest first. Activating the current heading reverses direction. Folders remain first; date ties use ascending natural names, then paths. Unknown dates remain last within their group for timestamp sorting. Packages and links have distinct icons, and directory links retain canonical navigation.

Recent date labels use completed minutes/hours, then local Today/Yesterday; older values use `dd.MM.yyyy HH:mm`. Help and accessibility expose complete timestamps and item type. Labels update each minute and on wake/activation without changing raw-date sorting or rereading the listing. See [A2/A30](../specs/001-mvp/spec.md#directory-panes) for the accepted ranges.

The A30 ordering was accepted with this unit's approval on 2026-10-05. A2 and single-window A30 have automated/native evidence below; Bilal accepted Unit 1 on 2026-10-06. Unreported manual checks remain explicit, and cross-window checks remain T16. A4 hidden visibility and Refresh remain Unit 2; transfer refresh remains in the operation tasks. Details and multiple selection are unchanged.

## Presentation revision evidence (2026-10-06)

Same OS/toolchain as the original unit below. Five added behaviour tests bring the full suite to 16 tests in two suites.

| Check | Executed result |
| --- | --- |
| Intentional red | `node scripts/test.mjs` against compiling minimal sort/date stubs failed on 23 intended expectations; all original 11 tests passed. |
| Green and final suite | `node scripts/test.mjs` passed all 16 tests after implementation and again after tightening. Tests cover header defaults/reversal/pane independence, completed-unit boundaries, exact local dates and midnight/DST calendar transitions. |
| Build/launch | `node scripts/build-app.mjs` passed after the final UI alignment changes. App launched from a fresh generated executable using the documented recovery; previous executables were preserved. No signing or bundler source change. |
| Mouse headers | Name descending, Modified descending/ascending and switching back to Name ascending worked. `file2.txt` stayed selected; the other pane retained its directory, selected `kept.txt` and sorting. |
| Keyboard headers | Shift-Tab focused Modified and Name; Space activated each heading and reversed Modified. Both selected URLs were retained. This supersedes the original picker keyboard limitation below. |
| Presentation | Final native dark layout inspected: headings align with row columns, direction arrow stays beside its heading, long names truncate without covering the date. Relative hours, Yesterday and exact older dates are visible; full timestamps are exposed in accessibility. |
| Live clock | Without navigation/reload, `minutes.txt` advanced from 13 min ago to 14 min ago over 64 seconds. Exact timestamp, row order and both selections stayed unchanged. |
| Documentation/fixture | Updated mixed/date fixture below executed successfully; embedded Node scripts parse, all 147 local Markdown links/anchors pass and `git diff --check` passes. |

The first green implementation had a corrected initializer argument-order compilation failure; that is not intentional red evidence. The periodic update is observed in the app. Wake/resume, light appearance, actual hover help and minimum-width resizing remain manual checks. Synthetic zoom/resize attempts did not establish a narrower window. Today has fixed-clock test evidence but was not observed during the overnight native review.

Tighten reused the existing sorter and native selection, kept one small date formatter, and aligned native list insets/header widths. Probe checked raw-date ordering, header defaults/reversal, local calendar boundaries and live-label selection retention. Earlier native navigation/error/package/link observations below remain evidence for the original unit; no revised-view repeat is claimed where unexecuted. No blocker was observed in the exercised revision paths.

Bilal also identified the reported popups as protected-folder permission requests. See [the permission note](../notes/README.md#protected-folder-permission-requests). No privacy choice was made by the agent; startup prompt timing is a separate follow-up.

## Header alignment correction (2026-10-06)

Bilal requested that Modified remain stationary when its sort arrow appears. The arrow now precedes the right-aligned label; Name retains its trailing arrow. This corrects the approved presentation revision in `BrowserWindow.swift` without changing sorting behaviour.

The bundle build and fresh-executable launch passed. Native screenshots were inspected with Modified inactive, ascending and descending: the label stays fixed and the arrow appears to its left. Selected `file2.txt` and the other pane's selected `kept.txt`, directory and sorting survived each change. Tighten kept the existing header helper and one arrow; probe checked both arrow directions, inactive alignment and independent selection. Whitespace passes. No new behaviour tests were needed for this layout correction; the earlier 16-test result remains the automated evidence.

At the correction checkpoint, the app was running on the same temporary review fixture, left Modified ascending and right Modified descending, with both selections intact. Bilal's later acceptance is recorded below.

## Unit 1 acceptance (2026-10-06)

Bilal said "approved now, commit unit 1" after reviewing the stationary Modified correction. This accepts the sorting unit including the column-header/relative-date revision and authorises its local commit on `bcinarli/t03-sorting-hidden-visibility`.

The approval does not individually report every manual checklist outcome. Keep those boxes unchecked where no result was supplied and retain the runtime limits above. A2/A30 remain partially validated; Unit 2 hidden visibility/Refresh, push and merge require separate approval. T03 remains in progress, not done.

## Original unit checks (2026-10-05)

macOS 27.0.1 (26A434), arm64; Swift 6.4, macOS SDK 27.0; Node.js 26.1.0. Runtime on macOS 26 and the minimum tool versions remains untested.

| Check | Command or fixture | Result |
| --- | --- | --- |
| Intentional red | `node scripts/test.mjs --filter DirectoryBrowsingTests` with compiling metadata/sort declarations | Four added tests failed on 22 intended expectations: metadata/link/package values, all four orders, path ties and latest pane settings. The original seven tests passed. |
| Green | Same targeted command after the core implementation | All 11 tests passed, including four sort combinations and two stale-result cases. |
| Final suite | `node scripts/test.mjs` after tightening | All 11 tests passed. |
| Bundle build | `node scripts/build-app.mjs` | Passed, including the final numeric-date/accessibility UI. Existing CLT linker search-path warnings were non-fatal. |
| Launch | Rebuilt `.build/PanePeek.app` | Final app launched after [fresh executable recovery](../notes/README.md#rebuilt-executable-recovery). The preceding in-place rebuild was rejected with an invalid signature; no signing or bundler source change was made. |
| Bundle metadata | `plutil -lint` on the generated Info.plist | Passed. |
| Deployment target | `plutil -extract LSMinimumSystemVersion raw` | `26.0`; this is a bundle value, not a macOS 26 runtime check. |
| Fixture/documentation | Original mixed fixture before relative-date additions; embedded Node script parsing, local links/anchors and `git diff --check` | Fixture creation and script parsing passed; all 92 local links passed and no whitespace errors were reported. |

The initial sandbox run failed before tests on compiler-cache access; it is not red evidence. Real temporary files cover modified dates, packages, valid/broken links and link dates distinct from target dates. Supplied listing entries cover unavailable dates and equal-name path ties independently of volume case rules. Controlled delayed reads reuse the existing listing gate.

## Original native checks and self-review

| Check | Agent observation |
| --- | --- |
| Both fields/directions | Name/default, Name descending and modified-time ascending/descending display the expected order with folders first. |
| Selection/independence | Selected `file2.txt` survives field/direction changes. The other pane retains its directory, selected `kept.txt`, Name field and ascending direction. |
| Metadata/presentation | Package/link icons are visible; full names, types and timestamps appear in accessibility. Link dates differ from their targets. Final dark layout and full numeric dates were inspected. |
| Navigation | Double-clicking the package leaves the directory unchanged. The directory link opens its canonical target; Command-Up returns to its target parent. Sort settings survive navigation. |
| Empty/error states | Empty directory shows No items. Missing-path navigation retains sorted entries, selection and settings with a visible error; valid navigation clears it. |
| Keyboard | Shift-Tab reaches the direction button and field picker; Space changes direction and opens the picker. Synthetic arrow/Return selection did not establish field selection. Bilal's complete keyboard check is pending. |

Tighten retained one comparator and one entry array, existing fixtures and native URL selection. Local UI helpers clarify icons; no generic filesystem or sorting layer was added. Probe checked unknown dates in either group/direction, ties, own link metadata, settings changed during a pending read, selection identity and retained navigation behaviour. No blocker remains in the exercised paths; manual review is still required. The task does not complete M1.

## Run and disposable fixture

From the repository root, quit an existing PanePeek process before rebuilding:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Use the recovery linked above if this development bundle hits the recorded cached-signature failure. Create a new fixture without touching working files:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink, utimes, lutimes, readdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const root = await mkdtemp(join(tmpdir(), 'panepeek-sorting-'));
const left = join(root, 'left');
const right = join(root, 'right');
await mkdir(left);
await mkdir(right);
for (const name of ['folder2', 'folder10', 'Sample.app', 'empty']) {
  await mkdir(join(left, name));
}
for (const name of ['file2.txt', 'file10.txt', 'tie2.txt', 'tie10.txt',
                    'a long filename with spaces and ü Unicode for sorting review.txt']) {
  await writeFile(join(left, name), 'Disposable sorting fixture.\n');
}
await writeFile(join(left, 'folder10', 'inside.txt'), 'Directory-link fixture.\n');
for (const [name, target] of [['file-link', 'file10.txt'], ['folder-link', 'folder10'],
                              ['package-link', 'Sample.app'], ['broken-link', 'missing']]) {
  await symlink(target, join(left, name));
}
for (const name of ['kept.txt', 'other.txt']) {
  await writeFile(join(right, name), 'Independent pane fixture.\n');
}
for (const entry of await readdir(left, { withFileTypes: true })) {
  const day = entry.isSymbolicLink() ? 3 :
    ['file10.txt', 'folder10', 'Sample.app'].includes(entry.name) ? 1 : 2;
  const date = new Date(`2026-10-0${day}T12:00:00Z`);
  const setTimes = entry.isSymbolicLink() ? lutimes : utimes;
  await setTimes(join(left, entry.name), date, date);
}
const now = new Date();
for (const [name, age] of [['just-now.txt', 5], ['minutes.txt', 600],
                          ['hour.txt', 7200], ['twelve-hours.txt', 45000]]) {
  const path = join(left, name);
  await writeFile(path, 'Disposable relative-date fixture.\n');
  const modified = new Date(now.getTime() - age * 1000);
  await utimes(path, modified, modified);
}
const yesterday = new Date(now);
yesterday.setDate(yesterday.getDate() - 1);
yesterday.setHours(0, 0, 0, 0);
await writeFile(join(left, 'yesterday.txt'), 'Local calendar-day fixture.\n');
await utimes(join(left, 'yesterday.txt'), yesterday, yesterday);
console.log(`Left: ${left}\nRight: ${right}`);
JS
```

Focus each pane, then Command-L to enter its printed path. Dates use the local timezone; older listing labels use the specified numeric format and full help uses the system locale. The earlier `file10.txt` contrasts with `file2.txt`; `tie2.txt`/`tie10.txt` share a date. The recent files show minute/hour labels and age while the app stays open. Yesterday can still appear as elapsed hours when fewer than thirteen hours old; rerun the fixture when a fresh Just now example is needed. Use the `empty` directory for the empty state. Packages and non-directory links remain selectable without navigation. Unknown timestamps have automated evidence; the normal fixture supplies real dates.

## Bilal's manual checklist

Unit 1 is accepted. Individual outcomes were not reported for this checklist, so unchecked items are not claimed as passed.

- [ ] Click Name/Modified; check that Modified stays stationary, first-click defaults, repeated-click reversal and folders first with natural timestamp ties.
- [ ] Keep a row selected while reordering; confirm the other pane retains its path, selection and sorting.
- [ ] Inspect relative/older exact dates and full hover timestamps; wait a minute and resume after sleep to check label updates.
- [ ] Inspect package/link distinction and canonical directory-link navigation.
- [ ] Check empty and failed navigation with sort settings retained.
- [ ] Use keyboard focus/Space for both column headings and their direction changes.
- [ ] Check light/dark appearance and narrow/wide pane resizing, including long names and dates.

Unit 1 is accepted and its local commit is authorised. Hidden visibility/Refresh requires the next unit's separate approval; push and merge remain unapproved.
