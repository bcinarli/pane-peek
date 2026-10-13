# PanePeek continuation index

## What is in flight?

[001 MVP](specs/001-mvp/README.md) is Active. Read its [tasks](specs/001-mvp/tasks.md) for implementation, manual review and publication state, then [criterion verdicts](specs/001-mvp/validation.md). Open task evidence only for the task being worked on or reviewed.

The [fluid Details preview unit](specs/001-mvp/evidence/fluid-details-preview.md) is accepted and published as [PR #24](https://github.com/bcinarli/pane-peek/pull/24), with build, targeted regressions and isolated native geometry/editor-retention checks passing. It extends A31 with remaining-height sizing in Preview/Edit. Bilal authorised merge and task cleanup on 2026-10-12; the PR records the merge result. Individual accessibility outcomes remain unreported.

The approved [Open in Finder convenience unit](specs/001-mvp/evidence/open-in-finder.md) is implemented and published as [PR #22](https://github.com/bcinarli/pane-peek/pull/22). Bilal deferred manual/accessibility review until after merge; acceptance remains pending. Its context/File actions extend A17/A18 independently of the planned transfer tasks.

## What is the next slice?

[T09](specs/001-mvp/plan.md#t09-rename-and-affected-document-handling) is Completed/Passed, including its [accepted PR correction](specs/001-mvp/evidence/rename-affected-document-handling.md#pr-20-cached-listing-correction). All units and the correction are merged as [PR #20](https://github.com/bcinarli/pane-peek/pull/20). Its full PR head `b42a7f7` is verified on local/live `main` at `ad97158`. [T10](specs/001-mvp/plan.md#t10-copy-selected-items-to-the-other-pane) is Completed/Passed: both units and their presented manual/accessibility scope were accepted on 2026-10-12; [evidence and fixtures](specs/001-mvp/evidence/copy-to-other-pane.md) retain the observed checks and individual unreported observations. Both units (`631b618`, `b483897`) and approved integration merge `526ecce` are published in [PR #23](https://github.com/bcinarli/pane-peek/pull/23). The checked integration with `main` at `8c3e9af` preserves the parallel Finder action. Bilal authorised PR #23 merge and task-workspace cleanup on 2026-10-12. T11 is Completed/Passed on Bilal’s acceptance of both presented units on 2026-10-12. Feature commits `ac8d45d`/`ef5296a` are published in merged [PR #25](https://github.com/bcinarli/pane-peek/pull/25), targeting `main`. [Evidence and fixtures](specs/001-mvp/evidence/move-to-other-pane.md) retain checks, acceptance and individual unreported native/accessibility outcomes. Local/live `main` at `9a669b0` contains T10’s full PR closing head `d06f484`, verified before implementation under [decision 0002](decisions/0002-feature-branches-and-prs.md). No T11 coding units remain. Bilal authorised PR #25 merge and task-workspace cleanup on 2026-10-12. T11 full closing head `09c5c16` is verified on local/live `main` at merge `fe6517b` before T12. [T12 Unit 1](specs/001-mvp/evidence/delete-to-trash.md) is accepted with feature commit `bd9b236`. [Unit 2](specs/001-mvp/evidence/delete-to-trash.md#unit-2-2026-10-13) adds batch Trash, accepted on 2026-10-13; 403 tests, build and production batch Trash/restore checks pass. T12 is Completed/Passed with no planned coding units remaining. Both feature commits `bd9b236`/`f7ee6a5` are published in open [PR #26](https://github.com/bcinarli/pane-peek/pull/26), targeting `main`; merge requires separate approval; individual native/accessibility outcomes remain unreported. No later task has started; T13 awaits the merged full T12 closing head on `main`.

## What binds implementation?

- [MVP spec](specs/001-mvp/spec.md) owns behaviour, scope and accessibility.
- [Decisions](decisions/README.md) identify accepted and superseded choices. The [layout decision](decisions/2026-10-11-browser-layout-modes-and-details-sizing.md) carries forward appearance/logo direction and replaces the always-dual layout.
- [Source-control decision](decisions/0002-feature-branches-and-prs.md) requires feature branches, task review and separate commit/push/merge approval.
- [Shared validation checklist](validation/checklist.md) applies to every unit. [Design sources](design/001-mvp/README.md) distinguish visual acceptance from native acceptance.

## What remains open?

- [Protected-folder permissions](notes/0004-protected-folder-permissions.md): startup trigger and denied-access follow-up remain unresolved.
- [Rendered Markdown](notes/0006-rendered-markdown-preview.md): a future proposal outside the MVP.
- App-wide accessibility and production icon acceptance remain T18; a completed UI task does not close those gates.

## Which workflows can be reused?

[Repository paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md) and [milestone workflow guidance](prompts/README.md). Historical fixture recipes and detailed observations remain under [validation history](validation/README.md); use the spec package for current state.
