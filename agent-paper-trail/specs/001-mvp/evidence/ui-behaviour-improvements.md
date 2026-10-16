---
task: ui-behaviour-improvements
verdict: Pending
closed: ""
---

# Evidence: browser UI and preview improvements

- 2026-10-16: Bilal accepted the [eight refinements](../../../decisions/2026-10-16-browser-ui-and-preview-improvements.md), confirmed directory contents still open under Reveal in Finder, and chose transient success notifications with retained error/partial outcomes. Approval of the first file-category icon coding unit follows the presented first-unit request; later units retain separate coding/manual gates.
- Unit 1 starts from clean local/live `main` at `d9bcd8f`, in an isolated feature branch. Unit 1 implementation and executed checks follow below; manual acceptance is pending. No commit/push/merge approval is implied.

## Unit 1 review scope

Map regular files to recognisable categories with a generic unknown fallback, retain existing directory/package/link distinctions and reuse pinned Lucide 1.17.0 geometry. Check mixed-case extensions, extensionless build/configuration names, selected/inactive rendering, keyboard selection and accessible row names. No file contents are read to choose an icon. Unexecuted manual/accessibility checks remain Pending.

## Unit 1 executed checks, 2026-10-16

Environment: macOS 27.0.1 (26A434), Apple Swift 6.4, Node 26.1.0; deployment minimum remains macOS 26. No macOS 26 runtime pass is claimed.

- Intentional red: `node scripts/test.mjs --filter DirectoryEntryIconTests` compiled, then failed with 35 classification/precedence expectations against a generic-icon placeholder. Green: all three test functions passed, including 34 parameterised filename cases, after implementation. Names are deliberately nonexistent, confirming classification does not require opening content.
- Native-list regressions: `node scripts/test.mjs --filter 'DirectoryEntryIconTests|DirectoryTableTests'` passed all nine tests, including retained URL selection, guarded dirty-document interaction, keyboard/context focus and large-to-small listing transitions. No whole-suite pass is claimed.
- `node scripts/build-app.mjs` succeeded with the existing toolchain search-path warning. All nine new SVGs match the official pinned Lucide 1.17.0 icon nodes exactly; the downloaded package matched its published SHA-512 integrity. All eleven file/folder catalog images load as distinct, valid 16-point templates from the compiled bundle. Plist lint and `git diff --check` pass.
- An isolated review bundle with an independent preference domain launches with disposable category fixtures. Native dark appearance shows every category, a generic unknown file, a misleadingly named directory, package, ordinary link and broken link without placeholders. Clicking source then pressing Down selected configuration, retained its icon/label and updated Details. Native accessibility exposes row names and File/Folder/Package/link distinctions; decorative icons do not duplicate the row labels.
- The copied development bundle rejects strict executable-path signature verification because its unsealed bundle resources differ. The built source executable's signature verifies and the review executable has identical SHA-256 bytes. No signing/security setting was changed; the native app was observed running. This is development validation, not distribution evidence.
- Standard tighten keeps one local icon enum, the existing row and asset mechanism, and no extra dependency or file-content reads. Standard probe checked identity precedence, ambiguous `.ts` recognition, mixed-case/extensionless/hidden names, unknown fallback, official geometry, compiled catalog loading and selected-state keyboard behaviour. Light appearance, inactive selection, enlarged text, increased contrast and actual VoiceOver remain manual checks.

## Run and manual review

The handoff links the running isolated **PanePeek File Icons Review** app and its fixture directory. The fixture media/document files contain plain placeholder text; they exercise filename icons only, not media decoding. The primary PanePeek app/preferences are unaffected. From this feature checkout, the normal build/run commands remain:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

- [ ] Review category shapes/size in light and dark appearances, including selected and inactive rows. Confirm code/configuration, media, archives, tables, documents, text and generic unknown files are distinguishable.
- [ ] Check keyboard selection and row names with VoiceOver; confirm folders, packages and ordinary/broken links retain their distinctions.
- [ ] Check enlarged text, narrow panes and increased contrast for usable labels/icons. Report the actual settings/outcomes or remaining limitations.

On 2026-10-16 Bilal reported “Icons look good”, accepting the presented icon appearance. Individual accessibility/settings outcomes remain unreported; the overall T20 task remains Active/Pending. Finder wording, layout toggle, favourites, Quick Look, inline media, direct Move/Trash and notifications have accepted scope but are not implemented by this unit. Later coding approvals and commit/push/merge remain separate.

