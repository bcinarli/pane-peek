# T02 directory browsing validation

Status: Bilal accepted the presented navigation and typography results on 2026-10-05, including canonical path entry, target-parent navigation and broken-link retention/other-pane selection. T02 remains in review; breadcrumb implementation, commit and push require separate approval. Unreported manual checks remain distinct from agent evidence.

## Unit 1 scope

Two independent directory listings initially at Home, folder chooser, Go to Folder/Command-L with absolute paths, per-pane Home, shared Enclosing Folder/Command-Up, directory double-click, native single-row selection/Return and a thin focused-pane underline. Shared actions capture their target before asynchronous work. Failed navigation retains the last successful directory/list; older success/error results cannot replace newer navigation. File reads run off the main actor.

Current paths are shown in compact headers. Clickable root/ancestor breadcrumbs and long-path presentation remain in Unit 2, which requires separate approval. Modified-time/sort controls, multiple selection, favourites and Details content remain in their mapped tasks. Packages are not browsable. Successful directory-link navigation now displays the canonical target under [decision 0005](../decisions/0005-finder-directory-symlink-navigation.md). Hidden items use the initial hidden-by-default listing policy; per-pane visibility controls remain T03.

## Environment and executed checks

macOS 27.0.1 (26A434), Apple Silicon, Swift 6.4, Command Line Tools with SDK 27.0, Node.js 26.1.0. Bundle/executable minimum macOS remains 26.0. Runtime testing on macOS 26 and minimum documented Swift/Node versions has not been performed.

| Check | Command or observation | Result |
| --- | --- | --- |
| Intentional red | `swift test` with the installed Testing plugin search path and `--filter DirectoryBrowsingTests`, against compiling behaviour stubs | Six tests failed with 26 behaviour expectations, including listing, failed navigation, pane/focus independence and stale completions. One test has success/error completion variants. |
| Green after implementation/tighten | `node scripts/test.mjs --filter DirectoryBrowsingTests` | Six tests passed, including both stale-completion variants. |
| Initial filesystem seam | Directory-link/package fixture, before decision 0005 | Initial implementation exposed a Foundation enumeration failure; the corrected read then preserved entered link paths. That path policy is superseded by the follow-up below. The URL assertion checks the Unix path rather than an incidental directory-hint suffix. |
| Build/package | `node scripts/build-app.mjs` after native command/accessibility/activation fixes | Passed; lowercase package/asset paths produce `.build/PanePeek.app`. Existing non-fatal CLT linker search-path warnings remain. |
| Support scripts | `node --check` on build, icon-export and test scripts | Passed. Icon artwork/export was not regenerated. |
| Bundle metadata/dependencies | `plutil -lint`, `vtool -show-build`, `otool -L` on the browsing bundle | Passed; minimum macOS 26.0 and system-only runtime dependencies. No separate core framework is needed in the bundle. |
| Paths/assets/docs | Physical directory names, Git rename casing, icon byte comparison, changed Markdown local links and `git diff --check HEAD` | Passed. Original icon, lowercase asset and bundled copy are identical. |
| Native controls/focus | Running app and accessibility tree | Distinct named panes, empty-selection focus targeting, named shared actions, Command-L and registered Command-Up verified. The initial toolbar-only parent shortcut was corrected through scene commands. |
| Initial native navigation | Separate disposable left/right directories | Chooser changes only its captured pane; cancellation preserves both locations. Double-click, Return, Home, parent and empty state work. Right row selection survives left directory navigation. Link-path checks preceded decision 0005; current checks are below. |
| Native failures/recovery | Submit missing and regular-file paths through Command-L | Visible error retains the previous directory/list; subsequent valid navigation clears it. |
| Native appearance | Agent dark window/screenshot; Bilal's light/dark and resizing review | Focus underline and both lists beside Details verified. Bilal reports light/dark appearance and resizing work. The two header font changes below are accepted at both display settings. |

The initial sandbox cache failure, missing Testing macro search path and native-builder missing Testing module were setup failures, not red behaviour evidence. The test runner derives the installed plugin path from `xcrun`. The SDK's `State` macro is unavailable in the selected CLT; a private alias selects the existing property wrapper. No tool installation or Xcode-project fallback was needed.

