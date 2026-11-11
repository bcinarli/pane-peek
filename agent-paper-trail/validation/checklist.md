# PanePeek validation checklist

Apply the [engineering and review rules](../engineering-and-review.md) and the owning workstream's acceptance criteria.

## Required task gate

- [ ] The approved unit matches the spec and plan. Required dependencies are published.
- [ ] Meaningful behaviour tests have intentional red/green evidence. Required checks pass on each affected surface.
- [ ] [Required performance evidence](../engineering-and-review.md#performance-checks-for-feature-development) covers elapsed time, CPU, RSS and app size. Pending measurements and material differences are explicit.
- [ ] Affected accessibility checks and any unexecuted checks are recorded.
- [ ] The review includes the result, criteria, evidence, run and fixture instructions as needed, and a short manual checklist.
- [ ] Tighten followed by probe is complete.
- [ ] Task and criterion rows link current evidence and limits. Relevant decisions and gotchas are recorded.
- [ ] Bilal has accepted the result before the next unit starts.
- [ ] Commit, push, merge and distribution each have separate approval before execution.

## Native design checks

Use the active spec and [accepted editable design sources](../design/001-mvp/README.md). Record affected checks in task evidence and criterion verdicts in the owning validation record.

## Accessibility checks

Use the [native accessibility baseline](../specs/001-mvp/spec.md#accessibility-baseline) for app changes. Apply the owning spec to other surfaces.

- [ ] Record the text-enlargement mechanism, tested sizes and platform limits. Exercise narrow layouts and long paths or labels.
- [ ] Check contrast in light, dark and affected states. Verify non-colour cues for essential state.
- [ ] Exercise keyboard access, visible focus and focus order. Check for keyboard traps.
- [ ] Check pointer targets and alternatives to dragging where applicable.
- [ ] Check VoiceOver names, roles, values and announcements for errors or state changes.
- [ ] Check relevant system settings, including increased contrast and reduced motion.

Record the scope exercised. Whole-app accessibility and any release-specific waivers are tracked in the [native accessibility matrix](../specs/001-mvp/validation.md#accessibility-and-native-review).

## Paper-trail review

- [ ] Specs/plans hold intent, task/criterion rows hold current state, and evidence links support verdicts.
- [ ] Lifecycle fields and supersession backlinks are consistent; superseded records point to current owners.
- [ ] Local links/anchors work and a new reader can locate the next gated slice within five minutes.
- [ ] Review bindings restate current records and their map/sync rule is current.
- [ ] Binding changes receive review from the code owner before merge; ownership is declared in [CODEOWNERS](../../.github/CODEOWNERS).
- [ ] Records follow the [repository content rules](../README.md#repository-record-content) and retain the provenance needed to interpret each result.
