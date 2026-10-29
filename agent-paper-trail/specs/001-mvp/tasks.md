# PanePeek MVP tasks

Status: Active

One row per task. The linked evidence file’s `task` slug identifies its row. Status: `Ready`, `Active`, `Blocked`, `Completed`, `Abandoned`. Verdict: `Pending`, `Passed`, `Failed`, `Waived`. Completed means the task’s implementation and manual review are accepted; publication is recorded separately. A Ready task still needs explicit approval for its coding unit. While manual review is pending, keep the task Active and its verdict Pending.

[Plan](plan.md) owns scope, dependencies and unit gates; [validation](validation.md) owns full-criterion verdicts. Link checks from each task’s evidence file. Verify required dependency commits on `main` before starting another task under [decision 0002](../../decisions/0002-feature-branches-and-prs.md).

The [GitHub release-update package](../2026-10-24-github-release-updates/README.md) owns its separate task state and unit gates.

The [Git and agent-worktree tracker](../2026-10-27-git-worktrees/tasks.md) owns the optional inspection workstream's task state and coding gates.

| Task | Milestone | Status | Verdict | Manual review | Publication / readiness | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| [Syntax detection and registry](plan.md#syntax-detection-and-registry) | Follow-up | Completed | Passed | Reviewed foundation accepted | Local commit; configuration coverage remains separate | [syntax-detection-registry](evidence/syntax-detection-registry.md) |
| [Contextual Find](plan.md#contextual-find) | Follow-up | Completed | Passed | Reviewed scope accepted; root correction verified for authorised publication | [PR #142](https://github.com/bcinarli/pane-peek/pull/142) | [contextual-find](evidence/contextual-find.md) |
| [Copy file content](plan.md#copy-file-content) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #139](https://github.com/bcinarli/pane-peek/pull/139) | [copy-file-content](evidence/copy-file-content.md) |
| [Resizable browser columns](plan.md#resizable-browser-columns) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #123](https://github.com/bcinarli/pane-peek/pull/123) | [resizable-browser-columns](evidence/resizable-browser-columns.md) |
| [Editor viewport stability](plan.md#editor-viewport-stability) | Follow-up | Completed | Passed | Accepted for typing and Save retention | [PR #122](https://github.com/bcinarli/pane-peek/pull/122) | [editor-viewport-stability](evidence/editor-viewport-stability.md) |
| [File information heading target](plan.md#file-information-heading-target) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #119](https://github.com/bcinarli/pane-peek/pull/119) | [file-information-heading-target](evidence/file-information-heading-target.md) |
| [Recursive current-folder search](plan.md#recursive-current-folder-search) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #118](https://github.com/bcinarli/pane-peek/pull/118) | [recursive-folder-search](evidence/recursive-folder-search.md) |
| [Back and Forward navigation](plan.md#back-and-forward-navigation) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #109](https://github.com/bcinarli/pane-peek/pull/109) | [back-forward-navigation](evidence/back-forward-navigation.md) |
| [Editor line numbers](plan.md#editor-line-numbers) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #108](https://github.com/bcinarli/pane-peek/pull/108) | [editor-line-numbers](evidence/editor-line-numbers.md) |
| [Collapsible File information](plan.md#collapsible-file-information) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #106](https://github.com/bcinarli/pane-peek/pull/106) | [collapsible-file-information](evidence/collapsible-file-information.md) |
| [Single-pane Details width](plan.md#single-pane-details-width) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #105](https://github.com/bcinarli/pane-peek/pull/105) | [single-pane-details-width](evidence/single-pane-details-width.md) |
| [Context-menu grouping](plan.md#context-menu-grouping) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #104](https://github.com/bcinarli/pane-peek/pull/104) | [context-menu-grouping](evidence/context-menu-grouping.md) |
| [Duplicate menu](plan.md#duplicate-menu) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #104](https://github.com/bcinarli/pane-peek/pull/104) | [duplicate-menu](evidence/duplicate-menu.md) |
| [Same-folder copies](plan.md#same-folder-copies) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #104](https://github.com/bcinarli/pane-peek/pull/104) | [same-folder-copies](evidence/same-folder-copies.md) |
| [Title-bar interaction](plan.md#title-bar-interaction) | Follow-up | Active | Pending | Gesture/control review accepted | [PR #103](https://github.com/bcinarli/pane-peek/pull/103) | [title-bar-interaction](evidence/title-bar-interaction.md) |
| [Fresh single-pane windows](plan.md#fresh-single-pane-windows) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #102](https://github.com/bcinarli/pane-peek/pull/102) | [fresh-single-pane-windows](evidence/fresh-single-pane-windows.md) |
| [Directory listing metadata](plan.md#directory-listing-metadata) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #102](https://github.com/bcinarli/pane-peek/pull/102) | [directory-listing-metadata](evidence/directory-listing-metadata.md) |
| [Root navigation bookmark](plan.md#root-navigation-bookmark-follow-up) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #100](https://github.com/bcinarli/pane-peek/pull/100) | [root-navigation-bookmark](evidence/root-navigation-bookmark.md) |
| [Syntax-highlighting flashes](plan.md#syntax-highlighting-flashes) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #99](https://github.com/bcinarli/pane-peek/pull/99) | [syntax-highlighting-flashes](evidence/syntax-highlighting-flashes.md) |
| [Save ownership preservation](plan.md#save-ownership-preservation) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #85](https://github.com/bcinarli/pane-peek/pull/85) | [save-owner-preservation](evidence/save-owner-preservation.md) |
| [Markdown link policy](plan.md#markdown-link-policy) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #84](https://github.com/bcinarli/pane-peek/pull/84) | [markdown-link-policy](evidence/markdown-link-policy.md) |
| [Save permission preservation](plan.md#save-permission-preservation-follow-up) | Follow-up | Completed | Passed | Accepted for the reviewed scope | [PR #83](https://github.com/bcinarli/pane-peek/pull/83) | [save-permission-preservation](evidence/save-permission-preservation.md) |
| [Markdown front matter](plan.md#additional-file-previews) | Follow-up | Completed | Passed | Accepted for the presented unit | [PR #78](https://github.com/bcinarli/pane-peek/pull/78) | [markdown-front-matter](evidence/markdown-front-matter.md) |
| [SVG preview and source editing](plan.md#additional-file-previews) | Follow-up | Completed | Passed | Accepted for the presented unit | [PR #78](https://github.com/bcinarli/pane-peek/pull/78) | [svg-preview-source-editing](evidence/svg-preview-source-editing.md) |
| [PDF preview](plan.md#additional-file-previews) | Follow-up | Completed | Passed | Accepted for the presented unit | [PR #78](https://github.com/bcinarli/pane-peek/pull/78) | [pdf-preview](evidence/pdf-preview.md) |
| [Static HTML preview](plan.md#additional-file-previews) | Follow-up | Completed | Passed | Accepted for the presented unit, including sandbox integration | [PR #78](https://github.com/bcinarli/pane-peek/pull/78) | [html-preview](evidence/html-preview.md) |
| [T20 Browser UI and preview refinements](plan.md#t20-browser-ui-and-preview-refinements) | M5 | Completed | Passed | Accepted | [PR #34](https://github.com/bcinarli/pane-peek/pull/34) | [ui-behaviour-improvements](evidence/ui-behaviour-improvements.md) |
| [T01 Launchable application shell](plan.md#t01-launchable-application-shell) | M1 | Completed | Passed | Accepted | See evidence | [launchable-shell](evidence/launchable-shell.md) |
| [T02 Directory browsing and breadcrumbs](plan.md#t02-directory-browsing-and-breadcrumbs) | M1 | Completed | Passed | Accepted | [PR #4](https://github.com/bcinarli/pane-peek/pull/4) | [directory-browsing](evidence/directory-browsing.md) |
| [T03 Sorting and hidden visibility](plan.md#t03-sorting-and-hidden-visibility) | M1 | Completed | Passed | Accepted | [PR #5](https://github.com/bcinarli/pane-peek/pull/5) | [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md) |
| [T04 Multiple selection and primary item](plan.md#t04-multiple-selection-and-primary-item) | M1 | Completed | Passed | Accepted | [PR #6](https://github.com/bcinarli/pane-peek/pull/6) | [multiple-selection-primary-item](evidence/multiple-selection-primary-item.md) |
| [T14 Context actions and copied paths](plan.md#t14-context-actions-and-copied-paths) | M1 | Completed | Passed | Accepted | [PR #7](https://github.com/bcinarli/pane-peek/pull/7) | [context-actions-copied-paths](evidence/context-actions-copied-paths.md) |
| [T15 Persistent favourites](plan.md#t15-persistent-favourites) | M1 | Completed | Passed | Accepted | [PR #8](https://github.com/bcinarli/pane-peek/pull/8) | [persistent-favourites](evidence/persistent-favourites.md) |
| [T05 Details metadata sidebar](plan.md#t05-details-metadata-sidebar) | M2 | Completed | Passed | Accepted | [PR #12](https://github.com/bcinarli/pane-peek/pull/12) | [details-metadata-sidebar](evidence/details-metadata-sidebar.md) |
| [T06 Read-only preview and highlighting](plan.md#t06-read-only-preview-and-highlighting) | M2 | Completed | Passed | Accepted | [PR #13](https://github.com/bcinarli/pane-peek/pull/13) | [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md) |
| [T07 Preview editor toggle and safe saving](plan.md#t07-preview-editor-toggle-and-safe-saving) | M2 | Completed | Passed | Accepted | [PR #15](https://github.com/bcinarli/pane-peek/pull/15) | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md) |
| [T19 Browser layout modes and expandable Details](plan.md#t19-browser-layout-modes-and-expandable-details) | M2 | Completed | Passed | Accepted | [PR #18](https://github.com/bcinarli/pane-peek/pull/18) | [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md) |
| [T08 New text file and folder](plan.md#t08-new-text-file-and-folder) | M3 | Completed | Passed | Accepted | [PR #19](https://github.com/bcinarli/pane-peek/pull/19) | [new-text-file-folder](evidence/new-text-file-folder.md) |
| [T09 Rename and affected document handling](plan.md#t09-rename-and-affected-document-handling) | M3 | Completed | Passed | Accepted | [PR #20](https://github.com/bcinarli/pane-peek/pull/20) | [rename-affected-document-handling](evidence/rename-affected-document-handling.md) |
| [T10 Copy selected items to the other pane](plan.md#t10-copy-selected-items-to-the-other-pane) | M3 | Completed | Passed | Accepted | [PR #23](https://github.com/bcinarli/pane-peek/pull/23) | [copy-to-other-pane](evidence/copy-to-other-pane.md) |
| [T11 Move selected items to the other pane](plan.md#t11-move-selected-items-to-the-other-pane) | M3 | Completed | Passed | Accepted | [PR #25](https://github.com/bcinarli/pane-peek/pull/25) | [move-to-other-pane](evidence/move-to-other-pane.md) |
| [T12 Delete to Trash](plan.md#t12-delete-to-trash) | M3 | Completed | Passed | Accepted | [PR #26](https://github.com/bcinarli/pane-peek/pull/26) | [delete-to-trash](evidence/delete-to-trash.md) |
| [T13 Drag and drop with Finder](plan.md#t13-drag-and-drop-with-finder) | M3 | Completed | Passed | Accepted | [PR #27](https://github.com/bcinarli/pane-peek/pull/27) | [drag-and-drop-finder](evidence/drag-and-drop-finder.md) |
| [T16 Independent windows and shared operation coordination](plan.md#t16-independent-windows-and-shared-operation-coordination) | M4 | Completed | Passed | Accepted | [PR #29](https://github.com/bcinarli/pane-peek/pull/29) | [independent-windows-shared-operation-coordination](evidence/independent-windows-shared-operation-coordination.md) |
| [T17 Restore the remembered directory pair](plan.md#t17-restore-the-remembered-directory-pair) | M4 | Completed | Passed | Accepted | [`e210e71`](https://github.com/bcinarli/pane-peek/commit/e210e71c5a1e25822862b8baf77d7d58839d8504); [PR #33](https://github.com/bcinarli/pane-peek/pull/33); [PR #30](https://github.com/bcinarli/pane-peek/pull/30) | [window-reopen-restoration](evidence/window-reopen-restoration.md); [original T17](evidence/remembered-directory-pair.md) |
| [T18 MVP acceptance and build documentation](plan.md#t18-mvp-acceptance-and-build-documentation) | M5 | Completed | Waived | Release-specific waiver | [Release-specific deviations](../../decisions/2026-10-19-mvp-release-acceptance-waivers.md) | [mvp-acceptance-build-documentation](evidence/mvp-acceptance-build-documentation.md) |

## App information and open-source documentation

| Task / slug | Status | Verdict | Manual review | Publication / next gate | Evidence |
| --- | --- | --- | --- | --- | --- |
| [about-macchiato](plan.md#about-macchiato-appearance-follow-up) | Completed | Passed | Accepted | [PR #42](https://github.com/bcinarli/pane-peek/pull/42) | [Checks](evidence/about-macchiato.md) |
| [T21 app-information](plan.md#t21-app-information-and-open-source-documentation) | Active | Pending | About accessibility pending | [PR #39](https://github.com/bcinarli/pane-peek/pull/39) | [Checks](evidence/app-information.md) |
| [design-docs-refresh](plan.md#design-and-documentation-refresh) | Completed | Passed | Accepted | [PR #41](https://github.com/bcinarli/pane-peek/pull/41) | [Checks](evidence/design-docs-refresh.md) |

## Post-M1 UI revisions

| Task / slug | Status | Verdict | Manual review | Evidence |
| --- | --- | --- | --- | --- |
| [typescript-classification](plan.md#typescript-preview-classification-follow-up) | Completed | Passed | Accepted | [Checks](evidence/typescript-classification.md); [PR #67](https://github.com/bcinarli/pane-peek/pull/67) |
| [consistent-confirmation-sheets](plan.md#consistent-confirmation-sheets-follow-up) | Completed | Passed | Accepted | [Checks](evidence/consistent-confirmation-sheets.md); [PR #66](https://github.com/bcinarli/pane-peek/pull/66) |
| [browser-cut-paste](plan.md#browser-cutpaste-follow-up) | Completed | Passed | Accepted | [Checks](evidence/browser-cut-paste.md); [PR #52](https://github.com/bcinarli/pane-peek/pull/52) |
| [browser-edit-menu](plan.md#browser-edit-menu-follow-up) | Completed | Passed | Accepted | [Checks](evidence/browser-edit-menu.md); [PR #52](https://github.com/bcinarli/pane-peek/pull/52) |
| [favourites-menu-labels](plan.md#favourites-menu-labels-follow-up) | Completed | Passed | Accepted | [Checks](evidence/favourites-menu-labels.md); [PR #51](https://github.com/bcinarli/pane-peek/pull/51) |
| [command-drag-and-preview-contrast](plan.md#command-drag-and-preview-contrast-follow-up) | Completed | Passed | Accepted | [Checks](evidence/command-drag-and-preview-contrast.md); [PR #40](https://github.com/bcinarli/pane-peek/pull/40) |
| [collision-sheet-backdrop](plan.md#attached-collision-sheet-backdrop-follow-up) | Completed | Passed | Accepted | [Checks](evidence/collision-sheet-backdrop.md); [PR #40](https://github.com/bcinarli/pane-peek/pull/40) |
| [transfer-duplicate-choices](plan.md#transfer-duplicate-choices-follow-up) | Completed | Passed | Accepted | [Checks](evidence/transfer-duplicate-choices.md); [PR #40](https://github.com/bcinarli/pane-peek/pull/40) |
| [dark-macchiato-appearance](plan.md#dark-appearance-follow-up) | Completed | Passed | Accepted | [Checks](evidence/dark-macchiato-appearance.md); [PR #40](https://github.com/bcinarli/pane-peek/pull/40) |
| [native-drag-initiation](plan.md#native-drag-initiation-follow-up) | Completed | Passed | Accepted | [Checks](evidence/native-drag-initiation.md); [PR #40](https://github.com/bcinarli/pane-peek/pull/40) |
| `window-reopen-restoration` | Completed | Passed | Accepted | [Checks](evidence/window-reopen-restoration.md); [`e210e71`](https://github.com/bcinarli/pane-peek/commit/e210e71c5a1e25822862b8baf77d7d58839d8504); [PR #33](https://github.com/bcinarli/pane-peek/pull/33) |
| `directory-table-navigation-crash` | Completed | Passed | Accepted | [Checks](evidence/directory-table-navigation-crash.md); [PR #32](https://github.com/bcinarli/pane-peek/pull/32) |
| `favourite-removal` | Completed | Passed | Accepted | [PR #28](https://github.com/bcinarli/pane-peek/pull/28); [Checks](evidence/favourite-removal.md) |
| `toolbar-backgrounds` | Completed | Passed | Accepted | [Checks](evidence/toolbar-backgrounds.md) |
| `toolbar-dividers` | Completed | Passed | Accepted | [Checks](evidence/toolbar-dividers.md) |
| `panel-headers` | Completed | Passed | Accepted | [Checks](evidence/panel-headers.md) |
| `icons-accent` | Completed | Passed | Accepted | [Checks](evidence/icons-accent.md) |
| `surfaces-details-type` | Completed | Passed | Accepted | [Checks](evidence/surfaces-details-type.md) |
| `muted-selection-prototype` | Completed | Passed | Accepted | [Checks and acceptance](evidence/muted-selection-prototype.md); [PR #21](https://github.com/bcinarli/pane-peek/pull/21) |
| `open-in-finder` | Active | Pending | Pending | [PR #22](https://github.com/bcinarli/pane-peek/pull/22); [Checks](evidence/open-in-finder.md) |
| `fluid-details-preview` | Completed | Passed | Accepted | [Checks](evidence/fluid-details-preview.md); [PR #24](https://github.com/bcinarli/pane-peek/pull/24) |

## Build and repository automation

| Task / slug | Status | Verdict | Manual review | Evidence |
| --- | --- | --- | --- | --- |
| [selective-codeql](plan.md#selective-codeql-scans) | Active | Pending | Local implementation accepted; advanced main scan passed; PR/weekly acceptance pending | [Outcome and limits](evidence/selective-codeql.md); [PR #140](https://github.com/bcinarli/pane-peek/pull/140) |
| [github-1-2-candidate](plan.md#final-release-candidate) | Completed | Waived | Reviewed scope accepted; remaining coverage waived for 1.2.0 (10) | [Candidate scope and limits](evidence/github-1-2-candidate.md); [Published v1.2.0](https://github.com/bcinarli/pane-peek/releases/tag/v1.2.0) |
| [ci-test-state-ownership](plan.md#concurrent-test-state-ownership) | Completed | Passed | Accepted | [Outcome and limits](evidence/ci-test-state-ownership.md); [PR #107](https://github.com/bcinarli/pane-peek/pull/107) |
| [ci-runner-execution](plan.md#ci-workload-isolation) | Completed | Passed | Accepted | [Outcome and limits](evidence/ci-runner-execution.md); [PR #107](https://github.com/bcinarli/pane-peek/pull/107) |
| [listing-operation-test-coordination](plan.md#listing-and-operation-test-coordination) | Completed | Passed | Accepted | [Outcome and limits](evidence/listing-operation-test-coordination.md); [PR #107](https://github.com/bcinarli/pane-peek/pull/107) |
| [save-test-coordination](plan.md#save-test-coordination) | Completed | Passed | Accepted | [Outcome and limits](evidence/save-test-coordination.md); [PR #107](https://github.com/bcinarli/pane-peek/pull/107) |
| [preview-metadata-sort-gates](plan.md#preview-metadata-and-sort-test-gates) | Completed | Passed | Accepted | [Outcome and limits](evidence/preview-metadata-sort-gates.md); [PR #107](https://github.com/bcinarli/pane-peek/pull/107) |
| [editor-test-gate-lifecycle](plan.md#editor-test-gate-lifecycle) | Completed | Passed | Accepted | [Outcome and limits](evidence/editor-test-gate-lifecycle.md); [PR #107](https://github.com/bcinarli/pane-peek/pull/107) |
| [stable-review-signing](plan.md#stable-review-signing) | Completed | Passed | Accepted | [Signing scope and limits](evidence/stable-review-signing.md); [PR #102](https://github.com/bcinarli/pane-peek/pull/102) |
| [app-store-1-1-candidate](plan.md#app-store-110-candidate-and-app-record) | Completed | Passed | Accepted | [Candidate scope and limits](evidence/app-store-1-1-candidate.md) |
| [app-store-archive-preparation](plan.md#app-store-archive-and-signing-preparation) | Completed | Passed | Accepted | [Archive scope and limits](evidence/app-store-archive-preparation.md) |
| [protected-folder-purpose-strings](plan.md#protected-folder-purpose-strings) | Completed | Passed | Accepted for the presented scope | [Purpose strings and propagation limits](evidence/protected-folder-purpose-strings.md); [PR #131](https://github.com/bcinarli/pane-peek/pull/131) |
| [production-sandbox-packaging](plan.md#production-sandbox-packaging) | Completed | Passed | Accepted | [Packaging scope and limits](evidence/production-sandbox-packaging.md); [`329c026`](https://github.com/bcinarli/pane-peek/commit/329c0261ca9f64cdaa2767a46b30e8208fedaed6) |
| [shared-sandbox-distribution](plan.md#shared-sandbox-distribution-readiness) | Ready | Pending | Distribution pending | [Production distribution decision](../../decisions/2026-10-20-production-sandbox-distribution.md) |
| [app-store-sandbox-volumes](plan.md#app-store-sandbox-volume-compatibility) | Completed | Passed | Accepted | [Volume scope and limits](evidence/app-store-sandbox-volumes.md) |
| [app-store-executable-compatibility](plan.md#app-store-executable-file-and-quarantine-compatibility) | Completed | Passed | Accepted | [Executable-file scope and limits](evidence/app-store-executable-compatibility.md) |
| [app-store-sandbox-finder-integration](plan.md#app-store-sandbox-clipboard-drag-and-finder-integration) | Completed | Passed | Accepted | [Transfer scope and limits](evidence/app-store-sandbox-finder-integration.md) |
| [app-store-sandbox-file-operations](plan.md#app-store-sandbox-file-operations) | Completed | Passed | Accepted | [Operation scope and limits](evidence/app-store-sandbox-file-operations.md) |
| [app-store-sandbox-editing](plan.md#app-store-sandbox-editing-and-safe-save) | Completed | Passed | Accepted | [Editing scope and limits](evidence/app-store-sandbox-editing.md) |
| [app-store-sandbox-quick-look](plan.md#app-store-sandbox-quick-look) | Completed | Passed | Accepted | [Quick Look scope and limits](evidence/app-store-sandbox-quick-look.md) |
| [app-store-sandbox-video-previews](plan.md#app-store-sandbox-video-previews) | Completed | Passed | Accepted | [Video preview scope and limits](evidence/app-store-sandbox-video-previews.md) |
| [app-store-sandbox-image-previews](plan.md#app-store-sandbox-image-previews) | Completed | Passed | Accepted | [Image preview scope and limits](evidence/app-store-sandbox-image-previews.md) |
| [app-store-sandbox-text-previews](plan.md#app-store-sandbox-text-previews) | Completed | Passed | Accepted | [Text preview scope and limits](evidence/app-store-sandbox-text-previews.md) |
| [app-store-sandbox-favourites](plan.md#app-store-sandbox-favourites) | Completed | Passed | Accepted | [Favourites scope and limits](evidence/app-store-sandbox-favourites.md) |
| [app-store-saved-access](plan.md#app-store-saved-folder-access) | Completed | Passed | Accepted | [Saved access and limits](evidence/app-store-saved-access.md) |
| [app-store-sandbox-navigation](plan.md#app-store-sandbox-navigation) | Completed | Passed | Accepted | [Navigation scope and limits](evidence/app-store-sandbox-navigation.md) |
| [app-store-sandbox-design](plan.md#app-store-sandbox-and-file-access-design) | Completed | Passed | Accepted | [Access model](evidence/app-store-sandbox-design.md) |
| [ci-workload-isolation](plan.md#ci-workload-isolation) | Completed | Passed | Accepted | [Validation](evidence/ci-workload-isolation.md); [PR #70](https://github.com/bcinarli/pane-peek/pull/70) |
| [final-release-candidate](plan.md#final-release-candidate) | Completed | Passed | Accepted | [Candidate checks and remaining gates](evidence/final-release-candidate.md) |
| [dmg-packaging](plan.md#dmg-packaging) | Completed | Passed | Accepted | [PR #59](https://github.com/bcinarli/pane-peek/pull/59); [Evidence and remaining checks](evidence/dmg-packaging.md) |
| [restoration-timeout-coordination](plan.md#restoration-timeout-coordination) | Completed | Passed | Accepted | [Checks](evidence/restoration-timeout-coordination.md); [PR #57](https://github.com/bcinarli/pane-peek/pull/57) |
| [hosted-signing-notarisation](plan.md#hosted-signing-and-notarisation) | Completed | Passed | Accepted | [Checks](evidence/hosted-signing-notarisation.md); [PR #55](https://github.com/bcinarli/pane-peek/pull/55); [PR #57](https://github.com/bcinarli/pane-peek/pull/57) |
| [notarisation-stapling](plan.md#notarisation-and-stapling) | Completed | Passed | Accepted | [Checks](evidence/notarisation-stapling.md); [PR #53](https://github.com/bcinarli/pane-peek/pull/53) |
| [developer-id-signing](plan.md#developer-id-signing-and-hardened-runtime) | Completed | Passed | Accepted | [Checks](evidence/developer-id-signing.md); [PR #50](https://github.com/bcinarli/pane-peek/pull/50) |
| [ci-async-test-reliability](plan.md#ci-and-merge-checks) | Completed | Passed | Accepted | [PR #49](https://github.com/bcinarli/pane-peek/pull/49); [Checks](evidence/ci-async-test-reliability.md) |
| [github-release-preparation](plan.md#github-release-preparation) | Completed | Passed | Accepted | [Checks](evidence/github-release-preparation.md); [PR #47](https://github.com/bcinarli/pane-peek/pull/47) |
| [release-numbering](plan.md#release-numbering) | Completed | Passed | Accepted | [Checks](evidence/release-numbering.md); [PR #46](https://github.com/bcinarli/pane-peek/pull/46); [PR #45](https://github.com/bcinarli/pane-peek/pull/45) |
| [release-packaging](plan.md#local-release-packaging) | Completed | Passed | Accepted | [Checks](evidence/release-packaging.md) |
| [privacy-secrets-checker](plan.md#privacy-and-secrets-checks) | Completed | Passed | Accepted | [PR #37](https://github.com/bcinarli/pane-peek/pull/37); [PR #38](https://github.com/bcinarli/pane-peek/pull/38); [Hosted hook evidence](evidence/privacy-secrets-checker.md) |
| [github-ci-merge-checks](plan.md#ci-and-merge-checks) | Completed | Passed | Accepted | [PR #36](https://github.com/bcinarli/pane-peek/pull/36); [Hosted success/enforcement evidence](evidence/github-ci-merge-checks.md) |

## Quality remediation

| Task / slug | Status | Verdict | Manual review | Evidence |
| --- | --- | --- | --- | --- |
| [linker-warning-cleanup](plan.md#linker-search-path-compatibility-follow-up) | Completed | Passed | Accepted | [Checks](evidence/linker-warning-cleanup.md); [PR #35](https://github.com/bcinarli/pane-peek/pull/35) |
| [source-warning-cleanup](plan.md#source-warning-compatibility-follow-up) | Completed | Passed | Accepted | [Checks](evidence/source-warning-cleanup.md); [PR #35](https://github.com/bcinarli/pane-peek/pull/35) |
| `m1-sorting-ownership` | Completed | Passed | Accepted | [Checks](evidence/m1-sorting-ownership.md) |
| `m1-selection-interaction` | Completed | Passed | Accepted | [Checks](evidence/m1-selection-interaction.md) |
| `m1-test-gate-diagnostics` | Completed | Passed | Accepted | [Checks](evidence/m1-test-gate-diagnostics.md) |
| `m2-discard-continuation` | Completed | Passed | Accepted | [Checks](evidence/m2-discard-continuation.md) |
| `m3-m4-test-gate-diagnostics` | Completed | Passed | Accepted | [C1.1/F3 checks](evidence/m3-m4-test-gate-diagnostics.md); [PR #31](https://github.com/bcinarli/pane-peek/pull/31) |
| `m3-m4-batch-preflight-assertions` | Completed | Passed | Accepted | [C1.2/F4 checks](evidence/m3-m4-batch-preflight-assertions.md); [PR #31](https://github.com/bcinarli/pane-peek/pull/31) |
| `m3-m4-editor-lock-ownership` | Completed | Passed | Accepted | [C2.1/F1 checks](evidence/m3-m4-editor-lock-ownership.md); [PR #31](https://github.com/bcinarli/pane-peek/pull/31) |
| `m3-m4-creation-availability` | Completed | Passed | Accepted | [C2.2/F2 checks](evidence/m3-m4-creation-availability.md); [PR #31](https://github.com/bcinarli/pane-peek/pull/31) |

### M1 quality remediation

Sorting ownership, selection interaction and test-gate diagnostics are complete for their recorded scopes.

### M2 quality remediation

The bounded Discard-continuation and layout review scope is complete. Whole-app acceptance remains in the criterion matrix.

### Combined M3/M4 quality review

The bounded test-gate, preflight-assertion, editor-lock and creation-availability corrections are complete. [PR #31](https://github.com/bcinarli/pane-peek/pull/31) retains publication provenance; broader native/accessibility scope remains in the criterion matrix.
