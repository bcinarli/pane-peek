# PanePeek agent paper trail

This folder owns durable project context for PanePeek. Start with the [continuation index](INDEX.md) to find current work, binding choices and open follow-ups without private chat history.

## Current work

[Git and agent worktrees](specs/2026-10-27-git-worktrees/README.md) owns optional local Git inspection, worktree discovery/navigation, pane status and unified diffs. Its task tracker owns coding readiness and manual acceptance.

[GitHub release updates](specs/2026-10-24-github-release-updates/README.md) owns the update spec, implementation plan, task state and acceptance for GitHub DMG downloads and manual installation.

The [website](specs/2026-10-17-website/README.md) is a separate workstream for the static site. Its validation matrix owns remaining live and accessibility acceptance.

[001 MVP](specs/001-mvp/README.md) is the active workstream. Use its [task tracker](specs/001-mvp/tasks.md) for execution/review state and its [criterion verdicts](specs/001-mvp/validation.md) for acceptance state. The [shared checklist](validation/checklist.md) owns project-wide review gates.

The [design sources](design/001-mvp/README.md) index the accepted UI/logo references and their production limits.

| Document | Purpose |
| --- | --- |
| [Spec](specs/001-mvp/spec.md) | Product behaviour, boundaries and A1–A41 acceptance criteria. |
| [Plan](specs/001-mvp/plan.md) | Observable tasks across five milestones, including T19 layout and T20 UI/preview refinements. |
| [Tasks](specs/001-mvp/tasks.md) | Task status and links to evidence. |
| [Decisions](decisions/README.md) | Accepted choices and their rationale. |
| [Draft design](design/001-mvp/README.md) | Accepted UI and logo references, with production limitations. |
| [Validation](specs/001-mvp/validation.md) | Current acceptance verdicts and task evidence. |
| [Shared checklist](validation/checklist.md) | Required review gates for every unit. |
| [Notes](notes/README.md) | Durable implementation gotchas as they emerge. |
| [Workflow guidance](prompts/README.md) | Milestone skills and reusable workflow guidance. |
| [Task starter](prompts/task-starter.md) | Reusable prompt for starting or continuing one planned task. |

## Authority and maintenance

The spec owns behavioural requirements; the plan owns task scope/dependencies; the task tracker owns execution status; each spec’s validation table owns criterion verdicts; task evidence owns verified outcomes and limits. Link between them rather than copying requirements into several files.

Keep README files as entry points and indexes. Put findings in focused notes or validation records and link them from the relevant index.

Repository records are the maintained project source.

Update the smallest relevant document when durable project facts change. Decision records are append-only; supersede an accepted choice with a new dated record rather than erasing its rationale. Draft documents may be revised through review.

Add architecture or rules records only when implementation or further workstreams need them. Keep the continuation index aligned with task sequencing and open threads.

## Repository record content

Keep only essential, current requirements, technical rationale, task state, verified outcomes and material acceptance limits. Keep security assessments, vulnerability details and reproduction material in private records. Exclude discussion history, approval narration and session-specific details, including paraphrased chat, requests and responses, approval sequences, agent activity logs and commit/amendment logistics. Private journals, raw transcripts, credentials and personal or session-generated filesystem paths stay outside the repository.

Keep every evidence submission to a brief outcome, a PR or commit reference and any limits that affect acceptance. Keep current build/run instructions in the contributor guide. Omit test narration, execution steps, fixture recipes, test totals, regression inventories, red/green sequences and low-level verification details. Reconcile completed work into the current contract rather than appending a chronology. Do not add GitHub Actions run or job URLs to paper-trail records; keep those links in private review records. Include dates and platform/toolchain details only when needed to interpret the result. Task and criterion rows link evidence without repeating it.

Keep review and authorisation state compact in the owning task or criterion row: scope, status and date where needed. Decisions retain the reviewed outcome and technical rationale. Record the project consequence without retelling how the discussion or approval unfolded.
