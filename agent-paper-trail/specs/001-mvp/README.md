# PanePeek MVP

Status: Active

Read [spec](spec.md), [plan](plan.md), [tasks](tasks.md) and [validation](validation.md) to establish behaviour, approach, current task state and criterion verdicts. Open `evidence/<task-slug>.md` only for the task being worked on or reviewed; its links retain detailed historical checks and disposable fixtures.

T08 and its presented review corrections are accepted and merged through [PR #19](https://github.com/bcinarli/pane-peek/pull/19), verified on local/live `main` at `9464287` before T09. T09's original units and [PR correction](evidence/rename-affected-document-handling.md#pr-20-cached-listing-correction) are accepted and merged as [PR #20](https://github.com/bcinarli/pane-peek/pull/20). Its full PR head `b42a7f7` is verified on local/live `main` at `ad97158`; T09 is Completed/Passed. T10 is Completed/Passed. Bilal accepted both units and their presented manual/accessibility scope on 2026-10-12; automated/build checks pass. Both units (`631b618`, `b483897`) and approved integration merge `526ecce` with `main` at `8c3e9af` are published in [PR #23](https://github.com/bcinarli/pane-peek/pull/23). Bilal authorised PR #23 merge and task-workspace cleanup on 2026-10-12. T11 is Completed/Passed on Bilal’s acceptance of both presented units on 2026-10-12. Feature commits `ac8d45d`/`ef5296a` are published in merged [PR #25](https://github.com/bcinarli/pane-peek/pull/25), with [checks, fixtures and acceptance](evidence/move-to-other-pane.md#unit-2-2026-10-12). T10’s full closing head `d06f484` is verified on local/live `main` at `9a669b0` under [decision 0002](../../decisions/0002-feature-branches-and-prs.md). No T11 coding units remain. Bilal authorised PR #25 merge and task-workspace cleanup on 2026-10-12. T11 full closing head `09c5c16` is verified on local/live `main` at merge `fe6517b` before T12; later-unit coding approval remains separate. Individual native/accessibility and real second-volume outcomes remain unreported.

[T12 Unit 1](evidence/delete-to-trash.md) adds confirmed single-item Trash, accepted with feature commit `bd9b236`. [Unit 2](evidence/delete-to-trash.md#unit-2-2026-10-13) adds batch Trash, accepted on 2026-10-13 after 403 tests, app build and production batch Trash/restore checks passed. T12 is Completed/Passed; no planned coding units remain. Both feature commits `bd9b236`/`f7ee6a5` are published in [PR #26](https://github.com/bcinarli/pane-peek/pull/26), targeting `main`; Bilal authorised PR #26 merge on 2026-10-13; individual native/accessibility outcomes remain unreported.

[T13](evidence/drag-and-drop-finder.md) is Completed/Passed: both planned units were accepted overall on 2026-10-13. Incoming Finder drops and captured outgoing selections support guarded copy/Command-move and pane-to-pane transfers. Final 426 tests, build/review packaging and launch/process checks pass; individual native/Finder/accessibility outcomes remain unreported. Unit 1 commit is `f92a12d`; Unit 2 commit and PR publication are authorised and in progress. The M3 quality checkpoint remains outstanding; merge remains separate.

| Record | Purpose |
| --- | --- |
| [Specification](spec.md) | Product behaviour, A1–A35 and engineering rules. |
| [Implementation plan](plan.md) | Task scope, dependencies and unit checkpoints. |
| [Task tracker](tasks.md) | Task status, verdict, manual review and publication. |
| [Validation](validation.md) | Criterion verdicts and remaining scope. |
| [Evidence](evidence/) | Concise task checks and closure verdicts. |
| [Decisions](../../decisions/README.md) | Binding choices and supersession. |
| [Design sources](../../design/001-mvp/README.md) | Accepted editable references and production limits. |
| [Shared checklist](../../validation/checklist.md) | Required unit gates. |
| [Historical evidence](../../validation/README.md) | Detailed observations and fixture recipes. |
