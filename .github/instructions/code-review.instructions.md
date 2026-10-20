---
applyTo: "**"
excludeAgent: "cloud-agent"
---

# PanePeek pull request review

Use the [code-review skill](../skills/code-review/SKILL.md) for investigation and finding verification. The [repository-wide binding](../copilot-instructions.md) restates project standards and owns the binding map/sync rule; this file owns review scope and comment style.

## Repository context

Read `AGENTS.md` and `agent-paper-trail/README.md` before reviewing. PanePeek is a native, local-only file browser for macOS 26+.

Use `agent-paper-trail/specs/001-mvp/` for `spec.md`, `plan.md`, `tasks.md` and `validation.md`. Open only the task's `evidence/<task-slug>.md`; evidence retains current outcomes, provenance and material limits. Use `agent-paper-trail/decisions/README.md` for accepted choices, `agent-paper-trail/notes/README.md` for gotchas and `agent-paper-trail/design/001-mvp/README.md` for UI/icon changes.

Accepted requirements and decisions bind implementation; proposed details remain subject to review. Review the PR within its task scope. Deferred MVP features are not defects in an earlier slice. Flag unsupported completion claims or changes that conflict with accepted requirements. Use `README.md` for build/run expectations; distinguish executed checks from pending manual acceptance.

## Findings

Report actionable problems introduced or worsened by this PR, supported by the diff and relevant surrounding code. Prioritise correctness, data loss, security, requirement conflicts and meaningful missing regression coverage. Report maintainability issues when they create a concrete risk or contradict an established repository rule.

Inspect callers, existing guards and tests before asserting a defect. Explain the triggering condition and practical consequence. Omit speculative issues, personal style preferences and requests to implement future tasks. Consolidate findings with the same root cause. Recheck earlier comments before repeating them.

## PR comments

Use a staff-plus, neutral, lean tone. Put one finding on the smallest relevant changed line range, in a short paragraph. State what fails, when it fails and why it matters. Include a specific correction when the evidence supports one; use a suggestion block only for a small, complete fix.

Keep comments to improvement points and substance. Omit praise, confirmation, warm-up introductions, drama and wrap-up endings. Use plain language and proportionate severity. Use British spelling for prose, preserve technical names and avoid em dashes. Keep any required review overview brief; when there are no actionable findings, do not invent comments.
