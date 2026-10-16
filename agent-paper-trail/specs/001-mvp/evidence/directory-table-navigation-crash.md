---
task: directory-table-navigation-crash
verdict: Passed
closed: "2026-10-16"
---

# Directory table navigation crash

## Approved unit, 2026-10-16

Bilal confirmed intermittent crashes after browsing large directories and then opening small directories, and approved regression coverage, table reload ordering and row bounds checks. This corrects navigation/listing under A1/A2 without changing accepted behaviour. Bilal accepted the presented unit on 2026-10-16 and authorised commit and PR publication. Merge remains separately gated.

The crash stack identifies an array subscript failure in `DirectoryTable.Coordinator.tableView(_:rowViewForRow:)`, called synchronously by the scroll reset inside `update(_:)`. The coordinator had replaced its entries while the native table still retained its previous row count. Reload and lay out the table before resetting scroll; return no view/string or the default height for invalid row callbacks. Also bound available-cell refresh and pointer targeting.

## Automated evidence

- 2026-10-16, red: `node scripts/test.mjs --filter DirectoryTableTests/scrolledLargeDirectoryCanNavigateRepeatedlyToASmallerDirectory` reproduced `Fatal error: Index out of range` and signal 5 when moving from a scrolled 200-file directory to an empty directory. A separate `--filter DirectoryTableTests/staleAndNegativeRowCallbacksReturnEmptyViewsAndDefaultHeight` run reproduced the same intentional failure for invalid row callbacks. The initial sandbox/compiler-cache failure is excluded from red evidence.
- 2026-10-16, green: `node scripts/test.mjs --filter DirectoryTableTests` passed all 6 tests, including three return trips each into empty/two-file destinations, scroll reset, row count, empty selection, retained native focus, current accessibility name/type-search string, and negative/stale row callbacks. Reload alone exposed an invalid negative scroll origin; laying out the resized table before the reset corrected it.
- 2026-10-16, full validation: `node scripts/test.mjs` passed 484 tests (62 native/app and 422 core), with 9 expected issues from existing timeout self-tests and no unexpected failures. `git diff --check` passed. The existing bundler, run as a generated local review copy with only its output directory/display name/bundle identity changed, built `.build/table-navigation-review/PanePeek.app`; launch succeeded and the matching executable remained running (PID 21614 at verification). The normal development bundle was not replaced.
- Environment: macOS 27.0.1 (26A434), Apple Swift 6.4, Node 26.1.0. Original supplied crash was on macOS 26.7.1; this fix has not been run on that OS version.

## Review checks

Affected native focus and accessibility row names are exercised by the automated tests; existing native keyboard range/selection/context-menu tests also pass. Bilal reported testing the review app successfully and accepted the unit overall on 2026-10-16. Individual VoiceOver and live keyboard outcomes were not reported. This is not a whole-app accessibility verdict.

The isolated review bundle uses `com.bcinarli.PanePeek.TableNavigationReview`, with separate preferences seeded to the review fixture. `.build/table-navigation-review/fixture/large` has 200 disposable text files, `small` has two, and `empty` has none. All three paths are in the review app's Favourites menu. Launch or reopen with `open -n .build/table-navigation-review/PanePeek.app`.

Manual recipe: open the review fixture's `large` directory, scroll towards the bottom, then use Go to Folder/Command-L or breadcrumbs to visit `small` and `empty`. Return to `large` and repeat. Expect no closure, the smaller listing at the top, correct row names/selection and usable keyboard navigation. Refresh or sort the same directory and check its table remains usable.

## Review passes

Tighten: kept the correction local to the existing coordinator and reused its native test helpers. Probe: checked empty and smaller listings, repeated navigation, stale/negative callbacks, focus, current accessibility labels, existing selection/dirty-document/context-menu behaviour and scroll layout timing. The unit is accepted; merge remains separate.
