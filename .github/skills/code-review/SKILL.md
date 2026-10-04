---
name: code-review
description: Investigate GitHub pull requests using code-first evidence, risk-based depth and verified findings. Use for automatic or requested PR code reviews.
---

# Code review

Follow the [repository review instructions](../../instructions/code-review.instructions.md) for project authority, task scope and comment style. This skill supplies the investigation method.

## Investigate the change

Establish the current PR head, base revision and changed files. Read existing review discussion, relevant tests and check results. Use the diff and current code as primary evidence; PR descriptions and discussion provide secondary context.

Start with the changed behaviour. Extend investigation when the change affects filesystem mutations, persistence, concurrency, error recovery, security boundaries or public contracts. Increase depth for changes across modules or removal of meaningful tests. A task's use of the project plan or agent guidance alone does not require a broader review.

For risky changes, trace the affected call path from its entrypoint and validation through the relevant helpers to the filesystem, persisted state or other runtime boundary. Check responsibility placement and whether a simpler existing path would achieve the same behaviour.

Review tests against realistic triggering conditions and failure paths. Use observed check results where available; distinguish code analysis from runtime validation and state material unknowns.

## Verify each finding

Establish how the diff causes or worsens the reported behaviour. Inspect callers and guards before asserting a defect; compare with the base revision when provenance is unclear. Omit a finding whose causal claim cannot be supported.

Check existing feedback against the current head, including fixes made since earlier reviews. Add a comment on an already reported issue only when new evidence materially changes the finding. Group consequences with the same root cause.

Match severity to the failure condition and practical impact. Distinguish a merge blocker from a non-blocking improvement. Apply the linked comment rules to verified findings without filling empty categories or adding a separate report template.

## Review permissions

Configured automatic Copilot reviews may publish findings for the current PR. A manual read-only review does not authorise posting. Code edits, commits, pushes, approvals, requests for changes, merges and repository configuration changes require separate authorisation.
