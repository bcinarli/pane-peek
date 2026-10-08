# T15 persistent favourites validation

Status: Bilal accepted T15 on 2026-10-08, confirming all five Unit 1 manual checks and the restored standard native toolbar buttons. Implementation `249370a` was committed/pushed with explicit approval in [PR #8](https://github.com/bcinarli/pane-peek/pull/8), which merged into `main` as `5dddcd2`.

## Unit 1 scope

Application-owned favourites, per-pane breadcrumb stars, shared toolbar and menu-bar Favourites menus, local persistence, equivalent-path identity and stale-path retention. Both menus use the same contents and capture the focused pane before invoking existing navigation. Star toggles retain focus, navigation and selection.

This covers the single-window portion of [A16](../specs/001-mvp/spec.md#favourites-and-context-menus) and stars in [A29](../specs/001-mvp/spec.md#breadcrumbs-and-sorting). Both criteria remain partial: dirty-document guards belong to T07 and shared windows to T16. Directory-pair restoration remains T17.

## Executed checks

Environment: macOS 27.0.1 (26A434), Apple Swift 6.4, macOS SDK 27.0 and Node 26.1.0 on Apple Silicon. Deployment minimum remains macOS 26. No macOS 26 run is claimed.

| Check | Result |
| --- | --- |
| Dependency/branch | T14 PR #7 verified closed/merged into `main` at `a58e518`; local/live `main` agree and contain `dd98d1f`. Created `bcinarli/t15-persistent-favourites` from clean current `main` after approval. |
| Intentional red | `node scripts/test.mjs --filter FavouritesTests` compiled with minimal stubs and failed five expectations across two behaviour scenarios: persisted/normalised lookup and actual favourite navigation/error state. The earlier sandbox compiler-cache failure is not behavioural red. |
| Final green | `node scripts/test.mjs`: all 29 tests in five suites pass after tightening the two new scenarios. No third-party dependencies or framework-mechanics tests added. |
| Build/package | Final `node scripts/build-app.mjs` succeeds. `plutil -lint .build/PanePeek.app/Contents/Info.plist` passes. Known CLT linker search-path warnings are non-fatal. |
| Native launch/relaunch | Final bundle launches. A real quit was confirmed through app inventory; relaunch retained saved paths, including the unavailable entry. |
| Shared stars | Two panes displaying the same directory both showed Saved. Toggling the inactive pane's star updated both, retaining both selections, focused pane and Details item. Re-adding produced one shared menu entry. |
| Menu/navigation | Toolbar menu navigated the focused empty pane while retaining the other pane's selection. Menu-bar Favourites navigated the other focused pane without changing its neighbour. Navigating an alias displayed the canonical target; saving used that target path. |
| Missing favourite | Saved a disposable directory, navigated away and renamed only that fixture directory. Opening its saved path showed an error while retaining the previous directory, listing and selection. The entry remained in the menu and after relaunch. |

The final automated scenarios cover:

- Persistent add/remove across store instances, canonical displayed identity from a real directory link, lexical equivalence and stale-entry reload. Preferences use a unique suite with cleanup.
- The actual favourite-navigation entry point capturing focus before its task starts, leaving the other pane unchanged, and retaining the selected listing after a real missing-directory failure.

Existing navigation/selection tests remain the regression coverage for their established transitions. Native star observation and menu targeting are checked in the app. A disconnected-store assertion was removed during tightening; stale retention is exercised at preference reload and in the native menu workflow instead.

## Reproduce the review

From the repository root, quit PanePeek before rebuilding:

```sh
node scripts/test.mjs
node scripts/build-app.mjs
open .build/PanePeek.app
```

If an in-place rebuilt executable is rejected, use the documented [generated-executable recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery). The agent preserved previously launched generated executables while preparing this review; no bundler change was made.

Create a disposable fixture and copy its printed paths into Go to Folder (Command-L):

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
const root = await mkdtemp(join(tmpdir(), 'panepeek-favourites-review-'));
const saved = 'shared ü with spaces and a long directory name for the breadcrumb star';
for (const folder of ['left', 'right', saved, 'missing']) {
  await mkdir(join(root, folder));
}
for (const file of ['first.txt', 'second.txt']) {
  await writeFile(join(root, 'left', file), 'Disposable favourite review fixture.\n');
}
await symlink(join(root, saved), join(root, 'alias'));
console.log(root);
for (const folder of ['left', 'right', saved, 'alias', 'missing']) {
  console.log(join(root, folder));
}
JS
```

Save `missing` with its star while it exists, then return to `left` and select a file. Rename only that disposable fixture to reproduce unavailability, replacing the example root below:

```sh
node --input-type=module <<'JS'
import { rename } from 'node:fs/promises';
const root = '/absolute/path/to/the/printed/fixture';
await rename(`${root}/missing`, `${root}/moved`);
JS
```

The agent's prepared fixture already has that rename applied; the saved `missing` entry is available for an immediate failure check. Preserve the fixture until review is complete. Automated tests never use the application's real preference domain; manual star actions use the app's normal local preferences.

## Bilal's manual checklist

- [x] Toggle stars with a selection; display the same directory in both panes and confirm both stars update. Toggling the inactive pane must retain focus and the Details item.
- [x] Switch focus and open a favourite from each menu, including with an empty listing/selection. Only the target pane changes.
- [x] Navigate through `alias`, save the canonical path and revisit it directly. Confirm one favourite and matching stars.
- [x] Quit/relaunch and revisit a saved path. Open `missing`: retain the old listing/selection, show an error and keep the saved entry.
- [x] Check outline/filled Mauve stars, long breadcrumbs, light/dark appearance and narrow window layout. Check keyboard activation of stars and menu entries with native Keyboard navigation enabled.

Bilal confirmed each of the five presented manual checks as OK on 2026-10-08. This accepts Unit 1, including light/dark appearance, narrow layout and keyboard activation. The inaccessible-directory case shares existing navigation error handling; no separate denied-permission native check is claimed.

## Toolbar pill-shape follow-up

Bilal requested pill-shaped Favourites and Directory actions toolbar menus after finding their circular shape uneven with the disclosure arrows. The direct request authorises this presentation-only follow-up. Retain native menu styling, actions and accessibility; Go to Folder keeps its existing circular shape. Validate by building and inspecting the running app, without new behaviour tests or fixtures.

The attempted change used a local layout container and 56-point width around each menu. Native inspection showed matching idle pills with their disclosure arrows. Both menus opened with their existing contents and accessibility labels. The app build, launch, Info.plist lint and whitespace checks passed. No new tests were added or rerun for this presentation-only change; Unit 1's 29-test green result stands above.

Standard tighten removed ineffective border-shape/label-sizing modifiers and retained only the layout containers. Light probe checked idle rendering, menu opening and accessible labels. It missed the interaction-state mismatch found below. Bilal's restoration request supersedes the pill checklist.

### Manual finding, 2026-10-08

Bilal found the pill geometry satisfactory but reported a shade difference during use and challenged the undisclosed workaround. The light screenshot shows a narrower active highlight inside the widened outer pill. The prior native checks establish idle proportions and menu opening only; they did not validate matching interaction-state appearance. The follow-up is not accepted.

Apple documents that [SwiftUI's capsule modifier](https://developer.apple.com/documentation/swiftui/buttonbordershape/capsule) has no effect on non-widget macOS system buttons. AppKit exposes [button border shapes](https://developer.apple.com/documentation/appkit/nsbutton/bordershape), including capsules, but their integration in this toolbar has not been verified. No claim that native pills are impossible is justified. Explain the options before further implementation: restore standard toolbar controls, or scope a native-control feasibility unit. No UI code changed after this feedback.

### Standard native restoration, 2026-10-08

Bilal selected "restore the standard native buttons". Removed both layout wrappers, forced widths and the wrapper-intent comment. Standard menu labels, contents, accessibility/help and accepted favourites behaviour are retained. No AppKit experiment was performed.

`node scripts/build-app.mjs` succeeds; the rebuilt app launches and remains running. Info.plist lint and whitespace checks pass. Native inspection confirms the original standard button geometry while idle and with each menu open in dark appearance, with both existing menus accessible. No extra outer pill surrounds the active highlight. Light appearance/hover was not separately agent-verified. Existing preferences and the review fixture were preserved. No new tests or fixtures were added; the presentation-only restoration did not require rerunning Unit 1's 29 behaviour tests.

Light tighten retained only the direct native menus. Light probe checked actual idle/menu-open rendering, accessible labels and menu contents, and verified removal of the rejected wrappers/widths without changes to handlers.

- [x] Confirm the restored standard buttons look correct while idle and with either menu open.

Bilal accepted the restoration with "all good now" and explicitly authorised commit/push on 2026-10-08.

## Review passes and milestone

Standard tighten retained one store, existing navigation and shared contents for the two real menus. It consolidated star labels/state and removed redundant test setup/assertions. Deep probe checked isolated preference ownership, lexical/canonical identity without case-folding, stale reload, captured focus, selection/error retention, native observation and actual quit/relaunch persistence. No outstanding Unit 1 correctness blocker was found.

All M1 task implementations are manually accepted. After reading the actual `code-quality-analysis` skill, broader M1 maintainability analysis is deferred to a separate checkpoint before M2. The accepted T15 diff has no identified correctness blocker from tighten/probe; publication adds no remediation or later task work. Milestone analysis has not been performed or accepted. Findings must be reviewed before any `cluster-workflow` remediation.