- 2026-10-16 review follow-up: Bilal asked whether hidden-file/folder icons exist. The pinned Lucide package has `eye-off` and `folder-dot`, but no `file-hidden`, `folder-hidden` or `file-dot` module. No hidden-item styling change or later coding unit was authorised by this question.

## Unit 1b: hidden-item badge, 2026-10-16

Bilal explicitly approved adding the eye-off badge after accepting the file-category icon appearance. The unit reuses existing `isHidden` metadata and the pinned Lucide eye-off artwork, preserves type icons and aligned names, and adds Hidden to the existing row accessibility/help description. This is a presentation-only follow-up: validate through the compiled catalog, native fixtures and existing classifier/list regressions rather than adding tests that mirror a conditional image. Executed checks follow below; manual acceptance remains Pending. Later T20 coding/source-control gates remain separate.

- `node scripts/test.mjs --filter 'DirectoryEntryIconTests|DirectoryTableTests'` passes all nine tests after the final layout adjustment. `node scripts/build-app.mjs`, plist lint and `git diff --check` pass. The eye-off SVG nodes match the pinned official package; the compiled badge loads as a valid template. Review/package executable bytes match and a standalone copy verifies its signature. A later test relink changes the build-products executable bytes, so the packaged executable is the relevant review comparison.
- Native fixture checks: before Show Hidden Files, each pane shows only three ordinary items. Enabling it in the left pane shows all ten fixtures, including seven dot-prefixed or macOS-flagged hidden entries. Badges appear only on hidden entries while folder/code/configuration/image/link/package icons remain. Both non-dot flagged paths report true filesystem hidden metadata. The other pane retains its visibility setting.
- Native dark screenshots confirm aligned headings/filenames and badges on ordinary and inactive-selected hidden rows. Keyboard Down/Up retains the hidden-file selection and Details; native row values/help include Hidden file/folder/link/package without a duplicate decorative image element. Actual VoiceOver announcements, light appearance, enlarged text and increased contrast remain unexecuted manual checks.
- Tighten keeps the badge beside the existing icon in one local layout with a shared column width; no new classification/store/dependency. Probe checks dot names versus filesystem flags, visible-item absence, retained special-item identity, selection/focus and accessible descriptions. No further code change was needed.

The running **PanePeek Hidden Icons Review** bundle has its own preferences and disposable fixtures. Left Show Hidden Files is enabled; right is disabled for comparison. Fixture media names contain placeholder text for icon checks. The handoff supplies the local app path; normal build/run commands above still apply.

- [ ] Review the badge size/readability in light/dark and selected/inactive states; ensure the original type icon remains recognisable and filenames stay aligned.
- [ ] Check Hidden in VoiceOver/help, including a hidden file/folder without a leading dot, and verify the Show Hidden Files toggle in either pane.
- [ ] Check narrow/enlarged-text/increased-contrast presentation. Individual outcomes remain Pending until reported.

### Icon-unit acceptance, 2026-10-16

Bilal reported “Looks good; approved”, authorised a local commit of the reviewed icon work, and approved continuing with Unit 2 Finder wording. Units 1/1b are accepted overall for the presented scope; individual light/VoiceOver/enlargement/increased-contrast outcomes remain unreported. T20 remains Active/Pending because later units are not yet implemented. Commit approval does not include push, PR or merge.

## Unit 2: Finder menu wording, 2026-10-16

Bilal approved this unit after accepting the icon follow-up. Reviewed icon work and the accepted planning records are committed locally as `3e95dc90e532d539c1abae5e9aba32e3cf3ba2e8`; no push/PR/merge performed. Unit 2 changes only the File/context labels from Open in Finder to Reveal in Finder and reconciles the current README. The handlers, enabled-state rules and directory-contents/file-reveal routing are retained. Executed checks follow below; Bilal's manual review remains Pending. No artificial label-only test is added.

