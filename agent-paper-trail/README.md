# PanePeek agent paper trail

This folder owns durable project context for PanePeek. Start with the [continuation index](INDEX.md) to find current work, binding choices and open follow-ups without private chat history.

## Current work

[001 MVP](specs/001-mvp/README.md) is the active workstream. Use its [task tracker](specs/001-mvp/tasks.md) for execution/review state and its [criterion verdicts](specs/001-mvp/validation.md) for acceptance state. The [shared checklist](validation/checklist.md) owns project-wide review gates.

The [design sources](design/001-mvp/README.md) index the accepted UI/logo references and their production limits.

| Document | Purpose |
| --- | --- |
| [Spec](specs/001-mvp/spec.md) | Product behaviour, boundaries and A1–A35 acceptance criteria. |
| [Plan](specs/001-mvp/plan.md) | Nineteen observable tasks across five milestones, with T19 layout work separate from T07. |
| [Tasks](specs/001-mvp/tasks.md) | Task status and links to evidence. |
| [Decisions](decisions/README.md) | Accepted choices and their rationale. |
| [Draft design](design/001-mvp/README.md) | Accepted UI and logo references, with production limitations. |
| [Validation](specs/001-mvp/validation.md) | Current acceptance verdicts and task evidence. |
| [Shared checklist](validation/checklist.md) | Required review gates for every unit. |
| [Notes](notes/README.md) | Durable implementation gotchas as they emerge. |
| [Workflow guidance](prompts/README.md) | Milestone skills and reusable workflow guidance. |
| [Task starter](prompts/task-starter.md) | Reusable prompt for starting or continuing one planned task. |

## Authority and maintenance

The spec owns behavioural requirements; the plan owns task scope/dependencies; the task tracker owns execution status; each spec’s validation table owns criterion verdicts; task evidence owns recorded checks. Link between them rather than copying requirements into several files.

Keep README files as entry points and indexes. Put findings in focused notes or validation records and link them from the relevant index.

Repository copies are the maintained source from this point. Earlier chat outputs are reference drafts.

Update the smallest relevant document when durable project facts change. Decision records are append-only; supersede an accepted choice with a new dated record rather than erasing its rationale. Draft documents may be revised through review.

Keep private session journals, raw transcripts, credentials and machine-specific observations outside this folder. Add architecture or rules records only when implementation or further workstreams need them. Keep the continuation index aligned with task sequencing and open threads.
