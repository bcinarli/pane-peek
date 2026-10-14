> Historical detail and fixtures. The current task verdict is in [T03 evidence](../specs/001-mvp/evidence/sorting-hidden-visibility.md); current criterion status is in [MVP validation](../specs/001-mvp/validation.md). Earlier checkpoint statements below are historical.

Status: Archived

# T03 sorting and hidden visibility validation

Status: Bilal accepted both units and the performance/test/document follow-ups on 2026-10-06. [PR #5](https://github.com/bcinarli/pane-peek/pull/5) merged as `77a745e`, verified on `main`. Executed checks and manual limits are recorded below.

Bilal confirmed both chronological Modified directions, folders-first Name, visible-selection retention through hidden toggling/Refresh and selection clearing when its hidden row disappears. Bilal then confirmed the now label correction and accepted all other tested features within Unit 2 scope. Individually unreported checks remain explicit below.

## Sorting performance follow-up (2026-10-06)

Bilal requested verification and correction of valid PR comments, then identified the [sorting-performance comment](https://github.com/bcinarli/pane-peek/pull/5#discussion_r4197564416). The reviewed PR head is `6fa42744d204ec8a0172da25315addfe18018dcb`, matching the clean checkout before this correction. The finding is valid: synchronous pane sorting occupied the main actor, and changing columns triggered separate sorts through both setting observers. The existing T03 feature branch and T02 dependency remain verified.

The correction keeps the accepted comparator and URL identities. Each column request sets field/direction together and sorts one snapshot in background work. Rows remain usable until the result arrives. A newer sort or published listing invalidates an older result; navigation publishes its directory and sorted rows together, using current settings even if they change during sorting. No grouping control, cache or worker framework was added. A2/A30 are the acceptance scope, with A3/A4 regressions.

| Check | Executed result |
| --- | --- |
| Baseline | Optimised Swift 6 in-memory probe: switching Modified → Name occupied the main actor for 0.086 seconds with 10,000 entries and 0.532 seconds with 50,000. |
| Intentional red | `node scripts/test.mjs --filter DirectoryBrowsingTests`, with compiling minimal asynchronous declarations: three intended expectation failures across two new tests. Older sorts replaced newer choices/rows and the directory changed before its sorted listing was ready. All original 16 browsing tests passed. |
| Green | `node scripts/test.mjs`: all 23 tests in two suites pass. Controlled sorts cover old completions after newer choices/listings, settings changed while sorting a loaded listing, and an older navigation sort completing while newer navigation is loading. Existing order/tie, hidden, Refresh, failure and stale-read tests remain green. |
| Responsiveness | Final optimised probe: the 50,000-entry sort took 0.512 seconds while a main-actor heartbeat ran 71 times; its largest observed interval was 9.4 ms. At 10,000 entries: 0.070 seconds, ten heartbeats, 7.5 ms largest interval. These are local core measurements, excluding filesystem reads and SwiftUI rendering; no timing threshold was added to tests. |
| Build/launch | `node scripts/build-app.mjs` and fresh-executable launch pass with the previously recorded non-fatal CLT warnings. The old generated executable was preserved. Same OS/toolchain as the original checks; no macOS 26 runtime claim. |
| Native mixed listing | Both Modified directions remain chronological; switching to Name gives natural folders-first order. Left `file2.txt` and right `file10.txt` stay selected. Left hidden toggle and focused Refresh retain rows/settings without changing the right pane. |
| Native large listing | A real 10,000-file folder loaded. Rapid Modified → Name requests ended in Name ascending; right focus/selection remained usable. Reversing Name brought the still-selected `file9999.txt` back into view, retaining right `file10.txt`. No whole-render latency number is claimed. |
| Documentation/bundle | All 165 local Markdown links/anchors, seven fixture scripts, whitespace and generated plist lint pass. The bundle declares minimum macOS `26.0`; repository documentation contains no private or machine-specific paths. |

Standard tighten retained one comparator, one stored listing and one sort-request identity, and simplified direction selection. Deep probe checked both asynchronous publication boundaries, delayed completions, navigation/loading/error retention, visibility, actual large-list actor availability and native URL selection. An additional agent navigation-after-sort/Refresh check was blocked when the Mac locked. Bilal subsequently confirmed that interaction during manual review. No privacy change, personal-file mutation, commit, push or external review reply was performed.

### Performance review fixture

Use the [global-date fixture](#global-date-disposable-fixture) for mixed folders/files and independent selected rows. For a larger directory, create disposable files with distinct modified times:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, utimes } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-sort-performance-'));
const large = join(root, 'large');
await mkdir(large);
for (let batch = 0; batch < 100; batch++) {
  await Promise.all(Array.from({ length: 100 }, async (_, offset) => {
    const index = batch * 100 + offset;
    const path = join(large, `file${(index * 7919) % 10000}.txt`);
    await writeFile(path, 'Disposable large-list fixture\n');
    const date = new Date(1700000000000 + index * 1000);
    await utimes(path, date, date);
  }));
}
console.log(`Large: ${large}`);
JS
```

Launch with `open .build/PanePeek.app`. Focus the left pane and enter the printed Large path with ⌘L; keep the right pane on a mixed fixture. Select a row in each pane. The fixture uses the same 10,000-file generation exercised above; leave it in place until cleanup is authorised.

Bilal’s correction checklist:

- [x] Alternate Name/Modified quickly; the final heading/direction matches the final order and the other pane remains usable.
- [ ] Reverse both fields, toggle hidden files and Refresh; selected URLs and independent settings survive.
- [x] Start a sort, then Refresh or navigate; the final directory, rows and sort choice agree without stale rows returning.

Bilal confirmed that rapid Name/Modified switching and Refresh/navigation during sorting work correctly on 2026-10-06. This accepts the performance correction. Earlier unit acceptances and individually unreported checks remain recorded. Follow-up acceptance and source-control approval are recorded below.

## Test-quality cleanup (2026-10-06)

Bilal reviewed the bounded T03 test-quality findings and approved cleanup. A2/A30 coverage remains, with A3/A4 pending-load and Refresh regressions. Only the two test files changed in this unit; the accepted app implementation is unchanged.

- Replace the two weak daylight-saving pairs with timestamps near local midnight. Both now distinguish calendar-day subtraction from fixed 24-hour arithmetic.
- Remove the immediate read of an assigned visibility flag and Foundation's identical-name comparison assertion. Retain final visibility and actual stable-path ordering checks.
- Replace the pending-navigation test's real files, timestamp writes and listing read with in-memory entries. Keep initial-load and Refresh scenarios separate; real metadata remains covered by the listing test.

| Check | Executed result |
| --- | --- |
| DST mutation check | Compile temporary copies of the existing formatter against the revised test pairs. The fixed-24-hour variant fails both expectations; the unchanged calendar implementation returns Yesterday for both. This is test-sensitivity evidence, not a product implementation red. No production source was mutated. |
| Full suite | `node scripts/test.mjs`: all 23 tests in two suites pass, including the revised DST and pending-navigation cases, real metadata and all three sorting races. Compilation succeeds with the known non-fatal CLT linker warnings. |
| Documentation | All 174 local Markdown links/anchors and `git diff --check` pass. |
| App review | Bilal's accepted rapid-sort and Refresh/navigation results above cover the existing bundle. No UI or production source changed in this cleanup, so the bundle was not rebuilt and no new native result is claimed. |

Light tighten removed only the identified assertions and disk setup, without a new shared helper. Light probe verified that the DST fixtures detect the intended mistake and that initial-load, Refresh, tie-break and stale-sort coverage remain. The test count stays at 23 because meaningful scenarios were preserved.

Use the existing app with `open .build/PanePeek.app`; the [performance fixture](#performance-review-fixture) and [global-date fixture](#global-date-disposable-fixture) remain available. Review the two test diffs for the removed assertions/setup and stronger DST timestamps. Bilal subsequently accepted this cleanup and authorised commit/push as recorded below; the next unit remains unapproved.

## Paper-trail indexing cleanup (2026-10-06)

Bilal requested README files as entry points and indexes. The [notes index](../notes/README.md) now links five focused records; existing observations, recovery commands and proposed follow-ups were preserved. Four anchored consumers now point to the moved notes. The paper-trail and MVP package entry READMEs link the canonical tracker/evidence instead of repeating acceptance history.

The plan now contains task scope, dependencies and checkpoints with evidence links. Dated approval, acceptance and publication history was removed from it; validation owns those records and the tracker owns execution state.

Light tighten grouped related topics without creating a note for every paragraph and removed approval history from the plan. Light probe checked preserved caveats, the unresolved follow-ups and all moved links. All 178 local Markdown links/anchors, 11 embedded Node snippets (syntax only) and `git diff --check` pass. The 23-test result above remains current; no production source changed or redundant suite/build/app run occurred during this documentation work. Bilal accepted the combined cleanup when authorising its commit; no new native review was needed for these test/document edits.

## Follow-up acceptance and source-control approval (2026-10-06)

After reviewing the test and documentation cleanup, Bilal instructed "commit the changes", then "then push". This accepts the presented cleanup and separately authorises local commits plus a push of the existing T03 branch. Code/test commit `0f052fc` contains the background-sorting correction and test refinement; the documentation commit contains the notes index, plan/evidence ownership cleanup and this acceptance record. Earlier executed checks remain current; no code changed or build/test/native run was repeated for acceptance-only updates. Merge and later tasks remain unapproved.

## Merge (2026-10-06)

Bilal authorised PR #5's merge and workspace cleanup. GitHub confirmed merge `77a745e` at `2026-10-06T18:18:39Z`. T04 preflight verified local/upstream/live `main` at that merge and reviewed head `d45bd8f` contained in it.

## Publication (2026-10-06)

Bilal instructed "commit unit 2 and push and create a PR" after manual acceptance. Unit 2 was committed as `1a1041fc1c5718adf255160b20a86b684f72c209`, following Unit 1 `f7965968edfb87bbf6672f6c1e3ea681a0cba5cc`, on `bcinarli/t03-sorting-hidden-visibility`. The branch push succeeded and [PR #5](https://github.com/bcinarli/pane-peek/pull/5) was created open against `main` and attached to the working chat.

Staging contained exactly the 14 reviewed Unit 2 code/test/evidence surfaces; whitespace and private-path checks passed. Publication records use light tighten then probe to preserve acceptance limits and the separate merge/next-task gates. No source change or additional test/build run was needed for these documentation updates. At this publication checkpoint, merge was pending and M1 remained incomplete.

## Manual feedback

On 2026-10-05, Bilal reported that placing the sort picker and direction button at opposite pane edges makes sorting cumbersome. Bilal prefers the accepted draft's Name/Modified column headings and relative recent dates with exact older dates. Bilal approved the bounded revision on 2026-10-06, including first-click directions and the date ranges in A2/A30. Future/unavailable values remain small display fallbacks; no creation/editing policies or special workflows were added. Bilal subsequently accepted Unit 1 including its revisions.

### Modified ordering revision proposed (2026-10-06)

During Unit 2 review, Bilal confirmed Show Hidden Files through Directory actions, View and its shortcut, plus focused-pane Refresh and its shortcut. Bilal reports Name sorting works, while Modified's separate directory/file ordering is confusing. The supplied screenshots show the current A30 folder-first rule, which sorts dates within each group. Read-only inspection of the comparator, original-resolution screenshot and live timestamp values confirmed that behaviour; no separate date inversion was established.

Recommend keeping folders first for Name and sorting Modified globally by actual timestamps, interleaving folders/files in either direction. Retain header defaults/reversal, natural-name/path tie-breakers, date labels and selected URL identity. Explicit Kind grouping would need additional controls and visible group separation; defer that larger alternative.

At this proposal checkpoint, the changed A30 contract awaited approval. Expected code/test surfaces were `DirectoryListing.swift` and `DirectoryBrowsingTests.swift`, with spec/plan/README/evidence amendments after approval. Proposed validation reused existing sorting/visibility tests for global chronological order and cross-kind ties, then the full suite, bundle build and native mixed-fixture review. No revision code or tests had been changed or run at that checkpoint.

### Global Modified revision evidence (2026-10-06)

[Changed, approved] Bilal approved folders-first Name and global Modified ordering, prioritising simplicity and performance. Kind grouping remains deferred and is not a priority. Updated A30 and the plan before implementation. The existing T03 feature branch retains the verified T02 dependency; no new UI, state or grouping abstraction was added.

| Check | Executed result |
| --- | --- |
| Intentional red | `node scripts/test.mjs` compiled and recorded four intended ordering failures: both global-date directions and hidden-on/off mixed listings. Name cases and the other 18 tests passed. Existing cross-kind ties and unavailable timestamps exercise the revised rule. |
| Green | Restricting the existing folder-first condition to Name made all 20 tests in two suites pass. Date ties remain natural Name ascending, then path; unavailable dates are globally last in either date direction. |
| Build/launch | `node scripts/build-app.mjs` passed with the recorded non-fatal CLT warnings. The previous executable was preserved and the fresh bundle launched. Same OS/toolchain as below; no macOS 26 runtime claim. |
| Native sorting/selection | Both Modified directions interleave folders/files by date. Equal-date `file10.txt` precedes `folder2` in either direction. Name retains folders first in ascending/descending natural order. Left selected `file2.txt` and right selected `file10.txt`, paths and independent settings survive all changes. |
| Native visibility/Refresh | Left-only hidden visibility places dot/metadata-hidden rows into the global order. Added a newer file and folder to both disposable directories: neither listing changed until ⌘R refreshed only the left. Sort/visibility and both selections survived; right retained its old listing. Both date directions also passed after Refresh. |
| Presentation | Native dark screenshot inspected. App is left on the mixed fixture: left Modified descending with hidden items shown and `file2.txt` selected; right Name descending with hidden items off and `file10.txt` selected. |
| Documentation/bundle | All 155 local Markdown links/anchors, five embedded fixture scripts and `git diff --check` pass. Generated Info.plist lint passes and declares minimum macOS `26.0`. Added repository prose contains no private journal or machine-specific paths. |

Tighten kept one comparator condition and updated existing behaviour tests. Probe checked cross-kind ties, unavailable dates, raw timestamps, hidden filtering, focused Refresh and the native URL-selection seam. A2/A30 are covered with A4 regressions. Manual acceptance was pending at this checkpoint and is recorded below. Earlier light/resize/wake and cross-window limits remain unchanged. No later task, commit or push is authorised.

#### Global-date disposable fixture

Launch using the run instructions below. This fixture creation was executed and used for native review:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, utimes } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
const root = await mkdtemp(join(tmpdir(), 'panepeek-global-dates-'));
const now = Date.now();
for (const side of ['left', 'right']) {
  const pane = join(root, side);
  await mkdir(pane);
  for (const [name, folder, age] of [
    ['folder2', true, 1200], ['folder10', true, 1800],
    ['file2.txt', false, 600], ['file10.txt', false, 1200],
    ['.hidden-folder', true, 300], ['.dot.txt', false, 1500], ['flagged.txt', false, 900]
  ]) {
    const path = join(pane, name);
    if (folder) { await mkdir(path); } else { await writeFile(path, 'Disposable sorting fixture\n'); }
    const date = new Date(now - age * 1000);
    await utimes(path, date, date);
  }
  execFileSync('/usr/bin/chflags', ['hidden', join(pane, 'flagged.txt')]);
}
console.log(`Root: ${root}\nLeft: ${join(root, 'left')}\nRight: ${join(root, 'right')}`);
JS
```

Focus each pane and enter its printed path with ⌘L. Select `file2.txt` on the left and `file10.txt` on the right. With hidden items off, Modified descending is `file2.txt`, `file10.txt`, `folder2`, `folder10`; ascending is `folder10`, `file10.txt`, `folder2`, `file2.txt`. Equal dates keep ascending Name order. Show hidden files on the left to inspect the interleaving.

For a focused Refresh check, add a newer file and folder to both directories after loading them:

```sh
PANEPEEK_FIXTURE_ROOT="paste the printed Root here"
node --input-type=module - "$PANEPEEK_FIXTURE_ROOT" <<'JS'
import { writeFile, mkdir, utimes } from 'node:fs/promises';
import { join } from 'node:path';
const root = process.argv[2];
const now = Date.now();
for (const side of ['left', 'right']) {
  const file = join(root, side, 'newest.txt');
  const folder = join(root, side, 'new-folder');
  await writeFile(file, 'Disposable refresh fixture\n');
  await mkdir(folder);
  await utimes(file, new Date(now - 120000), new Date(now - 120000));
  await utimes(folder, new Date(now - 240000), new Date(now - 240000));
}
JS
```

Refresh only the left with ⌘R; its new file appears before the new folder in descending date order. The right listing remains unchanged until its own Refresh. Leave fixtures in place until cleanup is authorised.

Bilal's revision checklist:

- [x] Click Modified twice: folders/files form one chronological order in either direction, confirmed by Bilal on 2026-10-06.
- [x] Click Name twice: folders remain first with natural names in either direction, confirmed by Bilal on 2026-10-06.
- [ ] Keep both selected rows while sorting, toggling hidden entries and refreshing only the focused pane.

Bilal accepted the revision with Unit 2 as recorded below; publication is recorded above.

### Under-minute date correction (2026-10-06)

Bilal reported a just-modified folder showing an exact date instead of a now label. A2 already specifies Just now for zero through 59 elapsed seconds. The native minute timeline supplied its last scheduled tick to the formatter; Refresh could load newer timestamps, which then appeared future-dated relative to that stale clock.

Before the correction, creating a real temporary file/folder and immediately refreshing reproduced exact date labels while filesystem metadata confirmed they were only milliseconds old. After sampling the current wall clock when rendering the list, new files/folders and a modified selected file immediately show Just now. The minute timeline, wake/activation updates, raw sorting and formatter fallbacks remain unchanged. No helper or additional timer was added.

`node scripts/test.mjs` passes all 20 tests, including existing fixed-clock zero/59/60-second boundaries. `node scripts/build-app.mjs` and fresh-bundle launch pass with the recorded non-fatal CLT warnings. Native Refresh retained both selected URLs and the other pane's path/order. Without Refresh or interaction, the new file/folder and selected modified file advanced from Just now to 1 min ago, retaining exact timestamps, order and selections. The native before/after check exercises the UI clock seam; no artificial view-mirroring test was added. Light tighten kept the correction local; probe checked fresh metadata, immediate Refresh, natural ageing and selection retention. All 155 local Markdown links/anchors, six embedded fixture scripts, whitespace and generated plist lint pass.

To review with a fresh pair, first load the global-date fixture above. Paste its printed Root below, create a new file/folder after loading, then Refresh that pane:

```sh
PANEPEEK_FIXTURE_ROOT="paste the printed Root here"
node --input-type=module - "$PANEPEEK_FIXTURE_ROOT" <<'JS'
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
const pane = join(process.argv[2], 'left');
const name = `fresh-${Date.now()}`;
await mkdir(join(pane, `${name}-folder`));
await writeFile(join(pane, `${name}.txt`), 'Disposable under-minute fixture\n');
console.log(`Created ${name}-folder and ${name}.txt`);
JS
```

- [x] Fresh rows show Just now, confirmed by Bilal on 2026-10-06. Visible-selection retention through Refresh was also confirmed.
- [ ] Leave the app open: labels advance to completed minutes on the minute timer without Refresh or reordering.

## Unit 2 acceptance (2026-10-06)

Bilal said: "I see `now` fixed. All other tested features also working fine for this unit's scope". This accepts Unit 2 including hidden visibility/Refresh, global chronological Modified sorting and the native under-minute date-clock correction. T03 is done for implementation/manual acceptance.

The acceptance does not individually report every checklist outcome. Keep unreported checks unchecked and retain the OS/toolchain and appearance/wake limits. A4 remains partial until transfer-triggered refresh; A30 cross-window checks remain T16. The existing 20-test, build/launch and native evidence above preceded acceptance; acceptance-only documentation does not require another build/test run.

At acceptance, Unit 1 was committed locally and Unit 2 publication remained a separate gate. Bilal subsequently authorised commit, push and PR creation as recorded above. Merge and the next task remain unapproved; T03 is not yet on `main` and M1 is not complete.

## Unit 1 scope and acceptance

At Unit 1 acceptance, each pane had aligned clickable Name/Modified headings with an arrow beside the active heading. Switching to Name started ascending; switching to Modified started newest first. Activating the current heading reversed direction. Both fields kept folders first, with natural-name/path date ties and unknown dates last within each group. The approved global Modified revision above supersedes that grouping rule. Packages and links have distinct icons, and directory links retain canonical navigation.

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

Bilal also identified the reported popups as protected-folder permission requests. See [the permission note](../notes/0004-protected-folder-permissions.md). No privacy choice was made by the agent; startup prompt timing is a separate follow-up.

## Header alignment correction (2026-10-06)

Bilal requested that Modified remain stationary when its sort arrow appears. The arrow now precedes the right-aligned label; Name retains its trailing arrow. This corrects the approved presentation revision in `BrowserWindow.swift` without changing sorting behaviour.

The bundle build and fresh-executable launch passed. Native screenshots were inspected with Modified inactive, ascending and descending: the label stays fixed and the arrow appears to its left. Selected `file2.txt` and the other pane's selected `kept.txt`, directory and sorting survived each change. Tighten kept the existing header helper and one arrow; probe checked both arrow directions, inactive alignment and independent selection. Whitespace passes. No new behaviour tests were needed for this layout correction; the earlier 16-test result remains the automated evidence.

At the correction checkpoint, the app was running on the same temporary review fixture, left Modified ascending and right Modified descending, with both selections intact. Bilal's later acceptance is recorded below.

## Unit 1 acceptance (2026-10-06)

Bilal said "approved now, commit unit 1" after reviewing the stationary Modified correction. This accepts the sorting unit including the column-header/relative-date revision and authorises its local commit on `bcinarli/t03-sorting-hidden-visibility`.

The approval does not individually report every manual checklist outcome. Keep those boxes unchecked where no result was supplied and retain the runtime limits above. A2/A30 remain partially validated. Unit 2 was subsequently authorised as recorded below; source-control approvals remain separate.

## Unit 2 hidden visibility and Refresh

Bilal instructed "continue to unit 2" on 2026-10-06 after accepting and committing Unit 1. The existing `bcinarli/t03-sorting-hidden-visibility` branch was clean at `f796596`, with T02 present on `main`. This approves A4's independent hidden visibility/manual Refresh slice, with A1/A3/A30 regressions. Transfers, watchers, later tasks and privacy/packaging source changes remain outside it.

Directory actions and the View menu expose Show Hidden Files (⌘⇧.) and Refresh (⌘R) for the focused pane. Each pane hides dot-prefixed and filesystem-hidden entries by default. Toggling filters its current cached listing immediately; Refresh rereads the displayed directory. Both retain sorting and visibility. Visible selected URLs stay selected; a hidden or removed URL clears its selection. The other pane is unaffected.

Same OS/toolchain as the original unit below. No macOS 26 runtime claim.

| Check | Executed result |
| --- | --- |
| Intentional red | `node scripts/test.mjs` with compiling minimal declarations recorded eight intended expectation failures across four new tests. All original 16 tests passed. Hidden-flag fixture setup succeeded. |
| Green | `node scripts/test.mjs` passed all 20 tests in two suites. Real filesystem tests cover dot/metadata-hidden files, hidden folders, independent visibility/navigation settings and newly added items after Refresh. Controlled reads cover settings/focus changed during a pending Refresh, permission failure retention and later recovery. Existing stale navigation success/error tests exercise the reused request guard. |
| Build/launch | `node scripts/build-app.mjs` passed with existing non-fatal CLT linker search-path warnings. The previous generated executable was preserved before rebuilding; the fresh bundle launched. No signing/bundler source change. |
| Native visibility | Directory actions and ⌘⇧. revealed `.dot.txt`, `.hidden-folder` and metadata-hidden `flagged.txt` only in the focused left pane. The right pane retained its path, selected `kept.txt`, visibility and sorting. |
| Native selection | Visible `kept.txt` stayed selected through hiding/revealing and Refresh. Hiding selected `flagged.txt` cleared selection; revealing again did not restore it. Renaming a selected fixture file on disk cleared its old URL after Refresh. |
| Native Refresh | Adding `new10.txt` and `.new-hidden.txt` to both fixture directories, then ⌘R, updated only the left listing in Modified descending order. Directory actions → Refresh updated the right listing while its hidden setting remained off. Both selected URLs were retained. |
| Native error/recovery | Temporarily moving the left fixture directory caused a visible Refresh error with rows, selected URL, sorting and visibility intact. Restoring the directory and refreshing cleared the error. Fixture directory and filename were restored afterwards. |
| Empty-pane focus/navigation | In the right empty directory, ⌘⇧. and ⌘R retained its focus cue and No items state. Command-Up returned to its parent with hidden entries visible and sorting retained. Toggling off there left the left pane unchanged. |
| Presentation | Native dark layout and View-menu command presence inspected. At this checkpoint the app was running with hidden items shown on the left, hidden on the right, Modified descending in both panes and `kept.txt` selected in each. |
| Documentation/fixture | Both published Unit 2 fixture steps executed; metadata-hidden flags and newly added files verified in each directory. Three embedded scripts parse, all 154 local Markdown links/anchors and `git diff --check` pass. Generated Info.plist lint passes and declares minimum macOS `26.0`. |

Tighten kept one authoritative sorted listing and reused the existing loader, navigation guards and native selection. Local toolbar/menu bindings share the same pane state. Probe checked hidden metadata, late settings, error recovery and the real focus/selection seam. No blocker was observed in the exercised paths. Bilal subsequently confirmed the View hidden-file toggle and both shortcuts. Direct View Refresh activation, light appearance and resizing remain unreported; keyboard commands and toolbar-menu activation were exercised. No privacy settings changed.

A4 stays partially validated: transfer-triggered refresh belongs to later tasks. Unit 2 manual acceptance is recorded above; no commit, push or next-task approval is inferred. T03 does not complete M1.

### Unit 2 disposable fixture

Use the build/run instructions below. Create a fresh fixture:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, utimes, realpath } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const root = await realpath(await mkdtemp(join(tmpdir(), 'panepeek-visibility-')));
for (const pane of ['left', 'right']) {
  await mkdir(join(root, pane));
  await mkdir(join(root, pane, 'empty'));
  await mkdir(join(root, pane, '.hidden-folder'));
  for (const name of ['kept.txt', '.dot.txt', 'flagged.txt']) {
    await writeFile(join(root, pane, name), 'Disposable visibility fixture.\n');
  }
  execFileSync('chflags', ['hidden', join(root, pane, 'flagged.txt')]);
  for (const [name, age] of [['kept.txt', 1800], ['.dot.txt', 1200], ['flagged.txt', 600]]) {
    const date = new Date(Date.now() - age * 1000);
    await utimes(join(root, pane, name), date, date);
  }
}
console.log(`Root: ${root}\nLeft: ${join(root, 'left')}\nRight: ${join(root, 'right')}`);
JS
```

Focus each pane and use ⌘L to enter its printed path. Select `kept.txt` in both panes. Show hidden files on the left and keep them hidden on the right. To test an external change, paste the printed Root into the variable below and add files to both directories:

```sh
PANEPEEK_FIXTURE_ROOT="paste the printed Root here"
node --input-type=module - "$PANEPEEK_FIXTURE_ROOT" <<'JS'
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';
const root = process.argv[2];
for (const pane of ['left', 'right']) {
  for (const name of ['new10.txt', '.new-hidden.txt']) {
    await writeFile(join(root, pane, name), 'Added after initial navigation.\n');
  }
}
JS
```

Refresh only the left pane: both new rows appear there; the right listing stays unchanged until its own Refresh. Leave these temporary fixtures in place until cleanup is authorised.

### Bilal's Unit 2 manual checklist

- [x] Show Hidden Files works through Directory actions, View and its shortcut, confirmed by Bilal on 2026-10-06.
- [x] Refresh reloads the focused pane and its shortcut works, confirmed by Bilal on 2026-10-06.
- [ ] Confirm dot/metadata-hidden entries appear only in the focused pane and the other pane retains its selection/sort/path.
- [x] A visible selected row remains selected while toggling hidden files or refreshing, confirmed by Bilal on 2026-10-06.
- [x] Hiding a selected hidden row leaves no row selected, confirmed by Bilal on 2026-10-06. The pane retains focus; no first row is selected automatically.
- [ ] Reveal that hidden row again; it should return without a selection.
- [ ] Add the refresh fixtures above; test ⌘R and View → Refresh. Check new rows, independent listings and retained sorting/visibility.
- [ ] Open `empty`, try ⌘⇧./⌘R, then Command-Up. Confirm the focus cue and per-pane visibility survive.
- [ ] Check error/recovery after temporarily moving the disposable directory, and inspect the menu in light/dark appearance and a narrower window.

Unit 2 is accepted. Unchecked items have no individual result reported by Bilal. Commit/push approval and publication are recorded above; merge remains separate.

## Original unit checks (2026-10-05)

macOS 27.0.1 (26A434), arm64; Swift 6.4, macOS SDK 27.0; Node.js 26.1.0. Runtime on macOS 26 and the minimum tool versions remains untested.

| Check | Command or fixture | Result |
| --- | --- | --- |
| Intentional red | `node scripts/test.mjs --filter DirectoryBrowsingTests` with compiling metadata/sort declarations | Four added tests failed on 22 intended expectations: metadata/link/package values, all four orders, path ties and latest pane settings. The original seven tests passed. |
| Green | Same targeted command after the core implementation | All 11 tests passed, including four sort combinations and two stale-result cases. |
| Final suite | `node scripts/test.mjs` after tightening | All 11 tests passed. |
| Bundle build | `node scripts/build-app.mjs` | Passed, including the final numeric-date/accessibility UI. Existing CLT linker search-path warnings were non-fatal. |
| Launch | Rebuilt `.build/PanePeek.app` | Final app launched after [fresh executable recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery). The preceding in-place rebuild was rejected with an invalid signature; no signing or bundler source change was made. |
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

- [ ] Click Name/Modified; check that Modified stays stationary, first-click defaults, repeated-click reversal, folders-first Name and global dates with natural timestamp ties.
- [ ] Keep a row selected while reordering; confirm the other pane retains its path, selection and sorting.
- [ ] Inspect relative/older exact dates and full hover timestamps; wait a minute and resume after sleep to check label updates.
- [ ] Inspect package/link distinction and canonical directory-link navigation.
- [ ] Check empty and failed navigation with sort settings retained.
- [ ] Use keyboard focus/Space for both column headings and their direction changes.
- [ ] Check light/dark appearance and narrow/wide pane resizing, including long names and dates.

Both units and their revisions are accepted, committed and pushed in PR #5. Merge and later coding units remain separate approvals.
