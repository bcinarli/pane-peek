---
task: rename-affected-document-handling
verdict: Passed
closed: "2026-10-12"
---

# Rename and affected document handling

T09 Unit 1, inline rename and file double-click follow-ups are implemented on `bcinarli/t09-rename-affected-documents`. Bilal approved all three coding units separately on 2026-10-12. Bilal accepted the final result on 2026-10-12 and authorised commit and PR creation. No further T09 coding unit remains. Published through [PR #20](https://github.com/bcinarli/pane-peek/pull/20); merge is pending.

- 2026-10-12, Unit 1: single-item Rename through the row context menu and File menu (Command-Shift-R), literal name/collision validation, filesystem case/link identity, current-window dirty-document guards, renamed selection/path recovery and affected browser refresh. T08 PR #19 head `6934c8f` is contained on local and live `main` at merge `9464287`.
- Intentional red/green: `node scripts/test.mjs --filter ItemRenameTests` compiled and failed 7 tests with 19 behaviour issues, then passed all 7. `node scripts/test.mjs --filter BrowserRenameTests` compiled and failed 7 tests with 12 issues, then passed. Probe regressions reproduced accepting an external replacement after Save (2 issues) and an obsolete pending-directory alias publication (1 issue); both pass after the bounded corrections. The initial sandbox compiler-cache setup failure is excluded from red evidence.
- Final checks: 81 targeted tests passed; `node scripts/test.mjs` passed 286 core tests and 14 app/native tests, with four existing expected gate-diagnostic issues. `node scripts/build-app.mjs` packaged successfully and the rebuilt app launched. `git diff --check` passed. Tighten reused ItemName, the name sheet, prompt UI and existing listing/selection machinery; probe checked identity replacement, real permission failure, concurrent destinations, delayed mutations, pending navigation, hidden-browser recovery and failed refresh.

## Inline rename follow-up

- 2026-10-12: Bilal approved the Finder-style inline follow-up under the [accepted interaction decision](../../../decisions/2026-10-12-inline-rename-and-browser-keyboard.md). The row editor replaces the rename sheet, with basename selection, editable extensions, Return/Escape and directory double-click/Command-Down. Existing mutation and dirty-document safeguards remain shared.
- Intentional red/green: three native field tests failed with 14 behaviour issues; the new dirty selection-transition test reproduced a missing renamed destination. Native collision retry exposed an active-editor refocus that ended editing and cancelled the request; a real NSWindow regression failed with one issue, then passed after retaining the editor. The transition test also needed to await its completion callback; that test synchronisation correction is distinct from the implementation fix.
- Final automated checks: 74 core and three native targeted tests passed; `node scripts/test.mjs` passed 289 core and 17 app/native tests, with four existing expected gate diagnostics. Tighten removed unused name-sheet options and reused the existing mutation path; probe exercised dirty selection cancellation, collision rejection without a dirty prompt, blur preserving the draft, relocated directory navigation and native retry focus. The final `node scripts/build-app.mjs` package passed and launched after the documented [generated-executable recovery](../../../notes/0001-build-and-bundle.md#rebuilt-executable-recovery) for a macOS launch rejection. Final warning styling and restoration of the original creation form were packaging/native checks after the full suite. `git diff --check` and changed-record local links/anchors passed. Final manual acceptance is recorded below.

Agent-observed follow-up: Return begins inline rename with basename selection; Return commits and Escape retains selection, with subsequent arrows/Return working in the list. Collision and invalid-name retries retain the typed name, expose the error and permit correction. Unicode basename selection, editable extension and multi-extension basename selection passed. Folder names select whole; Command-Down/double-click open folders. Context Rename and File shortcut use the same field; One Pane and restoration to Two Panes preserve the visible document. Clicking another row during dirty rename waits for Save/Discard/Cancel; Cancel retains the original selection/draft and Save renames with saved bytes, path and metadata. The final dark selected-row warning uses a separate text background and a warning symbol. Numerical contrast, other appearances/settings and VoiceOver speech remain unreported.

## File double-click follow-up

- 2026-10-12: Bilal approved the [file double-click gesture](../../../decisions/2026-10-12-file-double-click-rename.md). Agent reproduced the prior native result: double-click selected a file with no rename field. The updated primary action opens the existing editor for a single file/package/file link, retaining folder/directory-link navigation. It checks the clicked selection before scheduling and again before preparing rename, so rejected selection changes cannot rename the old item.
- Existing regression checks passed: 30 core tests (rename/dirty transitions and selection) plus three native editor tests. The initial selection filter matched none; SelectionTests then ran separately and passed all five. `node scripts/build-app.mjs` packaged and launched with the documented fresh-executable approach. No new automated routing adapter or mirrored test was added; the gesture was checked before/after in the native app. The earlier full 289 core/17 app result belongs to the inline unit, not this rerun.
- Tighten kept the change local to primary-action routing and reused Rename. Probe/native checks passed for file/package/file-link activation, basename selection, collision rejection, Escape retention, folder/directory-link navigation, rejected dirty selection without old-item rename, current-file dirty Cancel/Save, multiple-selection rejection and One/Two Panes. Saved bytes, destination path/size and unchanged link target text were verified. Affected native names/focus/warnings were inspected in dark appearance; Bilal accepted this new gesture on 2026-10-12.

## Coverage and provenance

Agent-executed on macOS 27.0.1 (26A434), Apple Swift 6.4 and Node 26.1.0. Validation is local; no CI or publication result is claimed. A23 is Passed under [MVP validation](../validation.md); criteria spanning later mutations/windows and the app-wide accessibility audit remain Pending.

| Scope | Executed checks |
| --- | --- |
| A23 | Temporary filesystem fixtures exercise files, folders, packages, links and dangling links; invalid/literal names; file/folder/link/hard-link collisions; real case-only rename; canonical parent aliases; replaced sources; a real read-only parent; concurrent exclusive destinations and same-name no-op. Rejected requests retain data. |
| Current-window A9 | Automated Save/Discard/Cancel, failed Save, failed mutation after Discard with retained draft/document identity, edited child of a renamed directory, disabled affected edits/Save during mutation, and saving at the new path after reload. A successful Save's new inode must match the saved snapshot before rename. |
| A18/A25, A17/A33 regressions | Single visible-item targeting, multi-selection/hidden/stale rejection, duplicate submission, selection/settings retention in matching panes, current and hidden browser relocation, later pending navigation with a rebased fallback, alias reads and successful rename followed by failed refresh. Old writable previews close before refresh. Cross-window coordination remains T16; other operation handlers remain their planned tasks. |
| Native result | Agent observed row context Rename, keyboard File action, initially selected filename, clean file rename and refreshed path/content/metadata, dirty Cancel retaining the draft, Save completing rename with saved bytes/size, directory following with retained other-pane child selection/settings, invalid-name/collision errors in the original name sheet, case-only rename, multi-selection shortcut rejection, One Pane name prompt and Escape cancellation. |

The app is left running on a disposable review directory. The session handoff supplies its current path. The fixture's file and folder names may already reflect the native smoke checks; use the recipe below for fresh data.

## Disposable fixture and run instructions

Quit PanePeek before rebuilding, then follow [build/run](../../../../README.md#build-and-run). Create a fresh fixture:

```sh
fixture=$(mktemp -d /tmp/panepeek-t09-review.XXXXXX)
mkdir "$fixture/folder" "$fixture/other" "$fixture/read-only" "$fixture/Example.app"
printf 'Keep this text.\n' > "$fixture/file.txt"
printf 'let original = "Keep this content"\n' > "$fixture/edited.swift"
printf 'Case rename content.\n' > "$fixture/case.txt"
printf 'Preserve occupied data.\n' > "$fixture/occupied.txt"
printf 'Keep this child.\n' > "$fixture/folder/child.txt"
printf 'Keep this package child.\n' > "$fixture/Example.app/child.txt"
printf 'Blocked rename fixture.\n' > "$fixture/read-only/blocked.txt"
ln -s missing.txt "$fixture/broken-link"
ln -s file.txt "$fixture/file-link"
ln -s folder "$fixture/folder-link"
ln "$fixture/file.txt" "$fixture/hard-link"
chmod 555 "$fixture/read-only"
printf '%s\n' "$fixture"
```

Open the printed path with Command-L. Put the other pane in `folder` and select `child.txt`. Give the panes different sorting/hidden settings. Rename one selected item with Return, its context menu or File → Rename (Command-Shift-R). Return confirms the inline field; Escape cancels it. Double-click/Command-Down opens a selected directory. Dot-prefixed renames retain the pane's hidden setting; an item hidden by that setting is pruned from selection under A19. Restore fixture permissions with `chmod u+w "$fixture/read-only"` when finished; cleanup is separate.

For inline naming checks, also create `archive.tar.gz`, `café 👀.swift`, `.env`, `.env.local` and `folder.with.dots`. Verify the initial selection excludes only the final file extension, selects folders/extensionless dotfiles whole, and permits editing the extension.

## File double-click manual checkpoint

Use the existing fixture recipe, then double-click one file, package and file link to start Rename. Double-click a folder/directory link to navigate. Check Escape, a collision and dirty Cancel, including double-clicking a different row with an unsaved draft. Return/context/File actions remain keyboard alternatives.

- [x] File double-click opens the same inline editor; folders continue to navigate.
- [x] Escape/collision and dirty Cancel preserve the correct item and draft; Save finishes rename.
- [x] Accept this follow-up's affected pointer/keyboard/focus result. Existing control appearance and VoiceOver measures remain separately reported below.

## Bilal's earlier manual checklist

Bilal reported these checks complete on 2026-10-12, with the file-double-click expectation retained separately under Review and publication.

- [x] Start inline rename with Return, context Rename and File Rename. Check basename selection, editable extensions, Unicode/dot names, Return confirmation and Escape restoring list focus without clearing selection. Retry a collision/invalid name and open a directory with double-click/Command-Down.

- [x] Rename a file, folder, package and link. Confirm literal names, selected result, updated path/metadata, preserved contents and link target identity. Rename `case.txt` to `CASE.txt`.
- [x] Try `bad/name`, `.`, `..`, `occupied.txt`, `broken-link` and `hard-link`; cancel inline rename. Confirm useful errors and unchanged data. Try renaming `read-only/blocked.txt`.
- [x] Rename an edited file with Save, Discard and Cancel. Check retained draft/undo after Cancel or failure, and edit/save again at the new path. A failed Save must abort rename.
- [x] Rename a directory containing the edited file. Resolve the dirty prompt, check the other pane follows the new directory and preserves surviving child selection/settings, and verify no obsolete Save path remains.
- [x] Check matching panes, One/Two Panes, multi-selection disabling and affected accessibility below. The current follow-up above is also accepted.

## Affected accessibility

Agent-observed in dark appearance: native menu/text-field/button names and roles, focused filename/basename selection in the original/follow-up controls, Command-Shift-R/Return/Escape, pointer context-menu access, perceivable inline error text, non-colour warning and Unsaved cues, and updated selected absolute paths. Native accessibility inspection establishes exposed structure, not a VoiceOver speech pass.

Bilal reported the earlier checklist complete; individual VoiceOver/appearance/enlargement/settings results and measurements were not supplied. The added file gesture received its own pointer/keyboard/focus review above. Agent inspection does not establish an additional VoiceOver or numerical contrast pass. Full applicability and whole-app acceptance remain T18 under the [shared checklist](../../../validation/checklist.md#accessibility-checks).

## Review and publication

2026-10-12: Bilal reported “all checked” and raised an outstanding expectation that file double-click should start rename. At that review, the accepted keyboard decision provided Return/context/File rename and directory double-click opening; file double-click took no action. Record the completed manual report separately from this requested activation change. Bilal subsequently approved the file double-click coding follow-up on the same date; it is implemented with checks above. Bilal accepted the final follow-up and authorised commit/PR creation on 2026-10-12. No additional coding unit remains. Merge approval is separate.

Manual verdict: Passed. T09 is Completed/Passed for its reviewed scope. Publication: [PR #20](https://github.com/bcinarli/pane-peek/pull/20), feature [commit `4690701`](https://github.com/bcinarli/pane-peek/commit/4690701a166f2c643076b5f1541c299d2f3a19d0), created/pushed on 2026-10-12. Merge and any later task require separate approval.

Final publication check on 2026-10-12: `node scripts/test.mjs` passed 289 core and 17 app/native tests on the combined accepted changes, with four existing expected gate diagnostics. The final app build and native launch were checked during the file-double-click unit.