- `node scripts/test.mjs --filter FinderOpeningTests` passes all four existing routing/error regressions, including directory contents, file/package/listed-link reveal, stale item types and missing/Finder failures. `node scripts/build-app.mjs`, `git diff --check` and the current-label source search pass. Same macOS/Swift/Node environment as Unit 1; no macOS 26 runtime check or whole-suite pass claimed.
- The existing isolated review app was closed with no selected document/draft, its prior executable preserved and its executable refreshed from the packaged build. Review/package bytes match. Native File menu shows Reveal in Finder disabled for empty selection and enabled after file selection. Right-clicking the fixture folder selects it and exposes the same enabled Reveal in Finder context action. The app is left running with that context menu open for review. Actual Finder invocation is not repeated for this wording-only unit; unchanged routing is covered by the existing regressions and historical native evidence.
- Light tighten keeps two direct native labels and current README wording. Light probe confirms no handler, enabled-state, URL selection, error or folder-opening logic changed; no old label remains in shipped sources. Accessibility exposes the new menu names/enabled states. The automation's Escape key did not dismiss the menu; its advertised native Cancel action did. Keyboard-only menu navigation and actual VoiceOver remain manual checks, not inferred passes.

### Unit 2 manual review

Use the running review app or the build/run commands above. The existing disposable fixture has a visible folder and files. Check the File and item context menus show Reveal in Finder, with no-selection disabling retained. Choosing a directory should still open its contents in Finder; files/packages/file links should still be revealed. Check keyboard/VoiceOver naming as applicable. Bilal accepted Unit 2 overall on 2026-10-16, authorised its local commit and approved Unit 3 grouped layout toggle/icons. Individual VoiceOver/keyboard-only outcomes remain unreported. Nothing has been pushed; later-unit commit and publication gates remain separate.

## Unit 3: grouped browser-layout toggle, 2026-10-16

Bilal accepted Unit 2 and authorised the grouped toggle/icons. Finder wording is committed locally as `8feaaac7cf681c675fb2079d2e9fd4f7eaaa3a17`; nothing has been pushed. Unit 3 uses a small native segmented-control bridge with the existing browser-mode binding and a shared toolbar background. Native SwiftUI segmented labels suppressed the requested icons, so the AppKit control supplies image-and-text segments without a second mode store. Bilal requested `square-split-horizontal` for Two Panes, paired with `square` for One Pane; both reuse the pinned Lucide 1.17.0 geometry.

- Intentional red: the two new `BrowserLayoutToggleTests` compiled and failed six expectations with inert selection/action handling. Green: `node scripts/test.mjs --filter 'BrowserLayoutToggleTests|BrowserLayoutTests|BrowserSplitViewTests'` passed twelve focused tests (eight app, four core). The native action reaches the existing mode transition, repeated selection retains the active browser, and external mode updates change selection without writing back. Existing regressions cover hidden-browser state, dirty documents and split/editor retention. No whole-suite or macOS 26 runtime pass is claimed; the environment matches Unit 1.
- `node scripts/build-app.mjs` passes, including a final rebuild after the icon refinement. Both SVGs match the official package nodes exactly and load as distinct valid 16-point templates from the compiled review catalog. Review executable/catalog bytes match the final package; plist lint and `git diff --check` pass. The earlier executable standalone-signature check passed; development-bundle signing limitations remain as recorded above. A resource-check compiler-cache permission failure was resolved using a writable temporary cache.
- Native dark review shows one joined capsule with both icons/text and an exclusive selected fill. AX exposes Browser layout with named One Pane/Two Panes radio values and no extra decorative image elements. Starting from the right browser's selected file, One Pane retains it, repeated One stays selected, and Two restores its peer on the right. A temporary unsaved text draft survives both switches with editor focus and Save availability retained; immediate Undo restores the original clean text without re-clicking the editor. The fixture was not saved or changed on disk. The final icon is visible after refresh; View → One Pane and View → Two Panes each update both layout and toolbar selection.
- Standard tighten retains one local platform bridge, one existing mode binding and two focused action/synchronisation tests. Standard probe checks exclusive selection, external updates, active-browser identity, editor/draft/Undo retention, catalog/provenance and accessibility values. No further code change was needed. Actual VoiceOver, keyboard-only toggle access, light appearance, enlarged text, narrow toolbar and increased contrast remain manual checks.

### Unit 3 manual review

The isolated review app is running with the final square/split-square toggle and disposable fixtures. The handoff links its local path; normal build/run commands above still apply. Review the joined presentation and selected state, switch modes with a selected item and unsaved draft, and check keyboard focus/VoiceOver names and values. Check light/dark, narrow/enlarged-text and increased-contrast presentation as applicable. Unit 3 remains uncommitted and pending Bilal's manual acceptance. Unit 4 Favourites coding, commit and publication retain separate gates.

