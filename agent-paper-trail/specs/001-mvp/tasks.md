# PanePeek MVP tasks

Status: T01–T04 and T14 are accepted and merged. Bilal accepted T15, including the restored standard native toolbar buttons. PR #8 merged into `main` as `5dddcd2` on 2026-10-08. Bilal approved T14's placement before T15/T05; each later coding unit requires approval.

The table follows that order; task IDs remain stable. Accepted draft design is recorded in [the design review](../../validation/design-review.md), separate from native task acceptance.

[The plan](plan.md#tasks) owns task scope, dependencies, tests and exit criteria. This file owns execution state only.

| Task | Milestone | Status | Evidence |
| --- | --- | --- | --- |
| [T01 Launchable application shell](plan.md#t01-launchable-application-shell) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t01-launchable-shell.md); Bilal accepted the current state and confirmed the full manual checklist on 2026-10-04. |
| [T02 Directory browsing and breadcrumbs](plan.md#t02-directory-browsing-and-breadcrumbs) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t02-directory-browsing.md): Bilal accepted the original units and authorised shipment of the shortcut cleanup through merge. [PR #4](https://github.com/bcinarli/pane-peek/pull/4) merged as `50b3c4a`; dependency commits are verified on `main`. No additional manual cleanup test report is claimed. |
| [T03 Sorting and hidden visibility](plan.md#t03-sorting-and-hidden-visibility) | M1 | done | [Units 1–2 and accepted follow-ups](../../validation/t03-sorting-hidden-visibility.md). [PR #5](https://github.com/bcinarli/pane-peek/pull/5) merged as `77a745e`, verified on `main`. |
| [T04 Multiple selection and primary item](plan.md#t04-multiple-selection-and-primary-item) | M1 | done | [Unit 1 accepted on 2026-10-07](../../validation/t04-multiple-selection-primary-item.md). [PR #6](https://github.com/bcinarli/pane-peek/pull/6) merged as `dbdbc59`, verified on `main`. |
| [T14 Context actions and copied paths](plan.md#t14-context-actions-and-copied-paths) | M1 | done | [Unit 1 evidence and acceptance](../../validation/t14-context-actions-copied-paths.md): Bilal confirmed all five presented manual checks on 2026-10-08. [PR #7](https://github.com/bcinarli/pane-peek/pull/7) merged as `a58e518`, verified on `main` with implementation `dd98d1f`. |
| [T15 Persistent favourites](plan.md#t15-persistent-favourites) | M1 | done | [Unit 1 evidence and acceptance](../../validation/t15-persistent-favourites.md): Bilal confirmed all five manual checks and accepted the restored standard native toolbar on 2026-10-08. Implementation `249370a` was committed/pushed with approval; [PR #8](https://github.com/bcinarli/pane-peek/pull/8) merged into `main` as `5dddcd2`. |
| [T05 Details metadata sidebar](plan.md#t05-details-metadata-sidebar) | M2 | done | [Unit 1 evidence and acceptance](../../validation/t05-details-metadata-sidebar.md): Bilal confirmed all five manual checks and approved the unit on 2026-10-10, then authorised commit, push and PR creation. Merge remains pending. |
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

## Post-M1 UI revisions

| Unit | Status | Evidence |
| --- | --- | --- |
| Toolbar backgrounds | done | [Native background API and validation](../../validation/ui-toolbar-backgrounds.md). Bilal confirmed all manual checks and authorised commit on 2026-10-09. |
| Toolbar dividers | done | [Owned native split container and validation](../../validation/ui-toolbar-dividers.md). Bilal confirmed the live-drag correction and authorised commit on 2026-10-09. |
| Panel header alignment | done | [Shared header height and native breadcrumb checks](../../validation/ui-panel-headers.md). Bilal confirmed the remaining manual review checks work OK on 2026-10-09 and dismissed the enlarged-text-header concern. |
| Icons and app accent | done | [Bundled draft icons and native Mauve accent](../../validation/ui-icons-accent.md). Bilal confirmed the remaining manual review checks work OK on 2026-10-09. |
| Content surfaces and Details typography | done | [Native surface roles and Apple text styles](../../validation/ui-surfaces-details-type.md). Bilal confirmed text enlargement, contrast and VoiceOver checks passed, then accepted the remaining manual review checks on 2026-10-09. |

## M1 quality remediation

Bilal accepted all three findings from the bounded M1 code-quality analysis on 2026-10-09. Each unit retains its own implementation and manual-review gate.

| Unit | Status | Evidence |
| --- | --- | --- |
| C1/F2: pane owns sorting | done | [Sorting ownership validation](../../validation/m1-sorting-ownership.md). Bilal confirmed validations passed, accepted the unit and authorised commit on 2026-10-09. |
| C2/F1: selection interaction regression coverage | done | [Selection interaction validation](../../validation/m1-selection-interaction.md). Implementation and red/green/native checks complete; Bilal confirmed all manual checks passed and authorised commit on 2026-10-09. |
| C3/F3: asynchronous test gate failure diagnostics | done | [Test gate diagnostics validation](../../validation/m1-test-gate-diagnostics.md). Red/green failure-path checks, full suite and rebuilt app smoke complete; Bilal confirmed the review checklist passed and authorised commit/push/PR on 2026-10-09. |
