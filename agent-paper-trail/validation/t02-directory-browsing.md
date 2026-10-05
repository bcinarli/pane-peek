# T02 directory browsing validation

Status: T02's original units are accepted. Bilal accepted Unit 1 navigation/typography and Unit 2 breadcrumbs on 2026-10-05. The [PR shortcut cleanup](#pr-shortcut-cleanup-2026-10-05) passed build/native checks; its manual confirmation is pending. Unit 1 is committed as `a093587`, Unit 2 as `682b55d`; the branch is pushed and [PR #4](https://github.com/bcinarli/pane-peek/pull/4) is open against `main`. Merge and later tasks retain separate gates. Unreported manual checks remain distinct from agent evidence.

## Unit 1 scope

Two independent directory listings initially at Home, folder chooser, Go to Folder/Command-L with absolute paths, per-pane Home, shared Enclosing Folder/Command-Up, directory double-click, native single-row selection/Return and a thin focused-pane underline. Shared actions capture their target before asynchronous work. Failed navigation retains the last successful directory/list; older success/error results cannot replace newer navigation. File reads run off the main actor.

Unit 1 showed current paths in compact headers; Unit 2 adds clickable root/ancestor breadcrumbs and long-path scrolling below. Modified-time/sort controls, multiple selection, favourites and Details content remain in their mapped tasks. Packages are not browsable. Successful directory-link navigation displays the canonical target under [decision 0005](../decisions/0005-finder-directory-symlink-navigation.md). Hidden items use the initial hidden-by-default listing policy; per-pane visibility controls remain T03.

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

- A1: navigation/focus/independence and breadcrumbs accepted, with automated and native evidence below.
- A2: partial for listing, file/folder distinction, initial order and empty state. Last-modified values and sort controls remain T03.
- A3: automated error-retention/stale-result coverage and visible native errors are recorded. Bilal confirms invalid/broken-link errors and retained navigation state. Controlled delayed reads exercise sequencing without requiring a slow mounted volume; T02 review is accepted.
- A29: Home, canonical directory-link navigation and breadcrumbs accepted. Stars and dirty guards remain T15/T07.
- Tighten: reused the existing native pane/sidebar, retained concrete listing/state types, removed an unused navigation wrapper and captured targets/parent paths before starting tasks. The test helper adds only the required local macro search path.
- Probe: checked real symlink/package reads, stale success/error ordering, focus across toolbar/dialog use, native shortcuts, error retention, copied asset/package paths and runtime dependencies. Native review corrected the parent shortcut, accessible menu name and Return activation. The list's native primary action now handles both double-click and Return. No exercised-path blocker remains; unexecuted checks stay explicit.
- T02 implementation/manual acceptance is complete and its commit/push/PR publication is authorised. M1 has not reached its quality checkpoint.

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
- [x] Presented navigation and typography results accepted. Unit 2 is also accepted below.

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

## Unit 2: breadcrumbs

Approval: Bilal authorised implementation and accepted the manual result on 2026-10-05. Status: accepted. Added distinct Home and `/` controls, clickable ancestors from the canonical directory and horizontally scrollable long paths. Retained the accepted `.body` text, aligned 44-point pane/Details headers and existing navigation/error/focus behaviour. Favourite stars and dirty guards remain T15/T07.

Code surfaces: `sources/panepeek/BrowserWindow.swift`, a derived ancestor-path property in `sources/panepeek-core/BrowserState.swift` and `tests/panepeek-core/DirectoryBrowsingTests.swift`. Buttons reuse the existing pane navigation. No new filesystem service or stored breadcrumb state.

Coverage: A1 breadcrumb navigation and A29 root/ancestor/long-path presentation. Full A29 still spans later favourites/dirty-guard tasks. Environment is unchanged from Unit 1.

| Check | Command or observation | Result |
| --- | --- | --- |
| Red | `node scripts/test.mjs --filter DirectoryBrowsingTests` against a compiling empty breadcrumb property | Three intended assertions failed: root, exact space/Unicode/reserved-character ancestor URLs and canonical link ancestry. Five other tests passed. |
| Green | Same targeted command after implementation and final review | Seven tests passed, including both stale-completion variants. |
| Build/launch | `node scripts/build-app.mjs`; quit and relaunch the bundle after each UI correction | Final build passed with existing non-fatal CLT linker warnings; final app launched. |
| Home/root | Native controls | `/` opened the filesystem root with a single root breadcrumb; Home returned to the home directory. |
| Ancestors/independence | Long linked-directory fixture; click `project space` | Correct canonical ancestor opened. The right directory and selected `kept.txt` remained unchanged. |
| Horizontal access | Native Scroll Left/Scroll Right accessibility actions | Scroll position moved from 1 to 0 and back to 1. All components expose named buttons and full paths, including spaces/Unicode. |
| Layout | Native dark screenshots with short and long paths | Short paths sit beside Home; long paths reveal the current component. Both location rows and Details remain aligned. Bilal's subsequent screenshot caught the native scrollbar obscuring labels; the correction below reserves space beneath them. |
| Errors/recovery | Submit a missing path, then the valid directory link | Error retained canonical breadcrumbs, listing and other-pane selection; valid navigation cleared it. |
| Documentation/whitespace | Changed Markdown local links and `git diff --check HEAD` | Passed. |

