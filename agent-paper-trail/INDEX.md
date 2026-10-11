# PanePeek continuation index

## What is in flight?

[001 MVP](specs/001-mvp/README.md) is Active. Read its [tasks](specs/001-mvp/tasks.md) for implementation, manual review and publication state, then [criterion verdicts](specs/001-mvp/validation.md). Open task evidence only for the task being worked on or reviewed.

## What is the next slice?

[T08 new text file and folder](specs/001-mvp/plan.md#t08-new-text-file-and-folder) is accepted, with [checks and fixtures](specs/001-mvp/evidence/new-text-file-folder.md), and published in open [PR #19](https://github.com/bcinarli/pane-peek/pull/19). Merge remains separately gated. T09 follows merge to `main` and separate coding-unit approval; future dependencies are in the plan.

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
