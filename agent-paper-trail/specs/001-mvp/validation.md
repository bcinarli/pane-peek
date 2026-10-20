# PanePeek MVP validation

Status: Completed for 1.0.0 (7) with release-specific waivers

The [spec](spec.md) owns criteria; [tasks](tasks.md) owns execution and manual-review state. Verdicts are `Pending`, `Passed`, `Failed` or `Waived`. A waiver needs a reason and a durable approval link. A partly exercised criterion stays Pending; completed portions and remaining work are identified below. Task completion does not imply completion of a criterion spanning later slices.

[Shared review gates](../../validation/checklist.md) apply to every unit.

## Additional file previews

A36–A39 follow the [accepted preview decision](../../decisions/2026-10-20-additional-file-previews.md) and have separate acceptance; the 1.0.0 waiver does not cover them.

| Criterion | Status | Evidence | Remaining scope |
| --- | --- | --- | --- |
| A36 Rendered Markdown and YAML front matter | Pending | [Markdown front matter](evidence/markdown-front-matter.md); [Link policy](evidence/markdown-link-policy.md) | Link-policy scope accepted; light appearance, enlarged text and remaining accessibility checks are unverified. |
| A37 SVG preview and source editing | Pending | [SVG preview and source editing](evidence/svg-preview-source-editing.md) | Light/enlarged text, remaining accessibility checks and macOS 26 verification. |
| A38 PDF preview | Pending | [PDF preview](evidence/pdf-preview.md) | Light appearance, remaining accessibility checks and macOS 26 verification. |
| A39 Static HTML preview | Pending | [Static HTML preview](evidence/html-preview.md) | Light/enlarged text, remaining accessibility checks and macOS 26 verification. |

## Functional criteria

The [1.0.0 (7) acceptance waiver](../../decisions/2026-10-19-mvp-release-acceptance-waivers.md) covers unverified portions marked Waived below; existing passing observations remain valid. Deferred checks remain listed for follow-up.

