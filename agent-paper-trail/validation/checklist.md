# PanePeek validation checklist

These project-wide gates apply to every unit. Each spec’s `validation.md` owns criterion verdicts; `tasks.md` owns task state and `evidence/` owns checks. Detailed earlier MVP outcomes are retained in [historical acceptance](mvp-acceptance-history.md).

## Required task gate

- [ ] Approved scope matches the maintained spec and plan.
- [ ] Meaningful automated behaviours have observed intentional red/green evidence; layout/packaging use actual build/native checks.
- [ ] Required build and targeted checks pass; the app launches with the visible result for code/UI work.
- [ ] Affected accessibility checks are recorded, with unexecuted checks explicit.
- [ ] Run instructions and disposable fixtures are available where needed.
- [ ] Bilal has accepted the unit’s manual review; automated green does not close that gate.
- [ ] Tighten followed by probe has been applied.
- [ ] Durable decisions/gotchas and concise task evidence are current.
- [ ] Commit, push and merge approval is separate from implementation approval.

Record executed checks/results, manual provenance and accepted deviations. Include OS/toolchain versions when they affect validity or reproducibility. Preserve existing evidence links and never invent closure dates or test outcomes.

## Native design checks

Use the active spec and accepted editable design sources. Record results in task evidence and the spec’s validation table. [MVP design and criterion outcomes](../specs/001-mvp/validation.md) and [earlier detailed checks](mvp-acceptance-history.md#native-design-checks) remain separately accessible.

## Accessibility checks

Use the [accepted native baseline](../decisions/2026-10-11-native-accessibility-baseline.md) and [MVP requirement](../specs/001-mvp/spec.md#accessibility-baseline).

- [ ] Record the supported text-enlargement mechanism, tested sizes and platform limits; keep narrow layouts and long paths/actions usable.
- [ ] Check applicable text/non-text contrast in light/dark and state variants; essential state has a non-colour cue.
- [ ] Exercise keyboard access, logical visible focus and absence of traps.
- [ ] Check pointer targets and accessible alternatives to dragging where applicable.
- [ ] Check VoiceOver names/roles/values and perceivable errors/status changes.
- [ ] Check relevant macOS settings, including increased contrast and reduced motion.

Affected-unit acceptance does not establish a whole-app pass. The [MVP accessibility matrix](../specs/001-mvp/validation.md#accessibility-and-native-review) retains the pending T18 audit.

## Acceptance evidence

Current MVP criterion verdicts are in [MVP validation](../specs/001-mvp/validation.md#functional-criteria). The [historical snapshot](mvp-acceptance-history.md#acceptance-evidence) preserves the previous detailed rows and their partial/unreported limits.

## Milestone quality checkpoint

Use the active plan’s quality workflow and the [current remediation rows](../specs/001-mvp/tasks.md#quality-remediation). Preserve the distinction between bounded analysis/remediation and whole-milestone completion.

### M1

[M1 evidence](../specs/001-mvp/tasks.md#m1-quality-remediation).

### M2

[M2 evidence](../specs/001-mvp/tasks.md#m2-quality-remediation).

## MVP completion

Use the [current MVP completion gates](../specs/001-mvp/validation.md#mvp-completion).

## PR 15 correction review

The [T07 evidence summary](../specs/001-mvp/evidence/preview-editor-safe-saving.md) includes accepted R1/R2 checks and verified merge. [Detailed review evidence](t07-preview-editor-safe-saving.md#pr-15-review-corrections) retains the original findings and fixtures.

## Paper-trail review

- [ ] Specs/plans hold intent, task/criterion rows hold current state, and evidence links support verdicts.
- [ ] Lifecycle fields and supersession backlinks are consistent; historical material is marked.
- [ ] Local links/anchors work and a new reader can locate the next gated slice within five minutes.
- [ ] Review bindings restate current records and their map/sync rule is current.
- [ ] Binding changes receive review from the code owner before merge; ownership is declared in [CODEOWNERS](../../.github/CODEOWNERS).
- [ ] Records follow the [content boundary](../README.md#repository-record-content): no discussion history, approval narration, session-specific details, private journals, raw chats, secrets or local-only paths; necessary validation provenance is retained.
