# PanePeek validation checklist

Status: Bilal accepted the current T01 state on 2026-10-04. Build/package/native checks, development icon and unverified per-check outcomes are recorded in [T01 evidence](t01-launchable-shell.md). Later task evidence remains pending; A31 stays partially validated.

The [spec](../specs/001-mvp/spec.md) owns criteria, and the [plan](../specs/001-mvp/plan.md#acceptance-traceability) maps them to tasks. This file owns acceptance evidence; [tasks.md](../specs/001-mvp/tasks.md) owns task status.

[Draft design review](design-review.md) records the accepted UI/logo and highlighting scope. It does not mark native acceptance criteria as passed.

## Required task gate

- [ ] Approved scope matches the maintained spec and plan.
- [ ] Meaningful automated behaviours have observed red/green evidence.
- [ ] Build and targeted tests pass.
- [ ] The app launches with the visible task result.
- [ ] Run instructions and disposable fixture/setup steps are supplied.
- [ ] Bilal has completed the task’s manual checklist and accepted the review.
- [ ] Tighten then probe has been applied.
- [ ] Durable decisions/gotchas are recorded; commit/push approval remains separate.

For each task, record the tested OS/toolchain, commands and results, manual observations, accepted deviations and review outcome. Add a linked evidence file when useful; do not mark a check as passed before it runs.

## Native design checks

Apply these with the relevant tasks and repeat the complete workflow at T18:

- [ ] T01/T02: two directory panes beside Details, native light/dark surfaces, thin focus cue with empty selection, compact Home/root breadcrumbs and aligned long-path headers.
- [ ] T03/T14: shared actions target the focused pane; hidden/sort settings remain independent; selected/directory paths copy exactly and long paths remain accessible.
- [ ] T15/T07/T16: favourite stars reflect shared state; bookmarking retains selection/buffer; favourite navigation follows dirty guards and changes only its target pane.
- [ ] T06/T07: every A15 language highlights in Preview and Edit, including HTML/XML, CSS/SCSS and JSX/TSX. Typing and mode changes retain buffer, caret/selection and undo.
- [ ] T08–T13/T16: context menus retain clicked-item/selection targeting and dirty guards; transfers use context actions and drag/drop without selection-triggered buttons.
- [ ] T18: essential controls/context actions are keyboard accessible, focus/selection are understandable with assistive access, and production icon assets preserve the accepted shape at small Dock/Finder sizes.

## Acceptance evidence

Use `Pending`, `Partially validated` or `Passed`. Criteria that span tasks stay partial until their entire behaviour is validated. An accepted deviation needs its rationale and review reference.

| Criterion | Status | Automated evidence | Manual evidence |
| --- | --- | --- | --- |
| A1 | Pending | None yet. | None yet. |
| A2 | Pending | None yet. | None yet. |
| A3 | Pending | None yet. | None yet. |
| A4 | Pending | None yet. | None yet. |
| A5 | Pending | None yet. | None yet. |
| A6 | Pending | None yet. | None yet. |
| A7 | Pending | None yet. | None yet. |
| A8 | Pending | None yet. | None yet. |
| A9 | Pending | None yet. | None yet. |
| A10 | Pending | None yet. | None yet. |
| A11 | Pending | None yet. | None yet. |
| A12 | Pending | None yet. | None yet. |
| A13 | Pending | None yet. | None yet. |
| A14 | Pending | None yet. | None yet. |
| A15 | Pending | None yet. | None yet. |
| A16 | Pending | None yet. | None yet. |
| A17 | Pending | None yet. | None yet. |
| A18 | Pending | None yet. | None yet. |
| A19 | Pending | None yet. | None yet. |
| A20 | Pending | None yet. | None yet. |
| A21 | Pending | None yet. | None yet. |
| A22 | Pending | None yet. | None yet. |
| A23 | Pending | None yet. | None yet. |
| A24 | Pending | None yet. | None yet. |
| A25 | Pending | None yet. | None yet. |
| A26 | Pending | None yet. | None yet. |
| A27 | Pending | None yet. | None yet. |
| A28 | Pending | None yet. | None yet. |
| A29 | Pending | None yet. | None yet. |
| A30 | Pending | None yet. | None yet. |
| A31 | Partially validated | Static layout uses build/manual checks. | [T01 sidebar layout](t01-launchable-shell.md); selection/content/metadata behaviour pending. |
| A32 | Pending | None yet. | None yet. |
| A33 | Pending | None yet. | None yet. |

## Milestone quality checkpoint

- [ ] Consider analysis with the actual `code-quality-analysis` skill.
- [ ] Review findings before remediation planning.
- [ ] If needed, use the actual `cluster-workflow` skill and obtain approval for bounded clusters.
- [ ] Resolve correctness blockers; explicitly defer optional work.

See [workflow guidance](../prompts/README.md). Skill availability does not imply completion of analysis or remediation; neither has been performed yet.

## MVP completion

- [ ] A1–A33 have passing evidence or explicitly accepted deviations.
- [ ] A clean checkout builds, tests, packages and launches using documented instructions.
- [ ] Setup/run and architecture documentation match the implementation.
- [ ] Known filesystem, save and Finder limits are stated accurately.
