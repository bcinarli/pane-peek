---
task: favourite-removal
verdict: Passed
closed: 2026-10-13
---

# Evidence: favourite removal

Approved T15 follow-up under A16: remove any saved path from both native Favourites menus without opening it, including an unavailable directory. Keep existing open entries and explicit stale-path retention. Removing a saved entry changes preferences only; it does not delete filesystem data.

- 2026-10-13 Unit 1: Bilal approved the proposed removal submenu, persistence regression and app review. Branch `fix/deleted-favourites-removal` starts from clean local/live `main` at `4cda29d`, containing merged PR #27. Commit, push and merge remain separate gates.
- 2026-10-13 Intentional red: `node scripts/test.mjs --filter removesDeletedFavouriteWithoutReaddingItOrChangingOtherSavedPaths` compiled with a no-op removal stub and failed the in-memory and persisted removal expectations. Real temporary directories and a unique preference suite cover deletion, equivalent paths, repeated removal and retained order of other favourites.
- 2026-10-13 Green: `node scripts/test.mjs --filter 'FavouritesTests|deferredFavouriteWaitsForDiscardBeforeLoadingItsCapturedDirectory'` passed all 4 tests. The explicit removal operation reuses existing path normalisation/preferences and is shared by both native menus; open actions retain their existing navigation/dirty guards.
- 2026-10-13 Build/review preparation: `swift build --product PanePeek`, isolated asset compilation, plist lint, source-executable signature/hash checks and launch/process checks passed. The review app has an isolated preference domain seeded with disposable missing/available paths. Existing app bundles/preferences were preserved. `git diff --check` and 9 affected favourites continuation links passed.
- 2026-10-13 Acceptance/publication: Bilal accepted the presented unit with "Approved. Commit and create a pr" and authorised commit and PR publication. Published [feature commit `43d2979`](https://github.com/bcinarli/pane-peek/commit/43d2979) in [PR #28](https://github.com/bcinarli/pane-peek/pull/28), targeting `main`. Individual native/accessibility outcomes were not separately reported; merge requires separate approval.

## Validation

Environment: macOS 27.0.1 (26A434), Apple Swift 6.4 and Node 26.1.0. Deployment minimum remains macOS 26; no macOS 26 run is claimed.

Native app inventory reported a locked Mac. The launched review executable was confirmed running; visible menu interaction, relaunch/draft retention and accessibility were not agent-observed. Bilal subsequently accepted the presented unit overall; individual outcomes remain unreported.

Standard tighten retained one shared menu implementation, the existing persistence format and one focused regression. Standard probe checked unavailable/equivalent paths, repeat-removal no-op, unrelated-entry order/persistence, existing navigation/dirty guards, removal without an open callback and the empty-menu branch. No further code change was warranted; individual keyboard/VoiceOver and native state-retention outcomes remain unreported.

Strict verification through the bundled executable path rejected the unsealed development bundle. The package executable's own signature verified, and its copied bytes matched. No signing identity or security setting was changed; launch/process verification subsequently passed. This is a local development package, not distribution-signing evidence.

## Run and manual review

Quit PanePeek before rebuilding, then run from the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

The running **PanePeek Favourites Review** app is seeded with two disposable saved paths, one unavailable after a fixture rename. Its bundle and fixture paths are supplied in the handoff rather than stored here. Use the [existing disposable favourites fixture](../../../validation/t15-persistent-favourites.md#reproduce-the-review) for a fresh setup: save `missing`, navigate away and rename only that fixture directory using the linked recipe.

- [ ] Open the unavailable favourite: an error appears and the current directory/selection remain usable. The saved path stays in the menu.
- [ ] Choose Favourites → Remove Favourite → that path in the toolbar. The entry disappears from both menus; unrelated favourites remain in order. Removing the final entry shows No favourites yet.
- [ ] Remove an entry through the menu bar while editing unsaved text. There is no dirty prompt or change to pane focus/directory/selection, buffer or undo. A visible pane's star reflects removal of its current directory.
- [ ] Quit/relaunch and confirm the removed path stays absent. Existing favourites still open in the focused pane with the established dirty guards.
- [ ] Exercise keyboard access to both removal submenus and check VoiceOver names/full paths and focus recovery. Check long paths in narrow windows and light/dark appearance; text-enlargement and relevant accessibility settings remain explicit review checks.

Bilal accepted the presented unit overall on 2026-10-13. The unchecked list retains individually unreported outcomes. This follow-up does not close cross-window A16 work or the T18 app-wide accessibility audit.
