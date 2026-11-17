# PanePeek validation checklist

Apply the [engineering and review rules](../engineering-and-review.md) and the owning workstream's acceptance criteria.

## Required task gate

- [ ] The change matches agreed scope and governing requirements. Required dependencies are published and agreed review checkpoints are identified.
- [ ] Meaningful behaviour tests have intentional red/green evidence. Required checks pass on each affected surface.
- [ ] [Required performance evidence](../engineering-and-review.md#performance-checks-for-feature-development) covers elapsed time, CPU, RSS and app size. Pending measurements and material differences are explicit.
- [ ] Affected accessibility checks and any unexecuted checks are recorded.
- [ ] The review includes the result, criteria, evidence, run and fixture instructions as needed, and a short manual checklist.
- [ ] [Self-review](../engineering-and-review.md#self-review) is complete: simplify first, then check realistic failure modes and supporting evidence. No personal skills are required.
- [ ] Changed eligible facts and affected acceptance are current under the content boundary. No per-unit record or duplicate verdict is required.
- [ ] Agreed checkpoints are satisfied; manual validation and maintainer acceptance of the delivered result remain explicit. No default per-unit approval is required.
- [ ] Maintainer/code-owner review is required before merge; release and distribution have explicit maintainer authority. Branch writes respect contributor permissions and agent-user authorisation.

## Native design checks

Use the active spec and [accepted editable design sources](../design/001-mvp/README.md). Put detailed affected checks in the PR review home and criterion verdicts in the owning validation record. Use a conversation draft when shared writing is unavailable or unauthorised.

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

- [ ] Specs hold requirements, issues hold new delivery plans/handoffs, and the configured acceptance home owns criterion verdicts. Legacy owners remain intact; optional outcome summaries do not duplicate verdicts.
- [ ] Lifecycle fields and supersession backlinks are consistent; superseded records point to current owners.
- [ ] Local links/anchors work and a new reader can locate the next gated slice within five minutes.
- [ ] Review bindings restate current records and their map/sync rule is current.
- [ ] Binding changes receive review from the code owner before merge; ownership is declared in [CODEOWNERS](../../.github/CODEOWNERS).
- [ ] Apply the [content boundary](../README.md#content-boundary) before every record check. Excluded work requires no record, renamed summary, linked summary, omission note or backfill. Eligible outcomes retain necessary provenance.
