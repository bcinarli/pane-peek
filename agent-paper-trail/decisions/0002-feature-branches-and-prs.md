# Feature branches and pull requests

Status: Accepted

Date: 2026-10-03

## Context

Bilal requested `main` as the default branch and feature-branch work for planned tasks, followed by a pull request before merging into `main`. The repository initially has no commits or remote branches.

## Decision

- Establish the initial reviewed paper-trail baseline directly on `main` with Bilal’s explicit commit/push authorisation.
- Use a separate feature branch from current `main` for each subsequent task. A descriptive name such as `feature/t01-application-shell` makes the task discoverable.
- Submit task changes through a pull request targeting `main`; do not push task implementation directly to `main`.
- Keep the atomic coding and manual-review gates within each task. Approval of a task or its implementation does not automatically authorise commit, push or merge.
- Verify required dependency changes are present on `main` before starting the next task. Distinguish implementation/manual acceptance from publication and merge state.

## Rationale and consequences

The initial commit establishes the branch on which future work depends. Feature branches and PRs keep task changes independently reviewable and preserve a stable default branch.

Branch protection and merge strategy are not configured by this decision. They can be selected separately if needed.

## Alternatives considered

- Continue all work directly on `main`: rejected in favour of Bilal’s feature-branch/PR workflow.
- Keep all tasks on one long-lived feature branch: not selected; per-task branches make individual task review and dependency state clearer.

## Related documents

- [Agent instructions](../../AGENTS.md)
- [Task plan](../specs/001-mvp/plan.md)
- [Task starter](../prompts/task-starter.md)
