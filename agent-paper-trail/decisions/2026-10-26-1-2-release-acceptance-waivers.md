---
status: Accepted
date: "2026-10-26"
supersedes: []
superseded_by: ""
---

# GitHub 1.2 release acceptance waivers

## Context

The signed and notarised PanePeek 1.2.0 (10) candidate has passing macOS 26 CI, verified downloaded packages and accepted macOS 26 functional smoke review. The [candidate evidence](../specs/001-mvp/evidence/github-1-2-candidate.md) records additional native checks and their limits.

## Decision and rationale

Accept this GitHub candidate with the remaining unverified portions of the [MVP validation matrix](../specs/001-mvp/validation.md) and [update validation matrix](../specs/2026-10-24-github-release-updates/validation.md) waived for this release. This includes the full accessibility/applicability audit and text-enlargement limits, unexercised native edge cases, remaining macOS 26 update/reminder/provider checks and secondary installation coverage.

Retain passing evidence and keep deferred coverage visible. Accepting the reviewed candidate with explicit limits is selected over delaying it for every outstanding check. The waiver does not establish passing outcomes or accessibility conformance.

## Limits

This applies only to 1.2.0 (10) with the reviewed app source in [`3dfa4fb`](https://github.com/bcinarli/pane-peek/commit/3dfa4fbb6181a1dfaae0ad4744df2c4e42fbf134). App changes or later releases require renewed review; the earlier 1.0.0 decision remains historical.

CI, privacy and the approved data/host boundary, signing, notarisation and package/download integrity still require passing evidence. Known faults are not waived. Public-release approval and verification of published downloads remain separate gates. This decision grants no App Store acceptance.
