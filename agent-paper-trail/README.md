# PanePeek agent paper trail

Use the [continuation index](INDEX.md) to find the active workstream, its next unit and known limits. Apply the [engineering and review rules](engineering-and-review.md) and [validation checklist](validation/checklist.md) across workstreams.

| Document | Purpose |
| --- | --- |
| [Spec](specs/001-mvp/spec.md) | Native baseline, boundaries and A1–A42, including post-MVP extensions. |
| [Plan](specs/001-mvp/plan.md) | Delivery milestones and existing follow-up scopes. |
| [Tasks](specs/001-mvp/tasks.md) | Task status and links to evidence. |
| [Decisions](decisions/README.md) | Accepted choices and their rationale. |
| [Draft design](design/001-mvp/README.md) | Accepted UI and logo references, with production limitations. |
| [Validation](specs/001-mvp/validation.md) | Current acceptance verdicts and task evidence. |
| [Engineering and review](engineering-and-review.md) | Shared engineering, unit review and performance requirements. |
| [Shared checklist](validation/checklist.md) | Verification for every unit. |
| [Notes](notes/README.md) | Durable implementation gotchas as they emerge. |
| [Workflow guidance](prompts/README.md) | Milestone skills and reusable workflow guidance. |
| [Task starter](prompts/task-starter.md) | Reusable prompt for starting or continuing one planned task. |

## Authority and maintenance

The spec owns behavioural requirements; the plan owns task scope/dependencies; the task tracker owns execution status; each spec’s validation table owns criterion verdicts; task evidence owns verified outcomes and limits. Link between them rather than copying requirements into several files.

Keep README files as entry points and indexes. Put findings in focused notes or validation records and link them from the relevant index.

Repository records are the maintained project source.

Update the smallest relevant document when durable project facts change. Decision records are append-only; supersede an accepted choice with a new dated record rather than erasing its rationale. Draft documents may be revised through review.

Add architecture or rules records only when implementation or further workstreams need them. Keep the continuation index aligned with task sequencing and open threads.

Use [dated spec packages](specs/README.md) for new workstreams. Apply release waivers only to the named candidate and scope.

## Repository record content

Keep only essential, current requirements, technical rationale, task state, verified outcomes and material acceptance limits. Keep security assessments, vulnerability details and reproduction material in private records. Exclude discussion history, approval narration and session-specific details, including paraphrased chat, requests and responses, approval sequences, agent activity logs and commit/amendment logistics. Private journals, raw transcripts, credentials and personal or session-generated filesystem paths stay outside the repository.

Keep every evidence submission to a brief outcome, a PR or commit reference and any limits that affect acceptance. Keep current build/run instructions in the contributor guide. Omit test narration, execution steps, fixture recipes, test totals, regression inventories, red/green sequences and low-level verification details. Reconcile completed work into the current contract rather than appending a chronology. Do not add GitHub Actions run or job URLs to paper-trail records; keep those links in private review records. Include dates and platform/toolchain details only when needed to interpret the result. Task and criterion rows link evidence without repeating it.

Keep review and authorisation state compact in the owning task or criterion row: scope, status and date where needed. Decisions retain the reviewed outcome and technical rationale. Record the project consequence without retelling how the discussion or approval unfolded.
