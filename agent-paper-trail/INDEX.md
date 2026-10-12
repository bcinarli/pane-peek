# PanePeek continuation index

## What is in flight?

[001 MVP](specs/001-mvp/README.md) is Active. Read its [tasks](specs/001-mvp/tasks.md) for implementation, manual review and publication state, then [criterion verdicts](specs/001-mvp/validation.md). Open task evidence only for the task being worked on or reviewed.

The approved [Open in Finder convenience unit](specs/001-mvp/evidence/open-in-finder.md) is implemented and published as [PR #22](https://github.com/bcinarli/pane-peek/pull/22). Bilal deferred manual/accessibility review until after merge; acceptance remains pending. Its context/File actions extend A17/A18 independently of the planned transfer tasks.

## What is the next slice?

[T09](specs/001-mvp/plan.md#t09-rename-and-affected-document-handling) is Completed/Passed, including its [accepted PR correction](specs/001-mvp/evidence/rename-affected-document-handling.md#pr-20-cached-listing-correction). All units and the correction are merged as [PR #20](https://github.com/bcinarli/pane-peek/pull/20). Its full PR head `b42a7f7` is verified on local/live `main` at `ad97158`. [T10](specs/001-mvp/plan.md#t10-copy-selected-items-to-the-other-pane) is Completed/Passed: both units and their presented manual/accessibility scope were accepted on 2026-10-12; [evidence and fixtures](specs/001-mvp/evidence/copy-to-other-pane.md) retain the observed checks and individual unreported observations. Both units are committed locally (`631b618`, `b483897`). The checked integration with `main` at `8c3e9af` preserves the parallel Finder action and has approval for the integration merge commit and PR publication. GitHub review/merge remains pending. T11 remains blocked until T10 is verified on `main` under [decision 0002](decisions/0002-feature-branches-and-prs.md).

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
