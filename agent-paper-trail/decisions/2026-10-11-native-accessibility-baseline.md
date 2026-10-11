---
status: Accepted
date: 2026-10-11
supersedes: []
superseded_by: ""
---

# Native accessibility baseline

## Context

Bilal established Apple-guided typography/accessibility and applicable WCAG 2.2 Level A/AA criteria as the app-wide baseline on 2026-10-09. [The typography review](../validation/ui-surfaces-details-type.md#apple-typography-follow-up) and [spec baseline](../specs/001-mvp/spec.md#accessibility-baseline) record this requirement.

## Decision and rationale

Use native semantic text styles, keyboard and accessibility APIs, interpreting applicable WCAG criteria through WCAG2ICT. Accessibility takes precedence over exact draft dimensions or colours. Font choices and visual approval alone do not establish text-enlargement, contrast or assistive-access compliance.

Each UI unit records the checks it affects, distinguishing agent observations from Bilal’s reported manual checks. T18 consolidates applicability, evidence and remaining gaps across the app.

## Alternatives considered

- Match the draft dimensions exactly: insufficient when larger text or native accessibility needs different spacing.
- Rely on native-control defaults as compliance evidence: would leave enlargement, contrast and assistive access unverified.

## Consequences

Keep unexecuted and platform-limited checks explicit. Record enlargement mechanisms/sizes and check contrast, focus, VoiceOver and dragging alternatives where applicable. Acceptance of one task does not close the app-wide accessibility audit.
