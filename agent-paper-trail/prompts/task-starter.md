# PanePeek task starter

Status: Active

Choose the GitHub issue or existing legacy task and relevant workstream. State which operations are requested; omit unavailable optional inputs rather than inventing them.

```text
Work on PanePeek <ISSUE_OR_EXISTING_TASK> in <WORKSTREAM_PATH>.
Requested operations: <explore, spec, plan, implement, review, handoff, reconcile>.

Read AGENTS.md and agent-paper-trail/README.md. Use the repository-local panepeek-paper-trail workflow; if discovery is unavailable, read agent-paper-trail/skills/panepeek-paper-trail/SKILL.md directly.

Read shared engineering/review rules and only the relevant requirements, decisions, acceptance rows and legacy scope. Inspect the current branch, linked issue/PR and dependencies. Follow the spec-first setting and its exceptions. Reuse existing authority; a plan or Ready status does not approve a coding unit.

For implementation, present the first unit, expected files, criteria, dependencies, checks and manual review steps. Identify required performance baselines before coding. If unit approval is missing, state the exact gate and end with “Waiting for your approval before proceeding”. Once approved, implement only that unit, validate, tighten then probe, and present the affected surface for manual acceptance before the next unit.

Keep new delivery plans and handoffs in the GitHub issue, with the PR linking to it. Keep review findings and detailed verification in the PR. Without shared access or write authority, prepare a conversation draft naming its destination. Apply the content boundary before reconciling eligible durable facts and affected acceptance. No per-unit paper-trail record is required. Commit, push, merge and distribution retain separate approval.
```
