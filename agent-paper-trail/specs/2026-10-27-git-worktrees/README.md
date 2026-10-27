# Git and agent worktrees

Optional local Git inspection adds agent-worktree browsing, per-pane branch information and file status, and a read-only unified diff in Details. Git features use Apple-provided tools when available; ordinary browsing and configured-location navigation remain usable without them.

| Record | Purpose |
| --- | --- |
| [Spec](spec.md) | Accepted behaviour, dependency policy and scope limits. |
| [Plan](plan.md) | Implementation units, dependencies and native verification gates. |
| [Tasks](tasks.md) | Coding readiness, manual review and publication state. |
| [Validation](validation.md) | Acceptance criteria and remaining checks. |

The [native baseline](../001-mvp/spec.md) remains binding for folder access, browser/editor state and accessibility. The [network and distribution decision](../../decisions/2026-10-24-github-release-updates.md) remains unchanged. Git inspection introduces no network operations or additional sandbox capabilities.
