---
applyTo: "**"
excludeAgent: "cloud-agent"
---

# PanePeek pull request review

Use the [code-review skill](../skills/code-review/SKILL.md) for investigation and finding verification. The [repository-wide binding](../copilot-instructions.md) restates project standards and owns the binding map/sync rule; this file owns review scope and comment style.

## Repository context

Read `AGENTS.md`, `agent-paper-trail/README.md` and the [shared engineering and review rules](../../agent-paper-trail/engineering-and-review.md) before reviewing. PanePeek is a native macOS 26+ file browser with local file processing; [the update spec](../../agent-paper-trail/specs/2026-10-24-github-release-updates/spec.md) defines the GitHub-only update network exception.

Find the owning workstream in the [continuation index](../../agent-paper-trail/INDEX.md). Read its spec and plan or the package README where it owns those, then the relevant task and validation rows. Use `agent-paper-trail/specs/001-mvp/` for affected native baseline requirements. Open only the task's `evidence/<task-slug>.md`; evidence retains current outcomes, provenance and material limits. Use `agent-paper-trail/decisions/README.md` for accepted choices, `agent-paper-trail/notes/README.md` for gotchas and `agent-paper-trail/design/001-mvp/README.md` for UI/icon changes.

Review the changed scope against accepted requirements and decisions. Flag unsupported completion claims. Use `CONTRIBUTING.md` for build and run expectations and verify which checks and manual acceptance steps are still pending.

## Findings

Report actionable problems introduced or worsened by this PR, supported by the diff and relevant surrounding code. Prioritise correctness, data loss, security, requirement conflicts and meaningful missing regression coverage. Report maintainability issues when they create a concrete risk or contradict an established repository rule.

Inspect callers, existing guards and tests before asserting a defect. Explain the triggering condition and practical consequence. Omit speculative issues, personal style preferences and requests to implement future tasks. Consolidate findings with the same root cause. Recheck earlier comments before repeating them.

## PR comments

Use a staff-plus, neutral, lean tone. Put one finding on the smallest relevant changed line range, in a short paragraph. State what fails, when it fails and why it matters. Include a specific correction when the evidence supports one; use a suggestion block only for a small, complete fix.

Keep comments to improvement points and substance. Omit praise, confirmation, warm-up introductions, drama and wrap-up endings. Use plain language and proportionate severity. Use British spelling for prose, preserve technical names and avoid em dashes. Keep any required review overview brief; when there are no actionable findings, do not invent comments.