### Unit 3 acceptance, 2026-10-16

Bilal accepted the presented toggle overall, authorised its local commit and approved Unit 4 Favourites popup implementation. Individual keyboard/VoiceOver and remaining appearance/settings outcomes are unreported. Later coding, push/PR/merge and Unit 4 commit remain separate gates.

## Unit 4: Favourites popup, 2026-10-16

The accepted layout toggle is committed locally as `128fa0c`; no push performed. Bilal approved a toolbar-anchored popup with folder names, subdued full paths and separate open/remove actions. The view reuses shared Favourites and BrowserState.openFavourite, which captures the active pane synchronously before scheduling guarded navigation. Removal uses the existing explicit operation, including unavailable paths; the menu-bar Favourites menu retains keyboard access. This presentation/integration unit adds no replacement persistence/navigation logic. Existing focused regressions and native checks apply rather than tests mirroring view declarations. Validation and manual acceptance are Pending.

- Scope addition, 2026-10-16: Bilal added Unit 9, Name / Size / Modified columns. Accepted records and reviewer bindings are reconciled; no size-column implementation is included in Unit 4.

### Unit 4 executed checks

- `node scripts/test.mjs --filter 'FavouritesTests|WindowCreationTests|deferredFavouriteWaitsForDiscard|cancelledOrDiscardedTransitionsCover'` passes six focused test functions (one native-window test, five core tests, including parameterised Cancel/Discard). They cover persistence, equivalent paths, explicit unavailable/repeated removal, captured active-pane navigation, failed-navigation selection retention, deferred dirty navigation and shared favourites/drafts across independent windows. Existing red/green ownership of those behaviours is retained; no new behaviour implementation or artificial view-structure test was added. `node scripts/build-app.mjs` passes. Same environment as Unit 1; no full-suite or macOS 26 runtime pass is claimed.
- New star-off SVG geometry matches the pinned official Lucide package. Folder, folder-open and star-off load as distinct valid 16-point templates from the compiled review catalog. Review executable/catalog bytes match the package, a standalone packaged-executable copy verifies its signature, plist lint and diff checks pass. The isolated review preference domain was backed up before seeding disposable paths; the main app/preferences are unchanged.
- Native dark popup shows two folders named Projects with different wrapping full paths, a long Unicode path, an unavailable path and `/` as the root name. It scrolls to lower rows. Empty-state wording, Close, Escape and outside-click dismissal pass. AX exposes complete name/path text and distinct full-path open/remove labels without decorative folder duplicates. Keyboard Tab/Shift-Tab reaches row open/remove buttons; Space activates Open and dismisses the popup.
- With a right-pane unsaved text draft, removing the unavailable favourite updates the popup without navigation, selection loss or a dirty prompt. The removal persists in the isolated preference key. Opening Projects dismisses the popup and shows the existing Save/Discard/Cancel sheet; Cancel retains the right directory, selection, draft and editor focus. Undo restores the original clean fixture text. A later clean Open changes only the right pane to the chosen directory; the left remains unchanged. Removing the left pane's saved directory updates its star immediately while preserving both locations and the right saved star. No fixture content was saved or deleted by these actions.
- Standard tighten keeps one local popover view and reuses the shared store/navigation/menu-bar access. Standard probe checks active-pane capture before dismissal, unavailable-path removal, dirty Cancel/Undo retention, shared star updates, duplicate/long/root paths, bounded scrolling and keyboard/AX actions. No further code change was needed. Actual VoiceOver, light appearance, text enlargement, narrow-window/increased-contrast presentation and live cross-window popup updates remain manual checks; the automated shared-window regression passes.

### Unit 4 manual review

The isolated review app is running with disposable favourites, including duplicate names and a long path. The handoff provides its local path; the normal build/run commands above still apply. Review row layout, open/remove icons, full-path readability, keyboard access and VoiceOver as applicable. Add/remove stars and open favourites in either active pane, including with a draft; review shared state in another window. Unit 4 is uncommitted and pending Bilal's manual acceptance. Unit 5 Quick Look and later coding/source-control actions retain separate gates. Unit 9 Size column is accepted scope only.

