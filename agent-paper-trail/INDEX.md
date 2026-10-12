# PanePeek continuation index

## What is in flight?

[001 MVP](specs/001-mvp/README.md) is Active. Read its [tasks](specs/001-mvp/tasks.md) for implementation, manual review and publication state, then [criterion verdicts](specs/001-mvp/validation.md). Open task evidence only for the task being worked on or reviewed.

The [fluid Details preview unit](specs/001-mvp/evidence/fluid-details-preview.md) is accepted and published as [PR #24](https://github.com/bcinarli/pane-peek/pull/24), with build, targeted regressions and isolated native geometry/editor-retention checks passing. It extends A31 with remaining-height sizing in Preview/Edit. Bilal authorised merge and task cleanup on 2026-10-12; the PR records the merge result. Individual accessibility outcomes remain unreported.

The approved [Open in Finder convenience unit](specs/001-mvp/evidence/open-in-finder.md) is implemented and published as [PR #22](https://github.com/bcinarli/pane-peek/pull/22). Bilal deferred manual/accessibility review until after merge; acceptance remains pending. Its context/File actions extend A17/A18 independently of the planned transfer tasks.

## What is the next slice?

[T09](specs/001-mvp/plan.md#t09-rename-and-affected-document-handling) is Completed/Passed, including its [accepted PR correction](specs/001-mvp/evidence/rename-affected-document-handling.md#pr-20-cached-listing-correction). All units and the correction are published as [PR #20](https://github.com/bcinarli/pane-peek/pull/20), with merge pending. [T10](specs/001-mvp/plan.md#t10-copy-selected-items-to-the-other-pane) waits for accepted T09 to merge and its dependency to be verified on `main`. Merge and the next coding unit require separate approval.

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
