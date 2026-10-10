# PanePeek validation checklist

The [spec](../specs/001-mvp/spec.md) owns criteria, and the [plan](../specs/001-mvp/plan.md#acceptance-traceability) maps them to tasks. This file owns acceptance evidence; [tasks.md](../specs/001-mvp/tasks.md) owns task status.

[Draft design review](design-review.md) records the accepted UI/logo and highlighting scope. It does not mark native acceptance criteria as passed.

## Required task gate

- [ ] Approved scope matches the maintained spec and plan.
- [ ] Meaningful automated behaviours have observed red/green evidence.
- [ ] Build and targeted tests pass.
- [ ] The app launches with the visible task result.
- [ ] Affected UI meets the applicable accessibility baseline checks, with evidence recorded.
- [ ] Run instructions and disposable fixture/setup steps are supplied.
- [ ] Bilal has completed the task’s manual checklist and accepted the review.
- [ ] Tighten then probe has been applied.
- [ ] Durable decisions/gotchas are recorded; commit/push approval remains separate.

For each task, record the tested OS/toolchain, commands and results, manual observations, accepted deviations and review outcome. Add a linked evidence file when useful; do not mark a check as passed before it runs.

## Native design checks

Apply these with the relevant tasks and repeat the complete workflow at T18:

- [x] T01/T02: two directory panes beside Details, native light/dark surfaces, thin focus cue with empty selection, compact Home/root breadcrumbs and aligned long-path headers.
- [x] T03/T14: shared actions target the focused pane; hidden/sort settings remain independent; selected/directory paths copy exactly and long paths remain accessible.
- [ ] T15/T07/T16: favourite stars reflect shared state; bookmarking retains selection/buffer; favourite navigation follows dirty guards and changes only its target pane.
- [ ] T06/T07: every [accepted A15 language](../specs/001-mvp/spec.md#details-sidebar-and-preview-editor) highlights in Preview and Edit. Typing and mode changes retain buffer, caret/selection and undo.
- [ ] T08–T13/T16: context menus retain clicked-item/selection targeting and dirty guards; transfers use context actions and drag/drop without selection-triggered buttons.
- [ ] T18: essential controls/context actions are keyboard accessible, focus/selection are understandable with assistive access, and production icon assets preserve the accepted shape at small Dock/Finder sizes.

## Accessibility checks

The [spec baseline](../specs/001-mvp/spec.md#accessibility-baseline) owns the requirement. Check affected surfaces with each UI unit; T18 records every applicable A/AA criterion, including justified not-applicable outcomes. The checks below cover recurring native UI concerns. Current app-wide validation is pending.

- [ ] Text enlarges through the supported native mechanism, aiming for 200% under the WCAG2ICT interpretation. Record the mechanism, tested sizes and platform limits; confirm long paths, narrow windows and all actions remain usable (1.4.4, 1.4.10).
- [ ] Text, controls and state indicators meet applicable contrast in light/dark and active/inactive states; essential state has a non-colour cue (1.4.1, 1.4.3, 1.4.11).
- [ ] Keyboard access covers panes, breadcrumbs, toolbar, menus, Details and editor. Focus order is logical, visible and unobscured, without traps (2.1.1, 2.1.2, 2.4.3, 2.4.7, 2.4.11).
- [ ] Pointer targets and alternatives to dragging satisfy the applicable native guidance and documented exceptions (2.5.7, 2.5.8).
- [ ] VoiceOver exposes meaningful structure, control names/roles/values and selection state; errors and relevant status changes are perceivable (1.3.1, 3.3.1, 4.1.2, 4.1.3).
- [ ] Relevant macOS accessibility settings preserve usability, including increased contrast and reduced motion, following Apple guidance.

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
| A10 | Passed | [T06 Unit 1](t06-read-only-preview-highlighting.md#executed-checks): real UTF-8/BOM/newline/empty, byte limits, NUL/invalid encoding, links/special files, stale success/error, clear/cancellation and unchanged-listing Refresh. | Bilal confirmed all five manual checks and accepted Unit 1 on 2026-10-10, including text/font/copy/scroll/read-only, primary/clear, unsupported/link metadata, Refresh/recovery and affected appearance/accessibility. |
| A11 | Pending | None yet. | None yet. |
| A12 | Pending | None yet. | None yet. |
| A13 | Pending | None yet. | None yet. |
| A14 | Pending | None yet. | None yet. |
| A15 | Partially validated | [T06 Unit 2](t06-read-only-preview-highlighting.md#unit-2-swift-and-json-highlighting): Swift/JSON tokens and guarded async publication. [Unit 3](t06-read-only-preview-highlighting.md#executed-unit-3-checks): YAML/YML and TOML boundaries and safe ranges. [Unit 4](t06-read-only-preview-highlighting.md#executed-unit-4-checks): JS/TS keywords, quoted/nested template strings, comments, regex/division context, numeric boundaries, module aliases and large/incomplete input. [Unit 5](t06-read-only-preview-highlighting.md#executed-unit-5-checks): HTML/XML tag/attribute/value, comment/CDATA/declaration/raw-text boundaries and large/incomplete ranges. [Unit 6](t06-read-only-preview-highlighting.md#executed-unit-6-checks): JSX/TSX markup/expression, fragment/spread/direct-value, generic/comparison and incomplete/large range boundaries. [Unit 7](t06-read-only-preview-highlighting.md#executed-unit-7-checks): CSS/SCSS selectors/declarations/values, nested rules, comments/URLs, escapes, interpolation and safe large/incomplete ranges. [Unit 8](t06-read-only-preview-highlighting.md#executed-unit-8-checks): PHP tags/variables, strings/comments, heredoc/nowdoc/interpolation/member boundaries and safe large/incomplete ranges. [Unit 9](t06-read-only-preview-highlighting.md#executed-unit-9-checks): Go keywords, quoted/raw/rune/comment, Unicode/numeric/selector and large/incomplete range boundaries. [Unit 10](t06-read-only-preview-highlighting.md#executed-unit-10-checks): Rust string/character/lifetime, nested comment, raw identifier/numeric and large/incomplete range boundaries. [Unit 11](t06-read-only-preview-highlighting.md#executed-unit-11-checks): Java Unicode escape/source mapping, text blocks, comment/identifier/numeric boundaries and safe large/incomplete ranges. Other accepted languages and Edit remain pending. | Bilal accepted all five Unit 2 and Unit 3 manual checks on 2026-10-10. Unit 4 agent checks cover dark colours, module/plain fallback, source copy/read-only/scroll, pane/primary/clear and unchanged-size/date Refresh. Bilal approved all five Unit 4 manual checks on 2026-10-10, including affected appearance/accessibility. Unit 5 agent checks cover dark colours, plain fallback, source copy/read-only/scroll, pane/primary/clear and unchanged-size/date Refresh; Bilal accepted all five Unit 5 manual checks on 2026-10-10, including affected appearance/accessibility. Unit 6 agent checks cover dark colours, plain fallback, source copy/read-only/scroll, pane/primary/clear and unchanged-size/date Refresh; Bilal accepted all five Unit 6 manual checks on 2026-10-10, including affected appearance/accessibility. Unit 7 agent checks cover dark colours, plain/excluded fallback, source copy/read-only/scroll, pane/primary/clear and unchanged-size/date Refresh; Bilal accepted all five Unit 7 manual checks on 2026-10-10, including affected appearance/accessibility. Unit 8 agent checks cover dark colours, source copy/read-only/scroll, pane/primary/clear/plain fallback and unchanged-size/date Refresh; Bilal accepted all five Unit 8 manual checks on 2026-10-10, including affected appearance/accessibility. Unit 9 agent checks cover dark colours, source copy/read-only/scroll, pane/primary/clear/plain fallback and unchanged-size/date Refresh; Bilal accepted all five Unit 9 manual checks on 2026-10-10, including affected appearance/accessibility. Unit 10 agent checks cover dark colours, source copy/read-only/scroll, pane/primary/clear/plain fallback and unchanged-size/date Refresh; Bilal accepted all five Unit 10 manual checks on 2026-10-10, including affected appearance/accessibility. Unit 11 agent checks cover dark colours, exact source copy/read-only/scroll, pane/primary/clear/plain fallback and unchanged-size/date Refresh. Bilal accepted all five Unit 11 manual checks on 2026-10-10, including affected appearance/accessibility. |
| A16 | Partially validated | [T15 Unit 1](t15-persistent-favourites.md#executed-checks): isolated preference persistence/removal, equivalent identity, stale-entry reload and captured focused navigation/error retention. | Bilal confirmed all five T15 manual checks on 2026-10-08, accepting shared stars, focus/selection retention, both menus, canonical identity, stale retention and relaunch persistence. T07 dirty guards and T16 cross-window checks remain pending. |
| A17 | Partially validated | [T14 Unit 1](t14-context-actions-copied-paths.md#executed-checks): context targeting/pane isolation and displayed path order/plain format. | Bilal accepted context/Control-click, single/multiple path copies in both sort directions and focused directory copy with no selection on 2026-10-08. Agent checked menu-open focus/primary state and actual clipboard pastes. Later dirty guards and Rename remain pending. |
| A18 | Partially validated | [T14 Unit 1](t14-context-actions-copied-paths.md#executed-checks): originating relative base and displayed file/folder link identity. | Bilal accepted path copies including links and Unicode on 2026-10-08; agent pasted relative paths and listed links. T08–T12 operation/background handlers remain pending. |
| A19 | Partially validated | [T04 checks](t04-multiple-selection-primary-item.md#executed-checks): primary/selection state and listing/navigation reconciliation. | [T04 manual review](t04-multiple-selection-primary-item.md#bilals-manual-review-2026-10-07) accepted, including primary deselection and upward/downward range spot checks. Dirty guards remain T07 and independent windows T16. |
| A20 | Pending | None yet. | None yet. |
| A21 | Pending | None yet. | None yet. |
| A22 | Pending | None yet. | None yet. |
| A23 | Pending | None yet. | None yet. |
| A24 | Pending | None yet. | None yet. |
| A25 | Pending | None yet. | None yet. |
| A26 | Pending | None yet. | None yet. |
| A27 | Pending | None yet. | None yet. |
| A28 | Pending | None yet. | None yet. |
| A29 | Partially validated | [T02](t02-directory-browsing.md#unit-2-breadcrumbs): root/exact ancestors, canonical link ancestry and navigation regressions. [T15](t15-persistent-favourites.md#executed-checks): favourite identity follows displayed canonical directories. | Bilal accepted T02 navigation/breadcrumb review and all five T15 manual checks, including shared stars, alias identity, appearance, narrow layout and keyboard activation. T07 dirty guards remain pending. |
| A30 | Partially validated | [T03 evidence](t03-sorting-hidden-visibility.md): independent settings, header defaults/reversal, folders-first Name, global Modified dates, cross-kind natural-name ties and unknown dates globally last in either date direction. Current settings apply after pending reads. The background-sorting follow-up adds stale-sort, changed-setting publication and superseded-navigation loading regressions; Bilal accepted its manual review on 2026-10-06. | Bilal confirmed global Modified sorting in both directions and folders-first Name, then accepted Unit 2 and the now correction on 2026-10-06. Bilal also confirmed rapid sorting and Refresh/navigation during sorting. Agent checked both selections and hidden/Refresh independence in the rebuilt app. Cross-window checks remain T16. |
| A31 | Partially validated | [T04](t04-multiple-selection-primary-item.md#executed-checks): focused pane supplies its primary item. [T05 Unit 1](t05-details-metadata-sidebar.md#executed-checks): metadata, latest/cleared selection and focused-pane Refresh. [T06 Unit 1](t06-read-only-preview-highlighting.md#executed-checks): guarded content and same-item Refresh. | T01/T04/T05 accepted. Bilal confirmed all five T06 Unit 1 manual checks and accepted content, primary/clear, unsupported/link metadata, Refresh/recovery and affected appearance/accessibility on 2026-10-10. [Details scroll follow-up](t06-read-only-preview-highlighting.md#details-scroll-follow-up) retains native preview/overflow scrolling; Bilal confirmed all three manual checks passed on 2026-10-10. T16 independent windows remain pending. |
| A32 | Pending | None yet. | None yet. |
| A33 | Partially validated | [T14 Unit 1](t14-context-actions-copied-paths.md#executed-checks): shared plain formatter preserves displayed item/link identity. [T05 Unit 1](t05-details-metadata-sidebar.md#executed-checks): real own attributes/link targets, permission formatting, unavailable fields, guarded async completion and same-item Refresh. | T14 path copies accepted. Bilal confirmed metadata/unavailable size, link identity/targets/copied paths, Refresh/error recovery and affected layout/accessibility, then accepted T05 on 2026-10-10. Save/mutation refresh remains later tasks. |

## Milestone quality checkpoint

- [x] Consider analysis with the actual `code-quality-analysis` skill.
- [x] Review findings before remediation planning.
- [x] Use the actual `cluster-workflow` skill to define bounded units and approve the active unit before implementation.
- [x] Resolve correctness blockers; explicitly defer optional work.

See [workflow guidance](../prompts/README.md). The M1 maintainability analysis is complete: Bilal accepted all three findings for remediation on 2026-10-09. No current correctness blocker was demonstrated. Bilal accepted [C1/F2 sorting ownership](m1-sorting-ownership.md) and confirmed its validations passed. [C2/F1 selection interaction coverage](m1-selection-interaction.md) is accepted following Bilal’s confirmation that all manual checks passed. [C3/F3 test-gate diagnostics](m1-test-gate-diagnostics.md) are accepted after Bilal confirmed the review checklist passed. The [task tracker](../specs/001-mvp/tasks.md#m1-quality-remediation) owns progress. This maintainability checkpoint is complete: all three remediation units are verified and accepted.

## MVP completion

- [ ] A1–A33 have passing evidence or explicitly accepted deviations.
- [ ] App-wide accessibility evidence covers all applicable A/AA criteria and records any remaining gaps.
- [ ] A clean checkout builds, tests, packages and launches using documented instructions.
- [ ] Setup/run and architecture documentation match the implementation.
- [ ] Known filesystem, save and Finder limits are stated accurately.
