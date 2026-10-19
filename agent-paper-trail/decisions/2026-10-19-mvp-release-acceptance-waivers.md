---
status: Accepted
date: "2026-10-19"
supersedes: []
superseded_by: ""
---

# MVP release acceptance waivers

## Context

PanePeek 1.0.0 (7) has accepted functional app review and passing local release checks. Parts of the full acceptance matrix, app-wide accessibility audit, clean-checkout/platform checks and production-icon validation remain unverified.

## Decision

Complete T18 for this candidate with a Waived verdict for the remaining unverified acceptance checks. Retain existing passing evidence and mark only unverified portions of the functional and accessibility criteria Waived. The validation matrix retains their scope for follow-up; this decision does not establish passing outcomes or accessibility conformance.

Accepting the reviewed candidate with explicit coverage limits is selected over completing every remaining check before closure or leaving T18 pending. This waiver is specific to 1.0.0 (7) and does not automatically cover later app changes.

## Limits

Required CI, privacy, signing, notarisation and package/download-integrity checks still require passing evidence. Hosted validation, public distribution and App Store submission keep their separate gates. The current icon is accepted for this release without claiming unperformed small-size or production-icon validation.
