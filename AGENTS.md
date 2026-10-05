# PanePeek agent instructions

Before meaningful project work, read [the paper trail](agent-paper-trail/README.md), then the relevant spec, plan, decisions, task state and validation expectations.

## Project context

PanePeek is a native, local-only file browser for macOS 26+. The active planning package is [001 MVP](agent-paper-trail/specs/001-mvp/README.md). Its reviewed decisions bind implementation; proposed details remain subject to review.

The paper trail owns durable project context. When a change conflicts with an accepted decision or requirement, present the evidence and update the relevant document through review before implementing a different direction.

## Working rules

- Follow the engineering and review rules in the [MVP spec](agent-paper-trail/specs/001-mvp/spec.md#engineering-and-task-review-rules) and the [task workflow](agent-paper-trail/specs/001-mvp/plan.md#task-workflow-and-exit-gates).
- Obtain approval before each atomic coding unit; present its test evidence and running app for manual review before the next unit. Commit and push require separate approval.
- Use red/green TDD for meaningful automated behaviours. Keep tests high-value, reuse existing behaviour, keep complexity low and comments short.
- Apply tighten followed by probe after every code unit or other work with meaningful output.
- At milestones, consider `code-quality-analysis`; use `cluster-workflow` only when reviewed findings warrant remediation. See [workflow guidance](agent-paper-trail/prompts/README.md); read the skill definitions before use.
- Keep task state and validation evidence factual. Pending manual review is not completion.
- Keep spec/task identifiers in the paper trail, not shipped source comments. Comments should explain durable intent.
- Use lowercase directory names, with explicit Swift package target paths. Preserve directory names required by the platform, including `Contents`, `MacOS` and `Resources` in app bundles.
- Record durable decisions and gotchas here. Private journals, raw chats, credentials and machine-specific paths stay outside the repository.
- For UI/icon work, read the [design sources](agent-paper-trail/design/001-mvp/README.md). Reuse the SVG logo geometry and editable UI draft instead of regenerating from screenshots; check their review status before production use.

## Source control and tooling

Repository: [bcinarli/pane-peek](https://github.com/bcinarli/pane-peek). The default branch is `main`. Task implementation uses feature branches and pull requests targeting `main`; follow the [source-control decision](agent-paper-trail/decisions/0002-feature-branches-and-prs.md). Commit, push and merge retain separate approval gates.

The Swift package shell and local bundling script are implemented. Follow the [build/run instructions](README.md#build-and-run), verify the available toolchain and record executed checks in validation evidence. Do not report unexecuted checks as passing.
