---
status: Accepted
date: 2026-11-16
supersedes:
  - decisions/0002-feature-branches-and-prs.md
  - decisions/0007-script-query-and-build-highlighting.md
  - decisions/2026-10-11-browser-layout-modes-and-details-sizing.md
  - decisions/2026-10-12-inline-rename-and-browser-keyboard.md
superseded_by: ""
---

# Portable contributor workflow

## Decision

The [shared engineering and review rules](../engineering-and-review.md) govern contributors without requiring personal skills or approval after every implementation unit. Agree implementation scope and intermediate checkpoints with the maintainer. Contributors may proceed within that scope between checkpoints; changed scope and unresolved prerequisites require review before dependent work continues.

Before presenting meaningful work, simplify unnecessary complexity, then check realistic failure modes, requirement conflicts and evidence gaps. Perform these checks directly or with available tools. Core engineering requirements, meaningful red/green TDD, matched performance measurements, accessibility and affected-surface validation remain binding.

Manual validation and maintainer acceptance apply to the delivered result. They do not create a default pause after every unit. Preserve genuine technical dependencies, feasibility gates, existing acceptance verdicts and scoped waivers. Maintainer/code-owner review is required before merge; waivers, releases and distribution require explicit maintainer authority.

Contributors may commit and push their own feature branches within agreed scope and repository permissions. Agents also follow their users' instructions, tool permissions and external-write authorisation. Personal approval cadence and optional skill installations belong in personal instructions.

## Scope of supersession

This decision supersedes only the personal-skill dependencies, default per-unit approval/manual-review pauses and blanket maintainer commit/push approvals in the records listed above and inherited workstream guidance. Their technical/product decisions, branch/PR boundaries, required validation and publication safeguards remain in force. Historical acceptance and authorship remain factual provenance.

## Rationale and alternatives

External contributors need executable quality standards without access to a maintainer's private tooling or availability at every step. Named skills and repeated personal approval would block otherwise authorised work. Removing quality checks would weaken the project; instead, state the checks directly and agree checkpoints where intermediate review changes a technical decision or limits rework.

The [paper-trail settings](../README.md#project-settings) own shared working/review homes; the [contribution guide](../../CONTRIBUTING.md#pull-requests) applies the workflow to human and agent-assisted contributions.