Tighten kept the ancestor list derived from the existing directory and reused navigation without wrappers or duplicate state. Probe checked root, literal URL components, canonical link ancestry, failure retention, stale results and native independent pane state. No new behaviour test was added for layout.

### Scrollbar and keyboard review follow-up, 2026-10-05

Bilal confirms Home versus `/` and ancestor clicks work. His screenshot showed the horizontal scrollbar covering the labels, and he reported Tab skipping breadcrumb buttons while Return acted on the list.

The corrected header reserves 16 points below the breadcrumb labels inside a fixed-height scroll content area. Home and Details receive matching spacing so their labels align. Native scrollbar and accessibility scroll actions remain available. `node scripts/build-app.mjs` passed; the relaunched app was checked with short and long paths. Native Scroll Left/Right moved from 1 to 0 and back to 1, with the active scrollbar visibly below readable labels. Clicking `project space` navigated only that pane and retained the other pane's selected `kept.txt`. No behaviour code changed or additional behaviour tests were needed; the earlier seven-test green result remains the automated evidence.

A read-only inspection of System Settings initially confirmed Keyboard navigation was off. Tab skipping native buttons matches [Apple's documented focus behaviour](https://developer.apple.com/videos/play/wwdc2023/10162/). With Keyboard navigation enabled, Tab/Shift-Tab focus buttons and Space activates them. The app retains native button behaviour; the agent changed no system setting. Bilal subsequently confirmed keyboard navigation and Space activation work.

Tighten retained local spacing modifiers and existing native controls. Probe rejected hiding indicators because that removed native accessibility scroll actions, then verified visible scrollbar separation, both scroll endpoints, short-path alignment and independent navigation in the final bundle. Bilal subsequently accepted the corrected scrolling, keyboard activation, light/dark appearance and resizing.

### Unit 2 fixture and manual checklist

Use the build/run instructions above. Create an isolated fixture; the command prints its root and linked path for Command-L:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = await mkdtemp(join(tmpdir(), 'panepeek-breadcrumbs-'));
const long = join(root, 'project space', '資料 ü#%',
  'a long directory component for breadcrumb scrolling',
  'another long component with readable native text', 'deepest');
await mkdir(long, { recursive: true });
await mkdir(join(root, 'right'));
await mkdir(join(root, 'aliases'));
await writeFile(join(long, 'inside.txt'), 'Disposable breadcrumb fixture.\n');
await writeFile(join(root, 'right/kept.txt'), 'Disposable breadcrumb fixture.\n');
const link = join(root, 'aliases/linked');
await symlink(long, link);
console.log(JSON.stringify({ root, link }, null, 2));
JS
```

- [x] Home and `/` open different locations; ancestor clicks work.
- [x] Corrected scrollbar and breadcrumb visibility reviewed.
- [x] Keyboard navigation works; Space activates the focused item.
- [x] Light/dark appearance and resizing work.
- [x] Unit 2 manual result accepted on 2026-10-05; commit, branch push and PR creation subsequently authorised. Merge remains a separate gate.

Full-path tooltips/accessibility and independent other-pane selection have agent evidence above. Bilal's feedback specifically confirms the checked items; it does not claim every agent check was repeated manually. No additional tests or build were run to record acceptance.

## PR shortcut cleanup, 2026-10-05

Bilal authorised removing the duplicate toolbar Command-Up declaration, then committing and pushing the cleanup. The Go menu command now owns the shortcut; the toolbar Enclosing Folder action remains clickable.

`node scripts/build-app.mjs` passed with the existing non-fatal CLT linker warnings. The rebuilt bundle was relaunched. Native checks confirmed Command-Up opens one parent in either focused pane, the toolbar parent action still works, both parent commands are disabled at `/`, and switching to the other pane re-enables its parent navigation. Left navigation preserved the right directory and selected row. Both original directories and the right selection were restored afterwards.

Tighten kept the source change to removing one modifier. Probe exercised shortcut ownership, toolbar activation, root disabling and focus switching. No core behaviour or tests changed; the preceding seven-test green result remains the behaviour-suite evidence. Use the existing build/run and fixture instructions above. Bilal's manual confirmation of this cleanup remains pending: check Command-Up and the toolbar parent action.
