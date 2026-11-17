# Feature branches and pull requests

## Workflow supersession

[Portable contributor workflow](2026-11-16-portable-contributor-workflow.md) supersedes this record’s per-unit approval/manual-review pauses and blanket maintainer commit/push gates only. Technical scope, required validation, branch/PR boundaries and maintainer merge/release authority remain binding. Earlier approval references describe the original adoption, not a prerequisite for new contributors.

Status: Accepted

Date: 2026-10-03

## Context

`main` is the default branch. Task implementation uses feature branches and pull requests.

## Decision

- Use a separate feature branch from current `main` for each subsequent task. A descriptive name such as `feature/t01-application-shell` makes the task discoverable.
- Submit task changes through a pull request targeting `main`; do not push task implementation directly to `main`.
- Keep the atomic coding and manual-review gates within each task. Approval of a task or its implementation does not automatically authorise commit, push or merge.
- Verify required dependency changes are present on `main` before starting the next task. Distinguish implementation/manual acceptance from publication and merge state.

## Rationale and consequences

Feature branches and PRs keep task changes independently reviewable and preserve a stable default branch.

The [CI and merge decision](2026-10-17-ci-and-merge-checks.md) owns required protections.

## Alternatives considered

- Continue all work directly on `main`: rejected because task changes need independent review.
- Keep all tasks on one long-lived feature branch: not selected; per-task branches make individual task review and dependency state clearer.

## Related documents

- [Agent instructions](../../AGENTS.md)
- [Task plan](../specs/001-mvp/plan.md)
- [Task starter](../prompts/task-starter.md)
