# PanePeek MVP validation

Status: Completed for 1.0.0 (7) with release-specific waivers

GitHub 1.2.0 (10) candidate acceptance is complete with the [1.2 release-specific waiver](../../decisions/2026-10-26-1-2-release-acceptance-waivers.md). Criterion tables retain their verification coverage: Pending and earlier Waived portions remain unverified, accepted only for this candidate under the new waiver.

The [spec](spec.md) owns criteria; [tasks](tasks.md) owns execution and manual-review state. Verdicts are `Pending`, `Passed`, `Failed` or `Waived`. A waiver needs a reason and a durable approval link. A partly exercised criterion stays Pending; completed portions and remaining work are identified below. Task completion does not imply completion of a criterion spanning later slices.

[Shared review gates](../../validation/checklist.md) apply to every unit.

## Git and agent worktrees

[G1–G8](../2026-10-27-git-worktrees/validation.md) own acceptance for the optional read-only Git extension. All remain Pending; earlier release waivers do not cover this work. Existing browser/editor criteria remain binding for affected behaviour.

## Copy file content

| Criterion | Status | Evidence | Remaining scope |
| --- | --- | --- | --- |
| A42 Current source buffer and accessible clipboard action | Pending | [Copy file content](evidence/copy-file-content.md) | Reviewed unit accepted. Light appearance, full VoiceOver, enlargement/system settings and native macOS 26 remain unverified. |

## Recursive current-folder search

| Criterion | Status | Evidence | Remaining scope |
| --- | --- | --- | --- |
| A41 Recursive name search, contextual Find and compact navigation controls | Pending | [Recursive search](evidence/recursive-folder-search.md); [Contextual Find](evidence/contextual-find.md) | Recursive-search and contextual Find units accepted; Light/narrow/enlarged layouts, full VoiceOver/system settings and native macOS 26 remain unverified. |

## Additional file previews

A36–A39 follow the [accepted preview decision](../../decisions/2026-10-20-additional-file-previews.md) and have separate acceptance; the 1.0.0 waiver does not cover them.

| Criterion | Status | Evidence | Remaining scope |
| --- | --- | --- | --- |
| A36 Rendered Markdown and YAML front matter | Pending | [Markdown front matter](evidence/markdown-front-matter.md); [Link policy](evidence/markdown-link-policy.md); [Contextual Find](evidence/contextual-find.md) | Link-policy and rendered Find scopes accepted; light appearance, enlarged text and remaining accessibility checks are unverified. |
| A37 SVG preview and source editing | Pending | [SVG preview and source editing](evidence/svg-preview-source-editing.md) | Light/enlarged text, remaining accessibility checks and macOS 26 verification. |
| A38 PDF preview | Pending | [PDF preview](evidence/pdf-preview.md) | Light appearance, remaining accessibility checks and macOS 26 verification. |
| A39 Static HTML preview | Pending | [Static HTML preview](evidence/html-preview.md); [Contextual Find](evidence/contextual-find.md) | Rendered Find scope accepted; Light/enlarged text, remaining accessibility checks and macOS 26 verification. |

## GitHub release updates

| Criterion | Status | Evidence | Remaining scope |
| --- | --- | --- | --- |
| A40 GitHub release checks, DMG download and manual installation | Pending | [Update acceptance](../2026-10-24-github-release-updates/validation.md) | Native behaviour, privacy, artifact validation, sandbox handoff, Store exclusion and affected accessibility checks. |

## Functional criteria

The [directory-listing optimisation](evidence/directory-listing-metadata.md) is accepted for its recorded local performance and native scope; it does not change existing criterion verdicts or privacy requirements.

The [1.0.0 (7) acceptance waiver](../../decisions/2026-10-19-mvp-release-acceptance-waivers.md) covers unverified portions marked Waived below; existing passing observations remain valid. Deferred checks remain listed for follow-up.

