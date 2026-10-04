---
applyTo: "**"
excludeAgent: "cloud-agent"
---

# PanePeek pull request review

## Repository context

Read `AGENTS.md` and `agent-paper-trail/README.md` before reviewing. PanePeek is a native, local-only file browser for macOS 26+.

Use `agent-paper-trail/specs/001-mvp/spec.md` for requirements and `agent-paper-trail/decisions/README.md` to find relevant accepted decisions. Read the relevant scope in `plan.md`, execution state in `tasks.md`, and evidence under `agent-paper-trail/validation/`. These two Markdown files are in `agent-paper-trail/specs/001-mvp/`. Consult `agent-paper-trail/notes/README.md` for known limitations and `agent-paper-trail/design/001-mvp/README.md` for UI/icon changes.

Accepted requirements and decisions bind implementation; proposed details remain subject to review. Review the PR within its task scope. Deferred MVP features are not defects in an earlier slice. Flag unsupported completion claims or changes that conflict with accepted requirements. Use `README.md` for build/run expectations; distinguish executed checks from pending manual acceptance.

## Findings

Report actionable problems introduced or worsened by this PR, supported by the diff and relevant surrounding code. Prioritise correctness, data loss, security, requirement conflicts and meaningful missing regression coverage. Report maintainability issues when they create a concrete risk or contradict an established repository rule.

Inspect callers, existing guards and tests before asserting a defect. Explain the triggering condition and practical consequence. Omit speculative issues, personal style preferences and requests to implement future tasks. Consolidate findings with the same root cause. Recheck earlier comments before repeating them.

## PR comments

Use a staff-plus, neutral, lean tone. Put one finding on the smallest relevant changed line range, in a short paragraph. State what fails, when it fails and why it matters. Include a specific correction when the evidence supports one; use a suggestion block only for a small, complete fix.

Keep comments to improvement points and substance. Omit praise, confirmation, warm-up introductions, drama and wrap-up endings. Use plain language and proportionate severity. Use British spelling for prose, preserve technical names and avoid em dashes. Keep any required review overview brief; when there are no actionable findings, do not invent comments.
