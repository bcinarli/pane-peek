# PanePeek task starter

Status: Active

Use this prompt to start or continue one planned task. Choose `<WORKSTREAM_PATH>` from the continuation index and `<TASK_ID>` from that package's tracker. Existing native follow-ups remain under `agent-paper-trail/specs/001-mvp/`; MVP delivery is complete. Provide a previous journal separately only when continuing work that needs it.

```text
Start or continue PanePeek task <TASK_ID> in this repository.

Complete the active bootstrap and session-continuity requirements before significant work. Read AGENTS.md, then agent-paper-trail/README.md.

Use the repository-local panepeek-paper-trail skill. If your runtime cannot discover it, read agent-paper-trail/skills/panepeek-paper-trail/SKILL.md directly; no personal skill installation is required.

Use <WORKSTREAM_PATH> as the workstream and retain the native baseline and shared review rules under agent-paper-trail/specs/001-mvp/:
- Read README.md, tasks.md and validation.md to establish review, execution and acceptance state.
- Read the selected task and its dependencies in the package's plan.md, or its README when that owns the implementation handoff.
- Read mapped requirements and acceptance criteria in the package's spec.md, or its README when that owns the specification. Retain the native baseline's engineering/accessibility rules and plan's shared workflow gates.
- Read relevant accepted decisions, notes and agent-paper-trail/validation/checklist.md. Open only the selected task’s evidence file; use current contributor instructions and disposable fixtures as needed.
- Inspect repository state and only the code/tests needed for this task’s first unit. Use a supplied previous journal if relevant.

Verify dependencies and existing approval against the tracker and explicit session instructions. If a required input or review is missing, identify the smallest gap. Do not infer implementation approval from document creation or tracker status, and do not request an approval already given for this unit.

First response: state the task’s current status, proposed first coding unit, expected files, acceptance criteria covered, validation and the visible result/manual checklist. Use high-value red/green behaviour tests, or build/manual checks for layout and packaging. Name any unresolved decision that changes the work. If approval is absent, stop with “Waiting for your approval before proceeding” and identify the unit.

Once authorised, verify the task feature branch follows agent-paper-trail/decisions/0002-feature-branches-and-prs.md, then implement only that unit using the spec’s engineering rules. Do not expand into later tasks or opportunistic refactors. If the task needs multiple coding units, retain a review checkpoint between them.

After the unit, apply tighten then probe, run the required checks, and present the launchable app, run/fixture instructions, test evidence and manual checklist. Keep the task Active with verdict Pending until Bilal accepts the manual result. Record manual review and publication separately. Update tasks.md, validation.md and the task’s evidence file truthfully, and record durable decisions/gotchas in the paper trail.

Stop for review before the next unit or task. Follow the plan’s milestone quality workflow when applicable. Commit and push require separate approval.
```
