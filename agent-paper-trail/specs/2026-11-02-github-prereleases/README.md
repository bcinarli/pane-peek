---
status: Accepted
date: 2026-11-02
supersedes: []
superseded_by: ""
---

# GitHub prerelease preparation

Publish betas after coherent batches of fixes or features, then prepare a stable release after acceptance. An optional RC can support final validation once the intended scope is complete. Candidates are selected deliberately from reviewed main commits.

Preserve the [read-only preparation and manual publication contract](../001-mvp/spec.md#github-release-preparation), existing signing/notarisation checks and [stable-only updater](../2026-10-24-github-release-updates/spec.md#release-checks-and-reminders). Existing [updater acceptance limits](../2026-10-24-github-release-updates/validation.md) remain applicable.

## Candidate identity

| Kind | Example tag | Publication |
| --- | --- | --- |
| Beta | `v1.3.0-beta.1` | Prerelease, excluded from Latest. |
| Release candidate (optional) | `v1.3.0-rc.1` | Prerelease, excluded from Latest. |
| Stable | `v1.3.0` | Separate stable release after acceptance. |

The draft target is 1.3.0; release metadata and build allocation remain separate. Beta/RC sequences are positive safe integers, unique within each version and kind. Refuse existing candidate tags/releases; corrections use a new identity rather than replacing published assets.

Keep [version.json](../../../version.json) as the sole numeric app version/build owner. An explicitly prepared beta or RC carries its validated kind and sequence as a separate About suffix, final before signing. About shows the suffix on its selectable version line, for example `Version 1.3.0-beta.2 (12)`, using local bundle metadata. Stable, App Store and ordinary local builds use their existing numeric display. The updater continues to compare the numeric bundle version/build and select stable releases only.

Select a target version newer than the latest stable release and reserve each new candidate's build through the [existing tool](../../../scripts/prepare-release.mjs). Its allocation, rebuild and worktree-coordination rules still apply.

The final stable build must exceed every shared beta/RC build for that version. Publish it under the numeric tag after packaging and acceptance. Clearing a suffixed tag's prerelease flag does not make it eligible for the current updater.

## Preparation and publication

Accept kind `stable`, `beta` or `rc`, defaulting to stable. Require a valid sequence for beta/RC and reject sequences for stable before signing. Use these inputs and assigned metadata to derive the tag/title and About suffix. Include kind/sequence in prerelease review-artifact names and verify the bundle matches the selected candidate before producing release notes.

Notes identify the tag, numeric app version/build and exact source commit. Beta/RC notes use non-empty Unreleased app changes from that commit, without dating or moving the stable changelog entry. Preserve stable note selection. Keep maintainer procedures in the [contributor guide](../../../CONTRIBUTING.md#github-preparation-artifacts).

Retain read-only permissions, the protected signing environment, exact-main/CI gates, credential cleanup and the asset allowlist. Preparation creates no tags/releases. Separately authorised manual publication uses the reviewed commit, notes and downloads. Verify the tag target, prerelease/Latest flags, hashes and public browser download. Expired assets require fresh preparation and review.

## Installation and validation

Testers install manually from GitHub using the production app identity and sandbox. Installing over the existing app replaces it and shares its settings. Returning to an older stable build requires manual reinstallation because the updater refuses downgrades. Notes must explain testing status, installation/return instructions and the version line displayed in About.

Each candidate requires automated, signing/notarisation, downloaded-app and focused manual validation. Keep unverified scope explicit; previous release waivers do not carry forward automatically.

| Criterion | Required outcome |
| --- | --- |
| P1 Identity | Valid kinds/sequences produce the intended tag/title; invalid combinations fail before signing; stable defaults remain compatible. |
| P2 Metadata and notes | Preparation preserves numeric app metadata; notes identify the exact source and correct changelog content. |
| P3 Hosted preparation | A real main run preserves source/CI, signing, notarisation, cleanup and asset restrictions, with clear candidate naming. |
| P4 Installation and isolation | Public downloads match checksums, install and launch; prereleases stay outside Latest; stable is eligible over a lower-build prerelease of the same version. |
| P5 Publication | Preparation performs no publication; manual publication refuses existing identities and requires separate approval. |
| P6 About identity | Beta and RC packages display the expected candidate and build in selectable, accessible About text. Numeric-only bundles retain their usual display, and package verification rejects a candidate mismatch. |

Unit tests do not establish hosted execution, public availability or native installation. Prerelease update subscriptions, side-by-side beta apps, App Store changes and automatic publication are outside scope.

## Implementation handoff

[Tasks](tasks.md) owns execution and review state; [validation](validation.md) owns acceptance verdicts.

1. Read [release-review.mjs](../../../scripts/release-review.mjs), [its tests](../../../tests/tooling/release-review.test.mjs) and [metadata validation](../../../scripts/release-metadata.mjs).
2. Implement candidate-input validation and tag/title/note generation only. Use red/green coverage for invalid kinds/sequences, stable compatibility, exact source/metadata and prerelease Unreleased selection when a matching historical stable section exists. Preserve numeric metadata and avoid network writes.
3. Apply tighten then probe, report validation and stop for unit review. Obtain approval for the next unit: hosted inputs, pre-signing validation, artifact names and contributor instructions. Candidate allocation, distribution and publication retain separate gates.

### About candidate label

Use the existing candidate inputs and [accepted display draft](about-label-proposal.md) in one unit. Package and verify the suffix, including mismatched candidate rejection, and exercise About with beta, RC and numeric-only bundles. Review the version line, selection and VoiceOver in a signed local candidate. Hosted preparation and distribution retain separate gates.

## GitHub references

[Release management](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository), [latest-release selection](https://docs.github.com/en/rest/releases/releases#get-the-latest-release) and [CLI publication controls](https://cli.github.com/manual/gh_release_create).
