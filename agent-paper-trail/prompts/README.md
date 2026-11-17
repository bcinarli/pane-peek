# PanePeek workflow guidance

Status: Active

Use [the task starter](task-starter.md) to start or continue work from its GitHub issue or an existing legacy task. Select governing sources through the [continuation index](../INDEX.md). The [project settings](../README.md#project-settings) own delivery and review homes; existing native baseline and follow-up records retain their stable paths.

The [panepeek-paper-trail skill](../skills/panepeek-paper-trail/SKILL.md) provides the repository workflow without a personal installation. Its visible source is shared through relative directory symlinks at `.agents/skills/panepeek-paper-trail` for Codex and `.claude/skills/panepeek-paper-trail` for Claude Code. `CLAUDE.md` imports `AGENTS.md`; other agents can follow its direct skill link. Invoke it as `$panepeek-paper-trail` in Codex or `/panepeek-paper-trail` in Claude Code. If discovery is disabled or a checkout does not preserve symlinks, read the visible source directly.

Use the [shared self-review checks](../engineering-and-review.md#self-review) before presenting meaningful work: simplify first, then inspect realistic failure modes and evidence gaps. No personal skills are required.

At milestones, consider bounded maintainability and test-quality analysis. Review source-backed findings before planning remediation; group accepted findings by cause, dependency or validation boundary and agree additional scope/checkpoints. Contributors choose their tools and may perform these checks directly.

Add project-specific starting/review prompts only when they are reusable without private chat context. Their references should point to the maintained paper trail.

## Copilot pull request reviews

[Copilot review instructions](../../.github/instructions/code-review.instructions.md) apply to every file and guide reviews against the paper trail, with lean, evidence-led inline findings. The [default-branch ruleset](https://github.com/bcinarli/pane-peek/rules/24469433) requests reviews for eligible PRs, including drafts and new pushes. Keep custom instructions enabled in repository Settings → Copilot → Code review. Existing feature branches need the instruction file before relying on it for reviews.

The [repository-wide binding](../../.github/copilot-instructions.md) restates current standards and maps their sources. Update mapped bindings in the same PR when a source changes. [CODEOWNERS](../../.github/CODEOWNERS) identifies the required code owner for review-instruction changes before merge. GitHub enforcement settings retain separate approval under the source-control decision.
