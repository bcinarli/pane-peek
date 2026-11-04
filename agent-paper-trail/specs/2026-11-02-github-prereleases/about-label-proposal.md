---
status: Proposed
date: 2026-11-04
---

# Prerelease identity in About

About shows `Version 1.3.0 (11)` for `v1.3.0-beta.1`. The [accepted contract](README.md#candidate-identity) keeps app metadata numeric and candidate labels in GitHub metadata, so the installed app does not display its beta identity.

Proposed display: `Version 1.3.0-beta.1 (11)`. Keep `version.json` and the numeric bundle version/build contract, and package candidate kind/sequence separately for local display. Stable builds must omit the suffix; RCs and local review packages need explicit behaviour, without network lookup.

Review this extension to the current app-UI exclusion and its display draft before implementation. Apply it to a new candidate; the published beta remains immutable.
