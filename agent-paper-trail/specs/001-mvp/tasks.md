# PanePeek MVP tasks

Status: T01, T02 and T03 are done for implementation/manual acceptance. [PR #5](https://github.com/bcinarli/pane-peek/pull/5) remains open against `main`; merge is unapproved and T03 is not yet on `main`. Revised T14/T15 sequencing and each later coding unit require approval.

The table follows that proposed order; task IDs remain stable. Accepted draft design is recorded in [the design review](../../validation/design-review.md), separate from native task acceptance.

[The plan](plan.md#tasks) owns task scope, dependencies, tests and exit criteria. This file owns execution state only.

| Task | Milestone | Status | Evidence |
| --- | --- | --- | --- |
| [T01 Launchable application shell](plan.md#t01-launchable-application-shell) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t01-launchable-shell.md); Bilal accepted the current state and confirmed the full manual checklist on 2026-10-04. |
| [T02 Directory browsing and breadcrumbs](plan.md#t02-directory-browsing-and-breadcrumbs) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t02-directory-browsing.md): Bilal accepted the original units and authorised shipment of the shortcut cleanup through merge. [PR #4](https://github.com/bcinarli/pane-peek/pull/4) merged as `50b3c4a`; dependency commits are verified on `main`. No additional manual cleanup test report is claimed. |
| [T03 Sorting and hidden visibility](plan.md#t03-sorting-and-hidden-visibility) | M1 | done | [Units 1–2 and follow-up evidence](../../validation/t03-sorting-hidden-visibility.md): Bilal accepted both units, the sorting-performance correction and test/document cleanup. All 23 tests pass. Follow-up code/test commit `0f052fc`; branch publication uses [PR #5](https://github.com/bcinarli/pane-peek/pull/5), open against `main`. Merge is unapproved. |
| [T04 Multiple selection and primary item](plan.md#t04-multiple-selection-and-primary-item) | M1 | not started | None yet. |
| [T14 Context actions and copied paths](plan.md#t14-context-actions-and-copied-paths) | M1 | not started | None yet. |
| [T15 Persistent favourites](plan.md#t15-persistent-favourites) | M1 | not started | None yet. |
| [T05 Details metadata sidebar](plan.md#t05-details-metadata-sidebar) | M2 | not started | None yet. |
| [T06 Read-only preview and highlighting](plan.md#t06-read-only-preview-and-highlighting) | M2 | not started | None yet. |
| [T07 Preview editor toggle and safe saving](plan.md#t07-preview-editor-toggle-and-safe-saving) | M2 | not started | None yet. |
| [T08 New text file and folder](plan.md#t08-new-text-file-and-folder) | M3 | not started | None yet. |
| [T09 Rename and affected document handling](plan.md#t09-rename-and-affected-document-handling) | M3 | not started | None yet. |
| [T10 Copy selected items to the other pane](plan.md#t10-copy-selected-items-to-the-other-pane) | M3 | not started | None yet. |
| [T11 Move selected items to the other pane](plan.md#t11-move-selected-items-to-the-other-pane) | M3 | not started | None yet. |
| [T12 Delete to Trash](plan.md#t12-delete-to-trash) | M3 | not started | None yet. |
| [T13 Drag and drop with Finder](plan.md#t13-drag-and-drop-with-finder) | M3 | not started | None yet. |
| [T16 Independent windows and shared operation coordination](plan.md#t16-independent-windows-and-shared-operation-coordination) | M4 | not started | None yet. |
| [T17 Restore the remembered directory pair](plan.md#t17-restore-the-remembered-directory-pair) | M4 | not started | None yet. |
| [T18 MVP acceptance and build documentation](plan.md#t18-mvp-acceptance-and-build-documentation) | M5 | not started | None yet. |

Use statuses `not started`, `in progress`, `review`, `done`, `blocked` or `deferred`. A task in manual review stays `review` until accepted; do not mark it done on automated results alone.

Add evidence links when work exists. Keep detailed test results outside this table and link to the relevant validation record. Do not use this tracker for session narration.

Done records implementation/manual acceptance. Verify dependency changes are on `main` before starting the next task, following [decision 0002](../../decisions/0002-feature-branches-and-prs.md).
