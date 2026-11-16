# PanePeek specifications

| Workstream | Status | Entry point |
| --- | --- | --- |
| 001 MVP / native baseline | Completed for MVP delivery; native baseline retained | [Spec package](001-mvp/README.md) and [closure review](../notes/2026-11-08-mvp-closure.md) |
| CLI and native path opening | Contract accepted. Criterion coverage and publication pending. | [Spec package](2026-11-08-cli-support/README.md) |
| Website | Active | [Spec package](2026-10-17-website/README.md) |
| GitHub release updates | Active | [Spec package](2026-10-24-github-release-updates/README.md) |
| Git and agent worktrees | Active | [Spec package](2026-10-27-git-worktrees/README.md) |
| GitHub prerelease preparation | Accepted; candidate acceptance tracked separately | [Spec package](2026-11-02-github-prereleases/README.md) |
| External change refresh | Proposed | [Spec package](2026-11-11-external-change-refresh/README.md) |
| Highlighting coverage | Proposed | [Spec package](2026-11-11-highlighting-coverage/README.md) |
| Test and CI reliability | Completed | [Maintenance package](2026-11-11-test-ci-reliability/README.md) |

Specs own current capability requirements and reviewed scope. Apply the [content boundary](../README.md#content-boundary) before creating a package or row. Reuse a governing capability rather than creating a folder for each delivery.

For new capabilities, use `YYYY-MM-DD-capability-slug/` and copy only needed starters:

- [spec.md](_template/spec.md): observable requirements, stable IDs and constraints, linking the separate acceptance home.
- [validation.md](_template/validation.md): criteria, verdicts, remaining coverage and scoped waivers, each maintained once.
- An optional `design-approach.md` when lasting responsibilities, interfaces or compatibility need explanation beyond the spec and code.

New packages have no default `tasks.md` or implementation plan. The GitHub issue owns delivery plans, progress and handoffs; its PR owns detailed verification. Existing `plan.md`, `tasks.md`, package README specifications and acceptance records retain their names and valid ownership until reviewed migration assigns their content.

Use `001-mvp` for the native product/accessibility baseline and its existing follow-ups. Its delivery completion does not retire these contracts. Preserve IDs, verdicts and evidence links; release waivers cover only their named scope and candidates.

Apply [Specs and changes](../README.md#specs-and-changes) for readiness, undelivered intent and lifecycle, and [Acceptance and limitations](../README.md#acceptance-and-limitations) when criteria change. New specs follow the starter's status and supersession fields; existing records need no header conversion. Decisions follow the adopted [decision log](../decisions/README.md).

Apply the [shared engineering and review rules](../engineering-and-review.md) to delivery. Read only the relevant scope and open outcome summaries only when provenance or limits matter.
