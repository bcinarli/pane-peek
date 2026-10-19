---
name: panepeek-paper-trail
description: Maintain PanePeek's in-repo paper trail while implementing or reviewing a task, reconciling a requirement change, or preparing a PR handoff. Record task state, criterion verdicts and evidence without requiring a personal agent-paper-trail installation.
metadata:
  version: 0.1.0
  paper-trail-conventions: 0.3.0
---

# PanePeek paper-trail workflow

Use the repository records as project authority. This workflow needs no personal skills, private preferences or session journals. All paths below are relative to the repository root; locate it before reading them.

## Establish the task

Read `AGENTS.md`, then `agent-paper-trail/INDEX.md`. Read the relevant spec package's `spec.md`, `plan.md`, `tasks.md` and `validation.md`, followed by the applicable decisions and notes. Open evidence only for the task being implemented or reviewed. Use `agent-paper-trail/validation/checklist.md` for shared gates and `README.md` for actual build/run commands.

Identify the task, current branch, dependency publication, existing approval and next coding unit. A Ready row is not coding approval. Retain the unit, manual-review and source-control gates in the plan; reuse approval already given for this scope.

If a request changes accepted intent, present the conflict and obtain review of the relevant requirement/decision before implementing the new direction. A Draft note is not accepted scope. Preserve explicit session instructions: if record changes are excluded, report the resulting gap and required reconciliation in the handoff instead of silently editing records or claiming the paper trail is current.

## Record the unit

Update the smallest relevant records after meaningful implementation or validation:

| Information | Maintained home |
| --- | --- |
| Task progress, manual review and publication | The task's row in `tasks.md` |
| Acceptance-criterion verdict and remaining scope | The criterion's row in `validation.md` |
| Executed checks, results and provenance | `evidence/<task-slug>.md` |
| Changed intent or implementation approach | `spec.md` or `plan.md`, with a reviewed decision/note link |
| A durable choice or repeated gotcha | `agent-paper-trail/decisions/` or `notes/` |

Keep progress and check results out of specs/plans. A PR description can link evidence but does not replace the repository records. Apply the [repository record content boundary](../../README.md#repository-record-content) before saving any record.

Use task statuses `Ready`, `Active`, `Blocked`, `Completed`, `Abandoned` and verdicts `Pending`, `Passed`, `Failed`, `Waived`. Keep an implemented task Active/Pending while manual review is pending. A partially exercised full criterion stays Pending, with verified portions and remaining checks linked. Record publication separately from acceptance.

Start task evidence with this header, matching the filename and task row:

```yaml
---
task: <task-slug>
verdict: Pending
closed: ""
---
```

Summarise each evidence unit in one to three short sentences: outcome, durable PR/commit/CI reference and material limits. Follow the [content boundary](../../README.md#repository-record-content) for detail and provenance; keep unexecuted manual/accessibility checks explicit. Task and criterion rows retain compact state and link the evidence. Do not invent dates or outcomes.

At task closure, link the closing PR or CI result, set the evidence verdict and closure date, copy the verdict to its task row and update only the criteria fully verified. Apply the gates from the plan before declaring completion.

## Reconcile and hand off

Preserve existing numbered record names and historical evidence URLs. New decisions use dated names and the header conventions in `agent-paper-trail/decisions/README.md`; precedence requires explicit supersession and replacement backlinks. Update indexes and every mapped reviewer binding in the same change.

Before PR handoff, apply a simplification pass followed by a correctness/evidence pass. Personal `tighten` and `probe` skills may support these passes; when unavailable, check directly for duplicated records, unsupported verdicts, requirement conflicts, missing affected checks and broken continuation links.

Verify the diff's meaningful behaviour changes have a task row and evidence, affected criterion rows are current, and reviewers can identify pending gates. Report unresolved record gaps as review work. Never backfill an acceptance verdict from the existence of code or a green test report alone. Keep private journals, raw chats, secrets and machine-specific paths outside the repository.