## Acceptance and self-review

- A1: partial for Unit 1 navigation/focus/independence; the breadcrumb unit remains pending.
- A2: partial for listing, file/folder distinction, initial order and empty state. Last-modified values and sort controls remain T03.
- A3: automated error-retention/stale-result coverage and visible native errors are recorded. Bilal confirms invalid/broken-link errors and retained navigation state. Controlled delayed reads exercise sequencing without requiring a slow mounted volume; full T02 review remains pending.
- A29: Home and canonical directory-link navigation groundwork. Breadcrumbs, stars and dirty guards retain their mapped gates.
- Tighten: reused the existing native pane/sidebar, retained concrete listing/state types, removed an unused navigation wrapper and captured targets/parent paths before starting tasks. The test helper adds only the required local macro search path.
- Probe: checked real symlink/package reads, stale success/error ordering, focus across toolbar/dialog use, native shortcuts, error retention, copied asset/package paths and runtime dependencies. Native review corrected the parent shortcut, accessible menu name and Return activation. The list's native primary action now handles both double-click and Return. No exercised-path blocker remains; unexecuted checks stay explicit.
- T02 is not complete and M1 has not reached its quality checkpoint.

## Run and disposable fixture

From the repository root, quit the running app before rebuilding:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Create an isolated fixture. The command prints its root; use its `left` and `right` directories in the chooser or Command-L. It never writes to working directories or preferences.

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-browsing-'));
for (const name of ['left/nested', 'left/empty', 'left/Sample.app', 'right']) {
  await mkdir(join(root, name), { recursive: true });
}
for (const name of ['left/file2.txt', 'left/file10.txt', 'left/nested/inside.txt', 'right/notes ü.txt']) {
  await writeFile(join(root, name), 'Disposable browsing fixture.\n');
}
await symlink(join(root, 'left/nested'), join(root, 'left/linked'));
console.log(root);
JS
```

## Bilal's manual checklist

- [x] Switch panes without selecting a row.
- [x] Command-L: valid directory browses; missing directory shows an error; cancellation retains the current location.
- [x] Nested and linked directories open; Return opens a selected directory.
- [x] Command-Up opens the parent; Home opens the home directory.
- [x] Navigation, opening and going back feel fast.
- [x] Light/dark appearance and resizing work.
- [ ] Confirm fixture ordering/file distinction, chooser targeting and empty/regular-file errors. These have agent evidence but were not explicitly reported in Bilal's feedback.
- [x] Header readability accepted at both Default and More Space settings.
- [x] Canonical directory-link navigation, target parent and broken-link retention/other-pane selection reviewed and accepted.
- [x] Presented navigation and typography results accepted. Breadcrumb Unit 2 retains its own approval checkpoint.

### Header readability follow-up, 2026-10-05

Bilal reported that the path text and Details title felt small at both 1800×1169 and the default 1512×982 display setting. Both used SwiftUI's `.caption` style. Bilal then authorised trying `.body` or other appropriate native text styles.

The change uses `.body` for the directory path and `.headline` for the Details section title in `sources/panepeek/BrowserWindow.swift`. Only those two font modifiers changed in application code. `node scripts/build-app.mjs` passed; the rebuilt app was launched and inspected with the disposable left/right fixtures. In the native dark window, text is larger and the headers remain aligned without clipping. The full directory path remains available through its tooltip/accessibility value. Bilal accepted the sizes at both Default and More Space settings.

Tighten retained two direct semantic font modifiers. Probe checked the native result, header alignment and full-path access. This is a layout change: no artificial behaviour test was added and the previously passing browsing suite was not rerun.

### Finder comparison, 2026-10-05

On the recorded macOS version, the agent tested a real directory symlink in Finder using both double-click and Go to Folder. Both routes followed the target; Command-Up opened the target's parent rather than the link's parent. The comparison used a separate Finder window, which was closed afterwards.

Bilal subsequently selected Finder's behaviour explicitly. [Decision 0005](../decisions/0005-finder-directory-symlink-navigation.md) supersedes the earlier entered-path requirement in A29. Selected link identity and file-operation/metadata policies are unchanged.

### Finder-style navigation follow-up

The off-thread listing read returns its resolved directory and entries together. A pane accepts both only for its latest successful request. Parent navigation therefore uses the target's ancestry; a failed link retains the last successful directory/list. Entries in a parent listing still identify the links themselves.

| Check | Observation | Result |
| --- | --- | --- |
| Red | Expanded the real symlink fixture with distinct alias/target parents before changing implementation. Ran `node scripts/test.mjs --filter DirectoryBrowsingTests`. | One test failed on five expected location/entry/parent assertions; the other five tests passed. |
| Green | Same targeted suite after implementation and path correction. | All six tests passed, including both stale-completion variants. Coverage includes path and URL entry, canonical child paths/parent, listed link identity and broken-link retention. |
| Foundation path seam | The first canonical implementation returned `/var` for the directory but `/private/var` for enumerated children. | Two assertions caught the mismatch. Rebasing children on the returned canonical directory fixed it. |
| Build/launch | `node scripts/build-app.mjs`; launched the rebuilt bundle. | Passed with the existing non-fatal CLT linker warnings. |
| Native real link | Go to Folder with a real user directory link, then Command-Up. | Canonical target shown; target parent opened. |
| Native fixture | Double-click `aliases/linked`, Command-Up; submit `aliases/broken`, then a valid link through Command-L. | Target directory and target parent shown. Broken link retained the parent listing with a visible error; valid navigation cleared the error. Right directory and selected `kept.txt` remained unchanged throughout. |

Tighten retained one concrete listing result and the existing navigation/UI flow. Probe checked the canonical path seam, broken targets, link identity, stale success/error results and independent native pane state. No further exercised-path blocker was found. Bilal subsequently reviewed all three presented checks and confirmed the result below.

Create a disposable follow-up fixture; the command prints its root. Foundation can display the equivalent `/tmp` spelling for a `/private/tmp` fixture.

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-finder-'));
for (const name of ['aliases', 'targets/destination', 'right']) {
  await mkdir(join(root, name), { recursive: true });
}
await writeFile(join(root, 'targets/destination/inside.txt'), 'Disposable fixture.\n');
await writeFile(join(root, 'right/kept.txt'), 'Disposable fixture.\n');
await symlink(join(root, 'targets/destination'), join(root, 'aliases/linked'));
await symlink(join(root, 'missing'), join(root, 'aliases/broken'));
console.log(root);
JS
```

