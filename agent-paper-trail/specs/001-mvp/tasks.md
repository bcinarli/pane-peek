# PanePeek MVP tasks

Status: T01–T04 are accepted and merged. T14 Unit 1 is accepted, including the approved test cleanup; commit, push and PR creation are authorised. Merge remains unapproved. Bilal approved its placement before T15/T05 on 2026-10-08; each later coding unit requires approval.

The table follows that order; task IDs remain stable. Accepted draft design is recorded in [the design review](../../validation/design-review.md), separate from native task acceptance.

[The plan](plan.md#tasks) owns task scope, dependencies, tests and exit criteria. This file owns execution state only.

| Task | Milestone | Status | Evidence |
| --- | --- | --- | --- |
| [T01 Launchable application shell](plan.md#t01-launchable-application-shell) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t01-launchable-shell.md); Bilal accepted the current state and confirmed the full manual checklist on 2026-10-04. |
| [T02 Directory browsing and breadcrumbs](plan.md#t02-directory-browsing-and-breadcrumbs) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t02-directory-browsing.md): Bilal accepted the original units and authorised shipment of the shortcut cleanup through merge. [PR #4](https://github.com/bcinarli/pane-peek/pull/4) merged as `50b3c4a`; dependency commits are verified on `main`. No additional manual cleanup test report is claimed. |
| [T03 Sorting and hidden visibility](plan.md#t03-sorting-and-hidden-visibility) | M1 | done | [Units 1–2 and accepted follow-ups](../../validation/t03-sorting-hidden-visibility.md). [PR #5](https://github.com/bcinarli/pane-peek/pull/5) merged as `77a745e`, verified on `main`. |
| [T04 Multiple selection and primary item](plan.md#t04-multiple-selection-and-primary-item) | M1 | done | [Unit 1 accepted on 2026-10-07](../../validation/t04-multiple-selection-primary-item.md). [PR #6](https://github.com/bcinarli/pane-peek/pull/6) merged as `dbdbc59`, verified on `main`. |
| [T14 Context actions and copied paths](plan.md#t14-context-actions-and-copied-paths) | M1 | done | [Unit 1 evidence and acceptance](../../validation/t14-context-actions-copied-paths.md): Bilal confirmed all five presented manual checks on 2026-10-08. Approved test cleanup passes. Commit, push and PR creation are authorised; merge remains unapproved. |
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
