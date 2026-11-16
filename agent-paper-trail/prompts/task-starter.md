# PanePeek task starter

Status: Active

Choose the GitHub issue or existing legacy task and relevant workstream. State which operations are requested; omit unavailable optional inputs rather than inventing them.

```text
Work on PanePeek <ISSUE_OR_EXISTING_TASK> in <WORKSTREAM_PATH>.
Requested operations: <explore, spec, plan, implement, review, handoff, reconcile>.

Read AGENTS.md and agent-paper-trail/README.md. Use the repository-local panepeek-paper-trail workflow; if discovery is unavailable, read agent-paper-trail/skills/panepeek-paper-trail/SKILL.md directly.

Read shared engineering/review rules and only the relevant requirements, decisions, acceptance rows and legacy scope. Inspect the current branch, linked issue/PR and dependencies. Follow the spec-first setting and its exceptions. Reuse existing authority; a Ready status alone does not establish scope agreement or satisfied dependencies.

For implementation, agree scope and any intermediate review checkpoints. Identify reviewable changes, criteria, dependencies, checks and required performance baselines before coding. Continue within agreed scope between checkpoints; pause when scope changes or a prerequisite blocks dependent work. Before presenting results, simplify unnecessary complexity, then check realistic failure modes and evidence gaps. Perform these checks directly or with available tools; no personal skills are required. Present the affected surface and validation at agreed checkpoints and for final acceptance.

Keep new delivery plans and handoffs in the GitHub issue, with the PR linking to it. Keep review findings and detailed verification in the PR. Without shared access or write authority, prepare a conversation draft naming its destination. Apply the content boundary before reconciling eligible durable facts and affected acceptance. No per-unit paper-trail record is required. Contributors may commit/push their own branches within agreed scope and permissions. Maintainer/code-owner review gates merge; explicit maintainer authority gates releases/distribution. Agent-user instructions and tool permissions remain applicable.
```