| Criterion | Status | Verified by | Remaining scope |
| --- | --- | --- | --- |
| A1 Navigation and pane independence | Passed | [directory-browsing](evidence/directory-browsing.md); [persistent-favourites](evidence/persistent-favourites.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [directory-table-navigation-crash](evidence/directory-table-navigation-crash.md) | Complete for the recorded criterion scope. |
| A2 Listing and modified-date display | Waived | [directory-browsing](evidence/directory-browsing.md); [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md); [directory-table-navigation-crash](evidence/directory-table-navigation-crash.md) | Individual appearance, resize/wake and accessibility scope remains unverified. |
| A3 Navigation errors and stale results | Passed | [directory-browsing](evidence/directory-browsing.md) | Complete for the recorded criterion scope. |
| A4 Hidden visibility and Refresh | Waived | [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md) | Complete native Refresh and accessibility scope remains unverified. |
| A5 Copy/move contents and links | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete native file/folder/link transfer scope remains unverified. |
| A6 Collision and ancestry rejection | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete native collision-choice and accessibility scope remains unverified. |
| A7 Transfer failure outcomes | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete partial-failure and physical-volume scope remains unverified. |
| A8 Responsive captured operations | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [m3-m4-editor-lock-ownership](evidence/m3-m4-editor-lock-ownership.md) | Complete interactive cross-window operation scope remains unverified. |
| A9 Affected dirty editors | Waived | [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [delete-to-trash](evidence/delete-to-trash.md) | Complete cross-window dirty-draft and accessibility scope remains unverified. |
| A10 Bounded text/media preview and Quick Look | Waived | [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [typescript-classification](evidence/typescript-classification.md) | Complete native media/Quick Look and accessibility scope remains unverified. |
| A11 Editing, explicit Save and native undo | Passed | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [Save identity correction](evidence/svg-preview-source-editing.md) | Complete for the recorded criterion scope. |
| A12 Save / Discard / Cancel transitions | Passed | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md) | Complete for the recorded criterion scope. |
| A13 External-change and write failures | Passed | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A14 Atomic save and byte/permission preservation | Pending | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [Permission preservation](evidence/save-permission-preservation.md); [Ownership preservation](evidence/save-owner-preservation.md) | Reviewed ownership-preservation scope accepted; macOS 26 and other filesystems remain unverified. |
| A15 Preview and Edit highlighting | Passed | [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [typescript-classification](evidence/typescript-classification.md) | Complete for the recorded criterion scope. |
| A16 Shared persistent favourites | Waived | [favourites-menu-labels](evidence/favourites-menu-labels.md); [persistent-favourites](evidence/persistent-favourites.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [favourite-removal](evidence/favourite-removal.md) | Complete live shared-favourites and accessibility scope remains unverified. |
| A17 Context targeting and path copying | Waived | [context-actions-copied-paths](evidence/context-actions-copied-paths.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [open-in-finder](evidence/open-in-finder.md) | Complete native context-targeting and Finder acceptance remains pending. |
| A18 Relative paths and operation menus | Waived | [context-actions-copied-paths](evidence/context-actions-copied-paths.md); [new-text-file-folder](evidence/new-text-file-folder.md); [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [copy-to-other-pane](evidence/copy-to-other-pane.md) | Complete native operation-menu and Finder acceptance remains pending. |
| A19 Multiple selection and primary item | Waived | [multiple-selection-primary-item](evidence/multiple-selection-primary-item.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [muted-selection-prototype](evidence/muted-selection-prototype.md) | Complete independent-window selection acceptance remains unverified. |
| A20 Batch preflight and partial outcomes | Waived | [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete native batch/partial-outcome acceptance remains unverified. |
| A21 Finder drag and drop | Waived | [drag-and-drop-finder](evidence/drag-and-drop-finder.md) | Complete Finder/cross-window gestures and accessibility scope remains unverified. |
| A22 Trash and cancellation | Waived | [delete-to-trash](evidence/delete-to-trash.md); [browser-edit-menu](evidence/browser-edit-menu.md) | Complete cross-window Trash and accessibility scope remains unverified. |
| A23 Rename validation and recovery | Passed | [rename-affected-document-handling](evidence/rename-affected-document-handling.md) | Complete for the recorded criterion scope. |
| A24 Create text file/folder | Passed | [new-text-file-folder](evidence/new-text-file-folder.md) | Complete for the recorded criterion scope. |
| A25 Mutation coordination and Refresh | Waived | [new-text-file-folder](evidence/new-text-file-folder.md); [rename-affected-document-handling](evidence/rename-affected-document-handling.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md) | Complete live cross-window mutation/Refresh and accessibility scope remains unverified. |
| A26 Independent windows | Waived | [independent-windows-shared-operation-coordination](evidence/independent-windows-shared-operation-coordination.md) | Complete live multi-window/favourites and accessibility scope remains unverified. |
| A27 Directory/layout restoration | Waived | [remembered-directory-pair](evidence/remembered-directory-pair.md); [window-reopen-restoration](evidence/window-reopen-restoration.md) | Complete native restoration, display and accessibility scope remains unverified. |
| A28 Multi-window quit/edit conflicts | Waived | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [independent-windows-shared-operation-coordination](evidence/independent-windows-shared-operation-coordination.md) | Complete live Quit/same-file conflict acceptance remains unverified. |
| A29 Breadcrumbs and canonical navigation | Passed | [directory-browsing](evidence/directory-browsing.md); [persistent-favourites](evidence/persistent-favourites.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A30 Independent sorting | Waived | [sorting-hidden-visibility](evidence/sorting-hidden-visibility.md); [ui-behaviour-improvements](evidence/ui-behaviour-improvements.md) | Complete live cross-window sorting and accessibility scope remains unverified. |
| A31 Details selection and content | Waived | [details-metadata-sidebar](evidence/details-metadata-sidebar.md); [read-only-preview-highlighting](evidence/read-only-preview-highlighting.md); [fluid-details-preview](evidence/fluid-details-preview.md) | Complete live cross-window Details/media and accessibility scope remains unverified. |
| A32 Preview/Edit buffer and undo retention | Passed | [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [Save identity correction](evidence/svg-preview-source-editing.md) | Complete for the recorded criterion scope. |
| A33 Metadata, displayed path and refresh | Waived | [context-actions-copied-paths](evidence/context-actions-copied-paths.md); [details-metadata-sidebar](evidence/details-metadata-sidebar.md); [preview-editor-safe-saving](evidence/preview-editor-safe-saving.md); [new-text-file-folder](evidence/new-text-file-folder.md) | Complete live cross-window metadata/Refresh scope remains unverified. |
| A34 Browser modes, state and targets | Waived | [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md); [copy-to-other-pane](evidence/copy-to-other-pane.md); [move-to-other-pane](evidence/move-to-other-pane.md); [drag-and-drop-finder](evidence/drag-and-drop-finder.md) | Complete live mode/menu/editor-retention and accessibility scope remains unverified. |
| A35 Details sizing and document retention | Waived | [browser-layout-modes-expandable-details](evidence/browser-layout-modes-expandable-details.md) | Complete live divider/keyboard/relaunch and accessibility scope remains unverified. |


## Accepted UI refinement scope

The [UI refinement evidence](evidence/ui-behaviour-improvements.md) covers the current browser, preview and operation presentation. The functional matrix retains full-criterion limits; draft safeguards remain binding.

## Accessibility and native review

The [release-specific waiver](../../decisions/2026-10-19-mvp-release-acceptance-waivers.md) covers the unverified audit, settings and icon checks; it does not claim accessibility conformance.

| Requirement | Status | Verified by / remaining scope |
| --- | --- | --- |
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
| Optimised, isolated arm64 package with matching version/build, notices and checksum; unchanged development build | Passed | [Packaging checks](evidence/release-packaging.md) |

## Release preparation

| Requirement | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| Local App Store 1.1.0 (8) candidate and app-record preparation | Passed | [Candidate scope and limits](evidence/app-store-1-1-candidate.md) |
| Native App Store archive and local Store export preparation | Passed | [Archive scope and limits](evidence/app-store-archive-preparation.md) |
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
