# PanePeek agent instructions

Before meaningful work, read [the paper trail](agent-paper-trail/README.md) and [shared engineering and review rules](agent-paper-trail/engineering-and-review.md). Use the [continuation index](agent-paper-trail/INDEX.md) to find the relevant spec, plan, decisions, task state and validation.

Use the repository's [panepeek-paper-trail skill](agent-paper-trail/skills/panepeek-paper-trail/SKILL.md) for task implementation, record reconciliation and PR handoff. If local skill discovery is unavailable, read that file directly.

## Project context

PanePeek is a native macOS 26+ file browser with local file processing. The [GitHub update decision](agent-paper-trail/decisions/2026-10-24-github-release-updates.md) permits only release checks and requested downloads as an app-operated network feature; Store builds exclude the updater.

Use [001 MVP](agent-paper-trail/specs/001-mvp/README.md) for the native product and accessibility baseline and its tracked follow-ups. Accepted decisions bind implementation.

The paper trail owns durable project context. When a change conflicts with an accepted decision or requirement, present the evidence and update the relevant document through review before implementing a different direction.

## Working rules

- Apply the [validation checklist](agent-paper-trail/validation/checklist.md) to each unit.
- Plan [performance checks](agent-paper-trail/engineering-and-review.md#performance-checks-for-feature-development) for new native app features before coding. Use the [native accessibility baseline](agent-paper-trail/specs/001-mvp/spec.md#accessibility-baseline) for native UI.
- Use lowercase directory names, with explicit Swift package target paths. Preserve directory names required by the platform, including `Contents`, `MacOS` and `Resources` in app bundles.
- Record durable decisions and gotchas here. Private journals, raw chats, credentials and machine-specific paths stay outside the repository.
- For UI/icon work, read the [design sources](agent-paper-trail/design/001-mvp/README.md). Reuse the SVG logo geometry and editable UI draft instead of regenerating from screenshots; check their review status before production use.

## Source control and tooling

Repository: [bcinarli/pane-peek](https://github.com/bcinarli/pane-peek). The default branch is `main`. Task implementation uses feature branches and pull requests targeting `main`; follow the [source-control decision](agent-paper-trail/decisions/0002-feature-branches-and-prs.md). Commit, push and merge retain separate approval gates.

Use the [contributor instructions](CONTRIBUTING.md#build-and-run). Verify the toolchain and record executed checks and remaining limits.
