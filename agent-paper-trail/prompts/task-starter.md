# PanePeek task starter

Status: Active

Choose `<WORKSTREAM_PATH>` from the [continuation index](../INDEX.md) and `<TASK_ID>` from its tracker. Supply a predecessor journal when needed for continuity.

```text
Start or continue PanePeek task <TASK_ID> in <WORKSTREAM_PATH>.

Complete the applicable bootstrap and continuity requirements. Read AGENTS.md and use the repository-local panepeek-paper-trail skill. If discovery is unavailable, read agent-paper-trail/skills/panepeek-paper-trail/SKILL.md directly.

Read agent-paper-trail/engineering-and-review.md, agent-paper-trail/validation/checklist.md and the selected workstream's requirements, plan, task and criterion rows. Check relevant decisions, notes and evidence for the selected task. Inspect the repository state and the code and tests needed for the proposed unit. Verify dependency publication and approval for this unit.

In your first response, give the task status, proposed coding unit, expected files, criteria, dependencies, validation and manual review steps. Name the baseline revision and planned performance measurements when required. State any unresolved decision that affects the unit. If approval is absent, stop and end with “Waiting for your approval before proceeding”.

Once approved, verify the feature branch and collect any required baseline. Implement only the approved unit. Run the checks and apply tighten followed by probe before presenting the result and evidence. Follow the shared review rules and paper-trail skill to record current outcomes and limits. Stop for manual acceptance before the next unit. Commit, push, merge and distribution each require separate approval.
```
