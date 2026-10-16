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
