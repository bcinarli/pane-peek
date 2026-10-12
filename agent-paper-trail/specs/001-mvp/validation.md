# PanePeek MVP validation

Status: Active

The [spec](spec.md) owns criteria; [tasks](tasks.md) owns execution and manual-review state. Verdicts are `Pending`, `Passed`, `Failed` or `Waived`. A waiver needs a reason and a durable approval link. A partly exercised criterion stays Pending; completed portions and remaining work are identified below. Task completion does not imply completion of a criterion spanning later slices.

The [historical acceptance snapshot](../../validation/mvp-acceptance-history.md) retains detailed observations and individually unreported checks. [Shared review gates](../../validation/checklist.md) apply to every unit.

## Functional criteria

| Criterion | Status | Verified by | Remaining scope |
| --- | --- | --- | --- |
| A1 Navigation and pane independence | Passed | [T02](evidence/directory-browsing.md), [T15](evidence/persistent-favourites.md), [T07](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A2 Listing and modified-date display | Pending | [T02](evidence/directory-browsing.md), [T03](evidence/sorting-hidden-visibility.md) | Individual light/resize/wake outcomes remain unreported; see historical checks. |
| A3 Navigation errors and stale results | Passed | [T02](evidence/directory-browsing.md) | Complete for the recorded criterion scope. |
| A4 Hidden visibility and Refresh | Pending | [T03](evidence/sorting-hidden-visibility.md); [T10](evidence/copy-to-other-pane.md) automated matching-pane single/batch copy refresh | Copy scope accepted by Bilal through T10; move refresh T11. |
| A5 Copy/move contents and links | Pending | [T10](evidence/copy-to-other-pane.md) automated single/mixed-selection file/folder/package contents and listed-link/source preservation | Copy scope accepted by Bilal through T10; moves T11. |
| A6 Collision and ancestry rejection | Pending | [T10](evidence/copy-to-other-pane.md) automated whole-selection conflicts with no mutation, repeated preflight before the first write, same-item/alias-descendant rejection and late collision preservation | Copy scope accepted by Bilal through T10; moves T11. |
| A7 Transfer failure outcomes | Pending | [T10](evidence/copy-to-other-pane.md) real unreadable-source partial success, injected incomplete destination, completed/failed/unattempted reporting and disk-success/refresh-failure distinction | Copy scope accepted by Bilal through T10; cross-volume move/cleanup T11. |
| A8 Responsive captured operations | Pending | [T10](evidence/copy-to-other-pane.md) controlled in-flight navigation/mode/selection changes, captured selection/destination, union source edit locks and duplicate/current-window mutation rejection | Copy scope accepted by Bilal through T10; moves T11 and shared coordination T16. |
| A9 Affected dirty editors | Pending | [T09](evidence/rename-affected-document-handling.md) automated current-window rename guards and new-path saving; native Cancel/Save. [T10](evidence/copy-to-other-pane.md) automated single/batch Save/Discard/Cancel, failed-Save abort before any copy and saved later-item baseline; both presented unit scopes accepted by Bilal | Other mutations T11–T13 and cross-window handling T16. |
| A10 Bounded asynchronous text preview | Passed | [T06](evidence/read-only-preview-highlighting.md), [T07](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A11 Editing, explicit Save and native undo | Passed | [T07](evidence/preview-editor-safe-saving.md); [T19 sizing/mode regression checks and manual acceptance](evidence/browser-layout-modes-expandable-details.md) | Complete for the recorded criterion scope. |
| A12 Save / Discard / Cancel transitions | Passed | [T07](evidence/preview-editor-safe-saving.md); [T19 layout-only prompt checks and manual acceptance](evidence/browser-layout-modes-expandable-details.md) | Complete for the recorded criterion scope. |
| A13 External-change and write failures | Passed | [T07](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A14 Atomic save and byte/permission preservation | Passed | [T07](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A15 Preview and Edit highlighting | Passed | [T06](evidence/read-only-preview-highlighting.md), [T07](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A16 Shared persistent favourites | Pending | [T15](evidence/persistent-favourites.md), [T07](evidence/preview-editor-safe-saving.md) | Shared cross-window checks remain T16. |
| A17 Context targeting and path copying | Pending | [T14](evidence/context-actions-copied-paths.md), [T07](evidence/preview-editor-safe-saving.md); [T09](evidence/rename-affected-document-handling.md) accepted single-item Rename/context targeting checks; [Open in Finder](evidence/open-in-finder.md) observed guarded context/File targeting | Finder-unit manual acceptance pending; operation targeting continues in later slices. |
| A18 Relative paths and operation menus | Pending | [T14](evidence/context-actions-copied-paths.md); [T08](evidence/new-text-file-folder.md) accepted creation menus; [T09](evidence/rename-affected-document-handling.md) accepted Rename actions; [T10](evidence/copy-to-other-pane.md) single/batch context copy and Shift-F10 routing, both unit scopes accepted; [Open in Finder](evidence/open-in-finder.md) automated routing/failures and observed native file/directory opening | Finder-unit manual/accessibility acceptance pending; remaining handlers T11–T12. |
| A19 Multiple selection and primary item | Pending | [T04](evidence/multiple-selection-primary-item.md), [T07](evidence/preview-editor-safe-saving.md), [accepted native-table selection regressions](evidence/muted-selection-prototype.md) | Independent windows remain T16. |
| A20 Batch preflight and partial outcomes | Pending | [T10 Unit 2](evidence/copy-to-other-pane.md#unit-2-2026-10-12) automated whole-selection preflight with no mutation, stop on first failure, retained completed copies and accurate failed/unattempted paths | Copy batch scope accepted by Bilal through T10; move/Trash/drag batches T11–T13. |
| A21 Finder drag and drop | Pending | No completed task evidence yet. | Planned: T13/T16. |
| A22 Trash and cancellation | Pending | No completed task evidence yet. | Planned: T12/T16. |
| A23 Rename validation and recovery | Passed | [T09](evidence/rename-affected-document-handling.md): original units and [PR correction](evidence/rename-affected-document-handling.md#pr-20-cached-listing-correction) accepted on 2026-10-12; red/green cached visibility/sort recovery and real native refresh-failure checks pass | Complete for the recorded criterion scope. Cross-window mutation coordination remains under A9/A25 and T16. |
| A24 Create text file/folder | Passed | [T08 evidence](evidence/new-text-file-folder.md#pr-19-review-corrections): original implementation and presented corrections accepted on 2026-10-11; canonical selection, pending navigation and refresh-outcome regressions pass | Complete for the recorded criterion scope. |
| A25 Mutation coordination and Refresh | Pending | [T08](evidence/new-text-file-folder.md) accepted creation/refresh; [T09](evidence/rename-affected-document-handling.md) current-window rename/recovery; [T10](evidence/copy-to-other-pane.md) automated single/batch matching-pane refresh, unrelated draft retention and structured partial outcomes through refresh | Other mutations T11–T12 and cross-window coordination T16. |
| A26 Independent windows | Pending | No completed task evidence yet. | Planned: T16. |
| A27 Directory/layout restoration | Pending | No completed task evidence yet. | Planned: T17. |
| A28 Multi-window quit/edit conflicts | Pending | [T07](evidence/preview-editor-safe-saving.md) | Multiple windows remain T16. |
| A29 Breadcrumbs and canonical navigation | Passed | [T02](evidence/directory-browsing.md), [T15](evidence/persistent-favourites.md), [T07](evidence/preview-editor-safe-saving.md) | Complete for the recorded criterion scope. |
| A30 Independent sorting | Pending | [T03](evidence/sorting-hidden-visibility.md) | Cross-window checks remain T16. |
| A31 Details selection and content | Pending | [T05](evidence/details-metadata-sidebar.md), [T06](evidence/read-only-preview-highlighting.md); [accepted fluid height follow-up](evidence/fluid-details-preview.md) | Individual height-follow-up accessibility outcomes remain unreported; independent windows remain T16. |
| A32 Preview/Edit buffer and undo retention | Passed | [T07](evidence/preview-editor-safe-saving.md); [T19 sizing/mode regression checks and manual acceptance](evidence/browser-layout-modes-expandable-details.md) | Complete for the recorded criterion scope. |
| A33 Metadata, displayed path and refresh | Pending | [T14](evidence/context-actions-copied-paths.md), [T05](evidence/details-metadata-sidebar.md), [T07](evidence/preview-editor-safe-saving.md); [T08](evidence/new-text-file-folder.md) accepted creation; [T09](evidence/rename-affected-document-handling.md) observed renamed metadata; [T10](evidence/copy-to-other-pane.md) automated single/batch copy refresh | Remaining mutation refresh T11–T12/T16. |
| A34 Browser modes, state and targets | Pending | [T19](evidence/browser-layout-modes-expandable-details.md) accepted automated/native mode and state checks; [T10](evidence/copy-to-other-pane.md) automated captured single/batch selection/destination, retained later navigation/mode and single-mode/stale-set rejection | T11/T13 transfers and independent windows T16. |
| A35 Details sizing and document retention | Pending | [T19](evidence/browser-layout-modes-expandable-details.md): automated bounds in both modes, preferred-width/proportion recovery, repeated Expand/Restore and native editor retention; native mode/sizing checks. Bilal accepted both units on 2026-10-11. | T16 windows and T17 restoration. |

## Accessibility and native review

| Requirement | Status | Verified by / remaining scope |
| --- | --- | --- |
| Applicable WCAG 2.2 A/AA and native guidance, including justified exclusions | Pending | Affected-unit checks are linked in task evidence. [T18](plan.md#t18-mvp-acceptance-and-build-documentation) consolidates the full applicability audit; no whole-app pass is claimed. |
| Text enlargement mechanism, tested sizes/platform limits and usable narrow/long-path layouts | Pending | [Typography](evidence/surfaces-details-type.md), [T07](evidence/preview-editor-safe-saving.md) and [T19](evidence/browser-layout-modes-expandable-details.md) record accepted unit checks; complete app-wide evidence remains T18. |
| Contrast and non-colour state, keyboard/focus, pointer alternatives and VoiceOver | Pending | [T19](evidence/browser-layout-modes-expandable-details.md), [T08](evidence/new-text-file-folder.md), [T09](evidence/rename-affected-document-handling.md) and [T10](evidence/copy-to-other-pane.md) record affected-checklist acceptance. T10 acceptance covers both presented units; individual settings/outcomes were not separately supplied. [Muted selection](evidence/muted-selection-prototype.md) records native focus checks, calculated colour contrast and Bilal's VoiceOver/visual acceptance. Reuse affected-unit evidence and [recurring accessibility checks](../../validation/checklist.md#accessibility-checks); app-wide coverage remains T18. |
| Native browser modes and Details width | Passed | [Accepted visual design](../../validation/layout-modes-design.md); [T19](evidence/browser-layout-modes-expandable-details.md) records agent-observed mode controls/state, hidden AX removal and retained editor focus, plus Bilal's acceptance of both affected manual/accessibility checklists on 2026-10-11. Individual settings/sizes were not separately supplied; the full app-wide audit remains T18. |
| Production icon and small-size acceptance | Pending | [T01](evidence/launchable-shell.md) validates only the development icon; final refinement remains T18. |

## Milestone quality checkpoint

M1 remediation and the bounded T07/M2 checkpoint are complete for their recorded scopes; [task rows](tasks.md#quality-remediation) and linked evidence own verdicts. Bilal confirmed on 2026-10-11 that the existing review after T07 satisfies the [M2 checkpoint](tasks.md#m2-quality-remediation). Both T19 units are accepted and merged, with publication recorded separately in the tracker. No additional quality analysis or remediation is claimed.

## MVP completion

- [ ] A1–A35 have Passed verdicts or explicitly accepted waivers.
- [ ] App-wide accessibility has complete applicability and evidence.
- [ ] A clean checkout builds, tests, packages and launches using documented instructions.
- [ ] Setup/run and architecture documentation match implementation.
- [ ] Filesystem, save and Finder limitations remain accurate.
