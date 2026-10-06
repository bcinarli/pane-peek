# PanePeek validation checklist

Status: T01 and T02 are accepted and merged. [T03 evidence](t03-sorting-hidden-visibility.md) records both units and their revisions accepted by Bilal on 2026-10-06. All 20 tests and build/native checks pass. Unit 1 is committed locally; Unit 2 is uncommitted. Later units and source-control steps require separate approval. Unreported manual checks remain distinct from acceptance and agent evidence; criteria spanning later tasks stay partial.

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

- [x] T01/T02: two directory panes beside Details, native light/dark surfaces, thin focus cue with empty selection, compact Home/root breadcrumbs and aligned long-path headers.
- [ ] T03/T14: shared actions target the focused pane; hidden/sort settings remain independent; selected/directory paths copy exactly and long paths remain accessible.
- [ ] T15/T07/T16: favourite stars reflect shared state; bookmarking retains selection/buffer; favourite navigation follows dirty guards and changes only its target pane.
- [ ] T06/T07: every A15 language highlights in Preview and Edit, including HTML/XML, CSS/SCSS and JSX/TSX. Typing and mode changes retain buffer, caret/selection and undo.
- [ ] T08–T13/T16: context menus retain clicked-item/selection targeting and dirty guards; transfers use context actions and drag/drop without selection-triggered buttons.
- [ ] T18: essential controls/context actions are keyboard accessible, focus/selection are understandable with assistive access, and production icon assets preserve the accepted shape at small Dock/Finder sizes.

## Acceptance evidence

Use `Pending`, `Partially validated` or `Passed`. Criteria that span tasks stay partial until their entire behaviour is validated. An accepted deviation needs its rationale and review reference.

| Criterion | Status | Automated evidence | Manual evidence |
| --- | --- | --- | --- |
| A1 | Passed | [T02](t02-directory-browsing.md): pane independence, focused/captured navigation targets and exact ancestor paths. [T03 Unit 2](t03-sorting-hidden-visibility.md#unit-2-hidden-visibility-and-refresh) adds visibility/navigation independence regressions. | Bilal accepted T02 navigation/focus and T03 Unit 2. T03 agent checks confirm independent visibility, focused shared actions and empty-pane targeting. |
| A2 | Partially validated | [T02 Unit 1](t02-directory-browsing.md) and [T03 evidence](t03-sorting-hidden-visibility.md): natural default order, both sort fields/directions, real modified values, relative-date boundaries/local calendar days and package/link distinction. | Bilal accepted both T03 units, including the sorting orders and now correction, on 2026-10-06. Agent reproduced the stale timeline-clock failure, then checked immediate Just now and later 1 min ago without Refresh, retaining both selections. Individual light/resize/wake outcomes remain unreported. |
| A3 | Passed | [T02 Unit 1](t02-directory-browsing.md): invalid/deleted/regular-file retention and stale success/error completions. [T03 Unit 2](t03-sorting-hidden-visibility.md#unit-2-hidden-visibility-and-refresh): failed/pending Refresh retention and recovery using the same request guard. | Bilal accepted T02 navigation/error behaviour and T03 Unit 2. Agent checked native Refresh error retention and recovery. Real slow-volume testing remains unclaimed. |
| A4 | Partially validated | [T03 Unit 2](t03-sorting-hidden-visibility.md#unit-2-hidden-visibility-and-refresh): real dot/metadata-hidden fixtures, independent visibility, manual reread and retained settings. Transfer-triggered refresh remains later tasks. | Bilal confirmed hidden/Refresh menus and shortcuts, visible-selection retention and clearing a selected hidden row, then accepted Unit 2 on 2026-10-06. Agent checked empty-pane focus and global-date ordering through visibility/Refresh. |
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
| A29 | Partially validated | [T02](t02-directory-browsing.md#unit-2-breadcrumbs): root/exact ancestors, canonical link ancestry and navigation regressions. | Bilal accepted canonical navigation/typography, Home/root/ancestor clicks, readable scrolling, keyboard activation, appearance and resizing. T15 stars and T07 dirty guards remain pending. |
| A30 | Partially validated | [T03 evidence](t03-sorting-hidden-visibility.md): independent settings, header defaults/reversal, folders-first Name, global Modified dates, cross-kind natural-name ties and unknown dates globally last in either date direction. Current settings apply after pending reads. | Bilal confirmed global Modified sorting in both directions and folders-first Name, then accepted Unit 2 and the now correction on 2026-10-06. Agent checked both selections and hidden/Refresh independence in the rebuilt app. Cross-window checks remain T16. |
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
