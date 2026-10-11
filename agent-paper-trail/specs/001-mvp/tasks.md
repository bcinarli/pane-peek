# PanePeek MVP tasks

Status: T01–T06 and T14–T15 are accepted and merged. All nineteen T06 units and the Details follow-up are accepted. Bilal accepted the final [Makefile Unit 19](../../validation/t06-read-only-preview-highlighting.md#unit-19-makefile-highlighting) checks on 2026-10-11. With separate approval, [PR #13](https://github.com/bcinarli/pane-peek/pull/13) merged into `main` as `4e73984` on 2026-10-11; implementation head `504881d` is verified as an ancestor. T07's dependency is satisfied under [decision 0002](../../decisions/0002-feature-branches-and-prs.md). Bilal accepted all T07 units and corrections on 2026-10-11, including stable filename wrapping and all remaining safe-saving/accessibility checks. [Final manual acceptance](../../validation/t07-preview-editor-safe-saving.md#final-manual-acceptance) records the result. Local implementation commit `9ecf861` exists; accepted header corrections and T07 review records are locally committed as `fb0ae44`. T07 is pushed and [PR #15](https://github.com/bcinarli/pane-peek/pull/15) is open against `main`; merge remains separately gated. The bounded [M2 quality checkpoint](../../validation/t07-preview-editor-safe-saving.md#m2-quality-checkpoint) and its [F1 test-focused unit](../../validation/t07-preview-editor-safe-saving.md#f1-discard-continuation-coverage) are complete. Bilal confirmed all F1 manual checks and authorised its local commit on 2026-10-11.

Current T07 state: [PR review corrections](../../validation/t07-preview-editor-safe-saving.md#pr-15-review-corrections) remain in review. Original feature and F1 acceptance above are retained; R1 keyboard corrections are manually accepted and authorised for commit/push; R2 unavailable controls are authorised and remain unimplemented.

Rows follow the [implementation order](plan.md#design-checkpoint), with T19 after T07 in M2 and T17’s layout restoration in M4. Task IDs remain stable. Accepted draft design is recorded in [the design review](../../validation/design-review.md), separate from native task acceptance.

[The plan](plan.md#tasks) owns task scope, dependencies, tests and exit criteria. This file owns execution state only.

| Task | Milestone | Status | Evidence |
| --- | --- | --- | --- |
| [T01 Launchable application shell](plan.md#t01-launchable-application-shell) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t01-launchable-shell.md); Bilal accepted the current state and confirmed the full manual checklist on 2026-10-04. |
| [T02 Directory browsing and breadcrumbs](plan.md#t02-directory-browsing-and-breadcrumbs) | M1 | done | [Units 1–2 evidence and acceptance](../../validation/t02-directory-browsing.md): Bilal accepted the original units and authorised shipment of the shortcut cleanup through merge. [PR #4](https://github.com/bcinarli/pane-peek/pull/4) merged as `50b3c4a`; dependency commits are verified on `main`. No additional manual cleanup test report is claimed. |
| [T03 Sorting and hidden visibility](plan.md#t03-sorting-and-hidden-visibility) | M1 | done | [Units 1–2 and accepted follow-ups](../../validation/t03-sorting-hidden-visibility.md). [PR #5](https://github.com/bcinarli/pane-peek/pull/5) merged as `77a745e`, verified on `main`. |
| [T04 Multiple selection and primary item](plan.md#t04-multiple-selection-and-primary-item) | M1 | done | [Unit 1 accepted on 2026-10-07](../../validation/t04-multiple-selection-primary-item.md). [PR #6](https://github.com/bcinarli/pane-peek/pull/6) merged as `dbdbc59`, verified on `main`. |
| [T14 Context actions and copied paths](plan.md#t14-context-actions-and-copied-paths) | M1 | done | [Unit 1 evidence and acceptance](../../validation/t14-context-actions-copied-paths.md): Bilal confirmed all five presented manual checks on 2026-10-08. [PR #7](https://github.com/bcinarli/pane-peek/pull/7) merged as `a58e518`, verified on `main` with implementation `dd98d1f`. |
| [T15 Persistent favourites](plan.md#t15-persistent-favourites) | M1 | done | [Unit 1 evidence and acceptance](../../validation/t15-persistent-favourites.md): Bilal confirmed all five manual checks and accepted the restored standard native toolbar on 2026-10-08. Implementation `249370a` was committed/pushed with approval; [PR #8](https://github.com/bcinarli/pane-peek/pull/8) merged into `main` as `5dddcd2`. |
| [T05 Details metadata sidebar](plan.md#t05-details-metadata-sidebar) | M2 | done | [Unit 1 evidence and acceptance](../../validation/t05-details-metadata-sidebar.md): Bilal confirmed all five manual checks and approved the unit on 2026-10-10. Implementation `540b72b` was committed/pushed with approval. Bilal authorised merging [PR #12](https://github.com/bcinarli/pane-peek/pull/12) into `main` on 2026-10-10; the PR records merge state. |
| [T06 Read-only preview and highlighting](plan.md#t06-read-only-preview-and-highlighting) | M2 | done | [All nineteen units and Details follow-up](../../validation/t06-read-only-preview-highlighting.md) implemented and manually accepted. Final 219 tests and native checks pass. Bilal authorised merging [PR #13](https://github.com/bcinarli/pane-peek/pull/13) on 2026-10-11; `main` contains merge `4e73984` and implementation `504881d`. |
| [T07 Preview editor toggle and safe saving](plan.md#t07-preview-editor-toggle-and-safe-saving) | M2 | review | [All units and corrections accepted](../../validation/t07-preview-editor-safe-saving.md#final-manual-acceptance) on 2026-10-11. Local implementation commit `9ecf861`; accepted header corrections and T07 review records are locally committed as `fb0ae44`. [M2 checkpoint](../../validation/t07-preview-editor-safe-saving.md#m2-quality-checkpoint) and F1 remediation complete; F1 accepted and committed as `c2a2925`. Published through [PR #15](https://github.com/bcinarli/pane-peek/pull/15) against `main`; merge pending. [PR review corrections](../../validation/t07-preview-editor-safe-saving.md#pr-15-review-corrections): R1 manually accepted; R2 authorised and awaiting implementation/manual review before merge. |
| [T19 Browser layout modes and expandable Details](plan.md#t19-browser-layout-modes-and-expandable-details) | M2 | not started | Accepted layout direction and [design evidence](../../validation/layout-modes-design.md); separate native coding approvals follow T07 acceptance and merge to `main`. |
| [T08 New text file and folder](plan.md#t08-new-text-file-and-folder) | M3 | not started | None yet. |
| [T09 Rename and affected document handling](plan.md#t09-rename-and-affected-document-handling) | M3 | not started | None yet. |
| [T10 Copy selected items to the other pane](plan.md#t10-copy-selected-items-to-the-other-pane) | M3 | not started | None yet. |
| [T11 Move selected items to the other pane](plan.md#t11-move-selected-items-to-the-other-pane) | M3 | not started | None yet. |
| [T12 Delete to Trash](plan.md#t12-delete-to-trash) | M3 | not started | None yet. |
| [T13 Drag and drop with Finder](plan.md#t13-drag-and-drop-with-finder) | M3 | not started | None yet. |
| [T16 Independent windows and shared operation coordination](plan.md#t16-independent-windows-and-shared-operation-coordination) | M4 | not started | None yet. |
| [T17 Restore remembered directories and layout](plan.md#t17-restore-the-remembered-directory-pair) | M4 | not started | [Accepted restoration decision](../../decisions/2026-10-11-browser-layout-modes-and-details-sizing.md); native implementation pending. |
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


## M2 quality remediation

Bilal accepted F1 and authorised its bounded test-focused unit on 2026-10-11. He subsequently confirmed all manual checks and authorised its local commit. The direct unit list is complete: one of one units implemented and accepted, committed as `c2a2925` and published through [PR #15](https://github.com/bcinarli/pane-peek/pull/15). Merge retains its separate gate.

| Unit | Status | Evidence |
| --- | --- | --- |
| U1/F1: Discard continuation coverage | done | [Strengthened existing transition assertions](../../validation/t07-preview-editor-safe-saving.md#f1-discard-continuation-coverage). Disposable regression red, focused/full green and native selection smoke pass. Bilal confirmed all manual checks and authorised local commit on 2026-10-11. No production changes. |