| Criterion | Status | Verified by | Remaining scope |
| --- | --- | --- | --- |
| A1 Navigation and pane independence | Pending | [directory-browsing](evidence/directory-browsing.md); [persistent-favourites](evidence/persistent-favourites.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [directory-table-navigation-crash](evidence/directory-table-navigation-crash.md); [root-navigation-bookmark](evidence/root-navigation-bookmark.md); [Back and Forward](evidence/back-forward-navigation.md) | Back/Forward is accepted for the reviewed scope; complete appearance, layout and accessibility acceptance remains unverified. Earlier recorded navigation/editor scope remains verified. |
| A2 Listing and modified-date display | Pending | [directory-browsing](evidence/directory-browsing.md); [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md); [directory-table-navigation-crash](evidence/directory-table-navigation-crash.md); [Column resizing](evidence/resizable-browser-columns.md) | Column resizing is accepted for the reviewed scope; complete appearance, resize/wake and accessibility scope remain unverified. |
| A3 Navigation errors and stale results | Pending | [directory-browsing](evidence/directory-browsing.md); [root-navigation-bookmark](evidence/root-navigation-bookmark.md); [Back and Forward](evidence/back-forward-navigation.md) | Back/Forward is accepted for the reviewed scope; complete appearance, layout and accessibility acceptance remains unverified. Earlier recorded navigation/editor scope remains verified. |
| A4 Hidden visibility and Refresh | Waived | [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md) | Complete native Refresh and accessibility scope remains unverified. |
| A5 Copy/move contents and links | Pending | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md); [Same-folder copies](evidence/same-folder-copies.md) | Same-folder copies are accepted for the reviewed scope. Complete native file/folder/link transfer scope remains unverified. |
| A6 Collision and ancestry rejection | Pending | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md); [Same-folder copies](evidence/same-folder-copies.md) | Same-folder copies are accepted for the reviewed scope. Complete native collision-choice and accessibility scope remains unverified. |
| A7 Transfer failure outcomes | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete partial-failure and physical-volume scope remains unverified. |
| A8 Responsive captured operations | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [m3-m4-editor-lock-ownership](evidence/m3-m4-editor-lock-ownership.md) | Complete interactive cross-window operation scope remains unverified. |
| A9 Affected dirty editors | Waived | [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [delete-to-trash](evidence/delete-to-trash.md) | Complete cross-window dirty-draft and accessibility scope remains unverified. |
| A10 Bounded text/media preview and Quick Look | Waived | [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [typescript-classification](evidence/typescript-classification.md) | Complete native media/Quick Look and accessibility scope remains unverified. |
| A11 Editing, explicit Save and native undo | Pending | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [Save identity correction](evidence/svg-preview-source-editing.md); [Highlighting flashes](evidence/syntax-highlighting-flashes.md); [Editor line numbers](evidence/editor-line-numbers.md); [Viewport stability](evidence/editor-viewport-stability.md); [Contextual Find](evidence/contextual-find.md) | Contextual Find scope accepted; Light appearance, full VoiceOver, enlarged text/contrast, physical resizing and native macOS 26 checks remain unverified. |
| A12 Save / Discard / Cancel transitions | Pending | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [Back and Forward](evidence/back-forward-navigation.md) | Back/Forward is accepted for the reviewed scope; complete appearance, layout and accessibility acceptance remains unverified. Earlier recorded navigation/editor scope remains verified. |
| A13 External-change and write failures | Passed | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A14 Atomic save and byte/permission preservation | Pending | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [Permission preservation](evidence/save-permission-preservation.md); [Ownership preservation](evidence/save-owner-preservation.md) | Reviewed ownership-preservation scope accepted; macOS 26 and other filesystems remain unverified. |
| A15 Preview and Edit highlighting | Pending | [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [typescript-classification](evidence/typescript-classification.md); [Highlighting flashes](evidence/syntax-highlighting-flashes.md); [Viewport stability](evidence/editor-viewport-stability.md) | Current-draft publication and reviewed Dark-mode scope pass; Light appearance, VoiceOver, enlarged text/contrast and macOS 26 checks remain unverified. |
| A16 Shared persistent favourites | Waived | [favourites-menu-labels](evidence/favourites-menu-labels.md); [persistent-favourites](evidence/persistent-favourites.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [favourite-removal](evidence/favourite-removal.md) | Complete live shared-favourites and accessibility scope remains unverified. |
| A17 Context targeting and path copying | Waived | [context-actions-copied-paths](evidence/context-actions-copied-paths.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [open-in-finder](evidence/open-in-finder.md) | Complete native context-targeting and Finder acceptance remains pending. |
| A18 Relative paths and operation menus | Pending | [context-actions-copied-paths](evidence/context-actions-copied-paths.md); [new-text-file-folder](evidence/new-text-file-folder.md); [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [Duplicate menu](evidence/duplicate-menu.md); [Context-menu grouping](evidence/context-menu-grouping.md) | Duplicate and context-menu grouping are accepted for the reviewed scope. Complete native operation-menu and Finder acceptance remains pending. |
| A19 Multiple selection and primary item | Waived | [multiple-selection-primary-item](evidence/multiple-selection-primary-item.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [muted-selection-prototype](evidence/muted-selection-prototype.md) | Complete independent-window selection acceptance remains unverified. |
| A20 Batch preflight and partial outcomes | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete native batch/partial-outcome acceptance remains unverified. |
| A21 Finder drag and drop | Waived | [drag-and-drop-finder](evidence/drag-and-drop-finder.md) | Complete Finder/cross-window gestures and accessibility scope remains unverified. |
| A22 Trash and cancellation | Waived | [delete-to-trash](evidence/delete-to-trash.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete cross-window Trash and accessibility scope remains unverified. |
| A23 Rename validation and recovery | Passed | [rename-affected-document-handling](evidence/rename-affected-document-handling.md) | Complete for the recorded criterion scope. |
| A24 Create text file/folder | Passed | [new-text-file-folder](evidence/new-text-file-folder.md) | Complete for the recorded criterion scope. |
| A25 Mutation coordination and Refresh | Waived | [new-text-file-folder](evidence/new-text-file-folder.md); [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md) | Complete live cross-window mutation/Refresh and accessibility scope remains unverified. |
| A26 Independent windows | Pending | [independent-windows-shared-operation-coordination](evidence/independent-windows-shared-operation-coordination.md); [Fresh defaults](evidence/fresh-single-pane-windows.md) | Fresh One Pane/expanded Details defaults are accepted; complete multi-window/favourites and accessibility scope remains unverified. |
| A27 Directory/layout restoration | Pending | [remembered-directory-pair](evidence/remembered-directory-pair.md); [window-reopen-restoration](evidence/window-reopen-restoration.md); [Fresh defaults](evidence/fresh-single-pane-windows.md) | Fresh defaults and retained saved modes are accepted; native Dock reopening and complete display/accessibility scope remain unverified. |
| A28 Multi-window quit/edit conflicts | Waived | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [independent-windows-shared-operation-coordination](evidence/independent-windows-shared-operation-coordination.md) | Complete live Quit/same-file conflict acceptance remains unverified. |
| A29 Breadcrumbs and canonical navigation | Passed | [directory-browsing](evidence/directory-browsing.md); [persistent-favourites](evidence/persistent-favourites.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A30 Independent sorting | Pending | [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md); [ui-behaviour-improvements](evidence/ui-behaviour-improvements.md); [Column resizing](evidence/resizable-browser-columns.md) | Native headings are accepted. Complete live cross-window sorting and accessibility scope remains unverified. |
| A31 Details selection and content | Pending | [details-metadata-sidebar](evidence/details-metadata-sidebar.md); [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md); [fluid-details-preview](evidence/fluid-details-preview.md); [Collapsible File information](evidence/collapsible-file-information.md); [Heading target](evidence/file-information-heading-target.md) | File information collapse is accepted for the reviewed scope; the heading target is accepted; complete live Details/media and accessibility scope remains unverified. |
| A32 Preview/Edit buffer and undo retention | Passed | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [Save identity correction](evidence/svg-preview-source-editing.md) | Complete for the recorded criterion scope. |
| A33 Metadata, displayed path and refresh | Pending | [context-actions-copied-paths](evidence/context-actions-copied-paths.md); [details-metadata-sidebar](evidence/details-metadata-sidebar.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [new-text-file-folder](evidence/new-text-file-folder.md); [Collapsible File information](evidence/collapsible-file-information.md); [Heading target](evidence/file-information-heading-target.md) | File information collapse is accepted for the reviewed scope; the heading target is accepted; complete live cross-window metadata/Refresh scope remains unverified. |
| A34 Browser modes, state and targets | Pending | [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [Back and Forward](evidence/back-forward-navigation.md); [Column resizing](evidence/resizable-browser-columns.md) | Column-width retention and Back/Forward are accepted for the reviewed scope. Complete native mode/menu/editor retention, appearance and accessibility scope remains unverified. |
| A35 Details sizing and document retention | Pending | [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [Fresh defaults](evidence/fresh-single-pane-windows.md); [Single-pane width](evidence/single-pane-details-width.md) | 66%/50% sizing is accepted for the reviewed scope; complete physical resizing, appearance, accessibility and macOS 26 acceptance remain unverified. |


## Accepted UI refinement scope

The [UI refinement evidence](evidence/ui-behaviour-improvements.md) covers the current browser, preview and operation presentation. The functional matrix retains full-criterion limits; draft safeguards remain binding.

## Accessibility and native review

The [release-specific waiver](../../decisions/2026-10-19-mvp-release-acceptance-waivers.md) covers the unverified audit, settings and icon checks; it does not claim accessibility conformance.

| Requirement | Status | Verified by / remaining scope |
| --- | --- | --- |
| Native title-bar dragging and configured double-click action | Pending | [Title-bar interaction](evidence/title-bar-interaction.md) Physical title/centre dragging and native Fill pass; remaining layout, accessibility and macOS 26 acceptance is pending. |
| Macchiato dark surfaces and filled-control labels | Waived | [Appearance evidence](evidence/dark-macchiato-appearance.md); [Backdrop correction](evidence/collision-sheet-backdrop.md); [Preview contrast correction](evidence/command-drag-and-preview-contrast.md) Unverified scope remains covered only by the release-specific waiver. |
| Applicable WCAG 2.2 A/AA and native guidance, including justified exclusions | Waived |  Unverified scope remains covered only by the release-specific waiver. |
| Text enlargement mechanism, tested sizes/platform limits and usable narrow/long-path layouts | Waived | [Typography](evidence/surfaces-details-type.md); [T07](evidence/preview-editor-safe-saving.md); [T19](evidence/browser-layout-modes-expandable-details.md) Unverified scope remains covered only by the release-specific waiver. |
| Contrast and non-colour state, keyboard/focus, pointer alternatives and VoiceOver | Waived | [T19](evidence/browser-layout-modes-expandable-details.md); [T08](evidence/new-text-file-folder.md); [T09](evidence/rename-affected-document-handling.md); [T10](evidence/copy-to-other-pane.md); [Muted selection](evidence/muted-selection-prototype.md); [recurring accessibility checks](../../validation/checklist.md#accessibility-checks) Unverified scope remains covered only by the release-specific waiver. |
| Native browser modes and Details width | Passed | [Accepted visual design](../../validation/layout-modes-design.md); [T19](evidence/browser-layout-modes-expandable-details.md) |
| Production icon and small-size acceptance | Waived | [T01](evidence/launchable-shell.md) Unverified scope remains covered only by the release-specific waiver. |

## Milestone quality checkpoint

The bounded M1, M2 and combined M3/M4 corrections are complete for their recorded scopes. [Task rows](tasks.md#quality-remediation) retain ownership and references; they do not establish whole-app acceptance.

## CI and merge checks

The [CI workflow](evidence/github-ci-merge-checks.md), [async coordination](evidence/ci-async-test-reliability.md) and [workload isolation](evidence/ci-workload-isolation.md) are accepted for their infrastructure scopes. Product and accessibility verdicts remain separate.

Hosted validation passes on Swift 6.3.3 and macOS 26 for [editor gates](evidence/editor-test-gate-lifecycle.md), [preview, metadata and sort gates](evidence/preview-metadata-sort-gates.md), [save coordination](evidence/save-test-coordination.md), [listing/operation coordination](evidence/listing-operation-test-coordination.md), [runner execution](evidence/ci-runner-execution.md), and [shared test-state ownership](evidence/ci-test-state-ownership.md).

[Selective CodeQL scans](evidence/selective-codeql.md) have local implementation acceptance and verified advanced main uploads/source coverage. Hosted PR scan/skip behaviour and the first weekly execution remain Pending. Existing required checks and product/accessibility verdicts retain their scope.

## App information and repository documentation

| Requirement | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| Apache-2.0 licence, project-origin NOTICE and factual privacy documentation | Passed | [T21 Unit 1](evidence/app-information.md) |
| Consistent packaged version/build metadata | Passed | [T21 Unit 2](evidence/app-information.md) |
| Accessible About with offline notices and browser/draft isolation | Pending | [T21 Unit 4](evidence/app-information.md); [app-owned Macchiato follow-up](evidence/about-macchiato.md) Full acceptance remains pending. |
| Changelog and contributor guide | Passed | [T21 Unit 3](evidence/app-information.md) |
| Product README and native screenshots | Passed | [T21 Unit 5](evidence/app-information.md) |

The [design and documentation scope](evidence/design-docs-refresh.md) is accepted; About accessibility remains separately pending.

## Privacy and secrets checks

The [privacy checker](evidence/privacy-secrets-checker.md) is accepted for CI and opt-in hooks. File-content limits and manual binary/prose review remain necessary; the checker does not establish product acceptance.

## Local release packaging

| Requirement | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| Explicit certificate signing for isolated sandbox review builds with stable identity across changed executables | Passed | [Signing scope and remaining checks](evidence/stable-review-signing.md) |
| Optimised, isolated arm64 package with matching version/build, notices and checksum; unchanged development build | Passed | [Packaging checks](evidence/release-packaging.md) |

## Release preparation

| Requirement | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| GitHub 1.2.0 (10) candidate metadata, app changelog and local review packages | Passed | [Verified metadata and dated app notes](evidence/github-1-2-candidate.md) |
| GitHub 1.2.0 (10) hosted signing/notarisation and downloaded DMG/ZIP integrity | Passed | [Verified signed-package scope](evidence/github-1-2-candidate.md) |
| GitHub 1.2.0 (10) reported macOS 26 functional smoke review | Passed | [Reported scope; individual checklist coverage unverified](evidence/github-1-2-candidate.md) |
| GitHub 1.2.0 (10) release acceptance of remaining unverified coverage | Waived | [Candidate-specific scope and mandatory gates](../../decisions/2026-10-26-1-2-release-acceptance-waivers.md) |
| GitHub 1.2.0 (10) public release and published-download verification | Passed | [Anonymous downloads match the reviewed candidate](evidence/github-1-2-candidate.md) |
| Local App Store 1.1.0 (8) candidate and app-record preparation | Passed | [Candidate scope and limits](evidence/app-store-1-1-candidate.md) |
| Native App Store archive and local Store export preparation | Passed | [Archive scope and limits](evidence/app-store-archive-preparation.md) |
| Resource-specific Desktop, Documents and Downloads explanations in native and scripted bundles | Passed | [Purpose strings and current-release acceptance](evidence/protected-folder-purpose-strings.md) |
| Production sandbox packaging and persisted access under the production identity | Passed | [Packaging scope and limits](evidence/production-sandbox-packaging.md) |
| Reviewed App Store sandbox access design | Passed | [Access model and remaining compatibility limits](evidence/app-store-sandbox-design.md) |
| Scoped cross-volume operations | Passed | [Volume scope and limits](evidence/app-store-sandbox-volumes.md) |
| Executable permissions and quarantine handling | Passed | [Compatibility scope and limits](evidence/app-store-executable-compatibility.md) |
| Scoped clipboard, drag and Finder integration | Passed | [Transfer acceptance limits](evidence/app-store-sandbox-finder-integration.md) |
| Scoped file operations with captured folder access | Passed | [Operation acceptance limits](evidence/app-store-sandbox-file-operations.md) |
| Scoped text editing and safe Save | Passed | [Editing acceptance limits](evidence/app-store-sandbox-editing.md) |
| Scoped read-only Quick Look | Passed | [Quick Look acceptance limits](evidence/app-store-sandbox-quick-look.md) |
| Scoped read-only video previews | Passed | [Video preview acceptance limits](evidence/app-store-sandbox-video-previews.md) |
| Scoped read-only image previews | Passed | [Image preview acceptance limits](evidence/app-store-sandbox-image-previews.md) |
| Scoped read-only text previews and item metadata | Passed | [Text preview acceptance limits](evidence/app-store-sandbox-text-previews.md) |
| Sandbox favourites with saved access and reconnection | Passed | [Favourites acceptance limits](evidence/app-store-sandbox-favourites.md) |
| Persistent read-only access and bookmark-backed restoration | Passed | [Saved access and acceptance limits](evidence/app-store-saved-access.md) |
| Isolated sandbox review build with explicit folder access and scoped navigation | Passed | [Navigation checks and acceptance limits](evidence/app-store-sandbox-navigation.md) |
| Final candidate metadata, app-only changelog and matching review packages | Passed | [Candidate validation and remaining gates](evidence/final-release-candidate.md) |
| Explicit build allocation, deliberate version selection, unchanged rebuild metadata and atomic same-file concurrency protection | Passed | [Numbering checks](evidence/release-numbering.md) |
| Read-only GitHub preparation from an eligible main commit, with matching ZIP/checksum and draft notes | Passed | [Preparation checks](evidence/github-release-preparation.md) |
| Explicit Developer ID signing with Hardened Runtime, secure timestamp and verification before archive generation | Passed | [Signing checks](evidence/developer-id-signing.md) |
| Accepted notarisation, matching log/ticket, stapled app and regenerated verified distribution archive | Passed | [Notarisation checks](evidence/notarisation-stapling.md) |
| Restoration timeout diagnostics await actual failure before checking terminal state | Passed | [Coordination checks](evidence/restoration-timeout-coordination.md) |
| Themed read-only DMG with verified signing/notarisation, mounted app and ZIP alternative | Passed | [DMG/ZIP evidence and remaining checks](evidence/dmg-packaging.md) |
| Main-only hosted credentials, cleanup before outputs, signed/notarised artifacts and verified hosted download | Passed | [Hosted checks](evidence/hosted-signing-notarisation.md) |

## MVP completion

T18 is completed with the [candidate-specific deviations](../../decisions/2026-10-19-mvp-release-acceptance-waivers.md). Unchecked items below retain their unverified status.

- [x] A1–A35 have Passed verdicts or explicitly accepted waivers.
- [ ] App-wide accessibility has complete applicability and evidence.
- [ ] A clean checkout builds, tests, packages and launches using documented instructions.
- [ ] Setup/run and architecture documentation match implementation.
- [ ] Filesystem, save and Finder limitations remain accurate.