- Long-list review, 2026-10-16: Bilal questioned scrolling with tens of favourites and whether a centred dialog would be preferable. Seeded forty disposable favourites in the isolated review domain, preserving its prior preferences. Native checks show the header remains fixed, only the bounded list scrolls, and the final entry/actions are reachable. This is a usability observation, not a performance benchmark or acceptance. No source change or search/dialog requirement is approved by the question; Unit 4 remains pending review.

### Unit 4 refinement approval, 2026-10-16

Bilal chose to retain the popover and explicitly approved folder-name/full-path search and increased height for roughly six to eight rows. Accepted records and reviewer binding are reconciled. Search adds matching behaviour with observed red/green tests; native review must include a long list, matching parent paths/duplicate names, no matches/clear, filtered open/remove, focus/Escape and retained draft guards. Unit 4 remains uncommitted and pending manual acceptance of the refined result.

### Unit 4 search/height refinement checks

- Intentional red: two new search tests compiled and failed seven matching expectations against an unfiltered placeholder. Green: the focused Unit 4 command above now passes eight test functions (one app, seven core), including eight name/path/case/accent/blank/missing/root query cases, preserved order/persistence and live filtered removal. The first integrated compile required the existing generic State-wrapper alias used elsewhere in the app because this SDK also exposes a State macro; after that local compatibility correction, tests and `node scripts/build-app.mjs` pass.
- The popover focuses search on opening, keeps it above the results and caps list height at 504 points. Native ordinary two-line-path rows show seven visible entries; the longer wrapped sample uses more space. Case/accent matching passes automated checks. Native folder-name search filters the large fixture list, parent-path search `/personal/` isolates the correct Projects folder, an unknown query shows No matching favourites, and Clear restores the saved list and search focus. Scrolling to the final result then changing to another query starts at the first match.
- Removing the sole filtered Saved folder 36 favourite shows the no-match state while retaining the query and unrelated favourites. Filtered Open targets the right active pane and dismisses the popup. Escape closes it even with a query, reopening resets the query/focus, and Tab from search reaches Clear then the row Open action; Space opens the filtered folder. Existing navigation/removal safeguards remain bound to the same callbacks and the expanded regression set passes. No repeated native draft write is needed for this matching-only refinement; the earlier Unit 4 dirty Cancel/Undo observations retain their scope.
- Standard tighten keeps matching in the existing Favourites owner, one local query and no second list/cache/store. Full paths already contain folder names. Standard probe checks whitespace reset, Unicode/case, missing paths, immutable saved order, filtered removal, scroll reset, focus, Escape and captured navigation. Actual VoiceOver, appearance/text-enlargement/increased-contrast, smaller-screen layout and live cross-window popup checks remain manual. Final build/review and record checks follow the same development-bundle limits recorded above. Unit 4 remains uncommitted and pending manual acceptance; later units are unapproved.

### Unit 4 acceptance, 2026-10-16

Bilal accepted the refined searchable/taller Favourites popover overall, authorised its local commit and approved Unit 5 browser Space/Quick Look implementation. Individual VoiceOver, appearance/text-enlargement/increased-contrast, smaller-screen and live cross-window popup outcomes remain unreported. Unit 5 commit, later coding and publication retain separate gates.

## Unit 5: browser Space and Quick Look, 2026-10-16

The reviewed Favourites unit is committed locally as `2eede8e`; nothing has been pushed. Bilal approved native Finder-style Quick Look from browser Space. A per-window responder owns the shared system panel through Apple's callbacks; the native table routes bare Space/Escape locally. Feed selected listed URLs in display order, starting at the primary item, and update/close with selection/window changes. Quick Look reads saved disk content and leaves editor/rename input and drafts intact. Bilal accepted the presented application overall on 2026-10-16; the resumed checks below resolve the lock interruption. Unit 5 remains uncommitted.

### Unit 5 executed checks

