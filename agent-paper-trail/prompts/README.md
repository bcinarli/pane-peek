# PanePeek workflow guidance

Status: Active

Use [the task starter](task-starter.md) to start or continue one planned MVP task. Fill in the task ID; it reads the maintained spec and plan rather than copying their contents.

Use the registered skills below for milestone quality work.

| Skill | Role |
| --- | --- |
| `code-quality-analysis` | Analyse a bounded code area for maintainability and test quality; produce evidence-backed findings without applying fixes. |
| `cluster-work` | Turn reviewed findings into coherent remediation clusters, then plan or implement a selected cluster through approved coding units. |

Read the actual skill definitions before use. Review analysis findings before cluster planning; planning approval does not authorise every coding unit. If a future environment lacks a required skill, report the gap and ask for direction rather than silently substituting workflows.

Tighten followed by probe remains the default after each code unit or other meaningful output, including analysis reports and cluster plans. Milestone analysis is a separate workflow.

Add project-specific starting/review prompts only when they are reusable without private chat context. Their references should point to the maintained paper trail.

## Copilot pull request reviews

[Copilot review instructions](../../.github/instructions/code-review.instructions.md) apply to every file and guide reviews against the paper trail, with lean, evidence-led inline findings. The [default-branch ruleset](https://github.com/bcinarli/pane-peek/rules/24469433) requests reviews for eligible PRs, including drafts and new pushes. Keep custom instructions enabled in repository Settings → Copilot → Code review. Existing feature branches need the instruction file before relying on it for reviews.

The [repository-wide binding](../../.github/copilot-instructions.md) restates current standards and maps their sources. Update mapped bindings in the same PR when a source changes. [CODEOWNERS](../../.github/CODEOWNERS) declares Bilal's ownership of review instructions; Bilal reviews those changes before merge. GitHub enforcement settings retain separate approval under the source-control decision.
