# Git and agent worktrees tasks

Scope: Accepted, 2026-10-27. Implementation has not started. The [plan](plan.md) owns dependencies and unit boundaries; [validation](validation.md) owns G1–G8 verdicts. Ready means specified work, not satisfied dependencies or accepted delivery. Follow [agreed scope/checkpoints and shared review requirements](../../engineering-and-review.md#task-review); no default per-unit approval is required. Manual validation and acceptance of delivered scope remain separate from publication.

The worktree-browsing unit includes the broader [discovery contract](spec.md#worktree-discovery-and-navigation): repository registrations, known locations including Windsurf/Hermes, and custom locations. Antigravity uses repository/custom discovery; unknown harness attribution does not restrict a verified checkout.

| Task | Status | Verdict | Next gate | Manual review | Publication | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| [git-access-feasibility](plan.md#git-access-feasibility) | Ready | Pending | Agreed implementation scope; required feasibility checks | Pending | Not published | Not started |
| [worktree-browsing](plan.md#worktree-browsing) | Ready | Pending | Unit 1 outcome, required dependency publication | Pending | Not published | Not started |
| [pane-git-information](plan.md#pane-git-information) | Ready | Pending | Dependencies accepted/published | Pending | Not published | Not started |
| [unified-diff](plan.md#unified-diff) | Ready | Pending | Dependencies accepted/published | Pending | Not published | Not started |
| [worktree-review-facts](plan.md#worktree-review-facts) | Ready | Pending | Dependencies accepted/published | Pending | Not published | Not started |

Keep an implemented unit Active/Pending until its manual review is accepted. Optional Git availability is a required product behaviour, not a waiver of failed or missing implementation checks.