- Intentional red: six compiled Quick Look tests failed eleven expectations against inert selection/panel/key handling. Four full-panel tests exposed the SwiftPM host's absent running/key application rather than product behaviour; replaced their activation scaffolding with reliable data-source/responder seams, with live ownership checked in the running app. A later nil-predecessor replacement test failed two expectations before fixing cleanup of a replaced responder. Final `node scripts/test.mjs --filter 'QuickLookPreviewTests|DirectoryTableTests|InlineNameEditorTests|BrowserLifecycleTests'` passes all 23 tests in four suites. Coverage includes ordered/primary/reordered/empty/nonexistent URLs, stale indexes, bare Space/repeat/modifier routing, Escape retaining selection, replacement with nil/non-nil predecessors, lifecycle forwarding and existing guarded selection/rename behaviour. No automated full-panel or whole-suite pass is claimed.
- `node scripts/build-app.mjs` passes. Final packaged/review executable and catalog bytes match; a standalone copy of the packaged executable passes signature verification, the review plist passes lint, and saved text fixtures are unchanged. The environment remains the Unit 1 macOS 27/Swift 6.4 setup; no macOS 26 runtime pass. Development-bundle signing limits remain as recorded above.
- Native review: Space opens a separate system Quick Look window with the saved text; Space again and Escape close it while retaining the browser row. Native PNG, PDF and H264 video previews decode real disposable content, including PDF text and video playback/timeline controls. Up/Down changes between the movie and PDF while the panel stays open and updates the browser selection. The final build was relaunched and its saved-text preview rechecked.
- Space in the Details editor inserts text and retains an unsaved draft without opening Quick Look. Attempts to refocus the selected row through automation triggered the existing drag/dirty guards; Cancel retained the draft. The Mac then locked, blocking completion of the native draft-preview/Undo, rename, multi-selection, empty-selection and window-handoff/teardown checks. Those outcomes remain Pending. The unsaved disposable draft has not been saved; saved fixture bytes remain unchanged.
- Standard tighten removed live-application activation scaffolding, redundant callback helpers and temporary diagnostics. Standard probe fixed nil-successor responder replacement and refreshes the current saved item when reopening. The controller retains listed URLs only, owns no editor state and installs/releases the shared panel through system callbacks; no global keyboard monitor or content loader was added. Actual VoiceOver, light/dark and enlarged-text/contrast/reduced-motion review remain manual.

### Unit 5 manual review

Build/run with the commands above, or use the isolated running review app linked in the handoff. Its disposable fixture directory contains saved text, a PNG, a PDF and a short movie. Review Space/Escape, live selection and multiple-item order, pane/window handoff, empty or unavailable selections and closing the owning window. Check Space remains local to rename/editor input; with a draft, Quick Look should show saved content while Details retains the draft and Undo. The lock interruption and its resumed checks are recorded below. Unit 5 commit, later units and publication retain separate gates.

### Unit 5 resumed native checks and acceptance, 2026-10-16

Bilal unlocked the Mac and reported “I checked the application, looks good”. This records overall acceptance of the presented application; individual accessibility/settings outcomes are unreported. Commit, later coding and publication still need separate approval.

- Resumed native checks pass on the final executable: Space replaces the selected inline-rename basename with a literal space; Escape cancels without renaming, then browser Space opens saved text. Empty browser Space leaves the panel closed. A two-row Shift selection opens at the second primary item; the system Back control shows the first displayed item, Escape retains both rows and the next Escape clears selection.
- With an unsaved text draft, focusing the selected row through its context menu avoids the automation's drag path. Browser Space shows saved disk text with no draft marker. Escape returns to the intact dirty draft; Undo removes the marker, returns to clean state and disables Save. The saved file remains byte-for-byte unchanged. An initial automation action failed during the second window's asynchronous home-list load; re-reading its current controls resolved it without app changes.
- New Window takes control with an empty selection and closes the old preview; its empty Space remains inert. Both windows subsequently open their own previews. Switching back to the original window retains owned panel visibility (first Space closes it; second reopens saved text). Closing the active owning browser window releases the panel; the remaining window immediately opens its own saved-text preview. Only the temporary second window was closed.
- A disposable selected file was preserved under a different name, making its listed URL unavailable. Native Quick Look showed the filename/generic fallback without a crash; Escape returned to the usable browser. The fixture was restored without deleting content. Final review app is left with a clean saved-text Quick Look panel open, one browser window and no test draft. Tighten/probe conclusions and the 23-test/build results remain unchanged; no source changed during resumed validation.
- Actual VoiceOver, appearance/text enlargement/increased contrast/reduced motion and a macOS 26 runtime pass remain unexecuted. Unit 5 is accepted overall and ready for its separate commit approval. T20/A10 remain Pending for later Details-media and app-wide checks.

### Unit 5 commit and next-unit approval, 2026-10-16

Bilal accepted the completed checks, authorised the local Quick Look commit and approved Unit 6a read-only image previews in Details. Unit 6b video, later coding and publication retain separate gates.