Manual follow-up:

- [x] Command-L through a directory link displays the canonical target.
- [x] Command-Up opens the target's parent.
- [x] A broken-link error retains the current directory and the other pane's selection.

The fixture can reproduce these checks using `aliases/linked`, its `targets` parent and `aliases/broken`. Double-click activation and valid-link recovery have agent evidence; Bilal's report specifically confirms the three checks above.

## Proposed Unit 2: breadcrumbs

Approval: pending. Add distinct Home and `/` controls, clickable ancestors from the canonical directory and horizontally scrollable long paths. Retain the accepted `.body` text, aligned pane/Details headers and existing navigation/error/focus behaviour. Favourite stars and dirty guards remain T15/T07.

Expected code surfaces: `sources/panepeek/BrowserWindow.swift`, a small ancestor-path helper in `sources/panepeek-core/BrowserState.swift` and `tests/panepeek-core/DirectoryBrowsingTests.swift`. Reuse the existing pane navigation, with no filesystem or layout redesign.

Coverage: A1 breadcrumb navigation and A29 root/ancestor/long-path presentation. Observe red/green for root, exact ancestor URLs with spaces/Unicode and canonical link ancestry. Reuse the existing navigation/failure suite; build and inspect the native header for scrolling, keyboard/accessibility, alignment and independent pane targeting.

Visible manual result: Home and root remain distinct; ancestor clicks navigate only their own pane; long components remain reachable by scrolling and keyboard; both headers stay aligned during light/dark resizing. Stop for manual acceptance after this unit. No unresolved decision changes the proposed scope.
