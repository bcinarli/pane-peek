---
task: github-ci-merge-checks
verdict: Pending
closed: ""
---

# CI and merge checks

## Workflow unit: 2026-10-17

Bilal approved CI workflow implementation and merge-check enablement, excluding release work. The unit adds one macOS build/test check and a development artifact. Configuration/packaging is validated directly rather than with artificial behaviour tests.

Checks executed before publication pass: `node scripts/test.mjs` (101 application and 455 core tests), `node scripts/build-app.mjs`, YAML parsing, Bash syntax for every run block, required-check configuration and pinned action hashes. Bundle metadata/resources and archive extraction pass, with identical executable bytes and retained permissions. The nine known-issue reports are intentional timeout-gate self-tests, verified against their matching assertions. No build warnings/errors were observed. Hosted execution on the workflow's configured toolchain remains unverified.

Tighten then probe checked the single-job scope, failure propagation, PR concurrency, credential isolation, artifact permissions and evidence boundaries. This unit changes no application UI or product/accessibility verdict; no native visual, keyboard or VoiceOver pass is claimed.

GitHub inspection confirmed Actions enabled with read-only default workflow permissions, no active `main` protection and a separate disabled Copilot-review ruleset. No remote settings have been changed.

2026-10-17: Bilal accepted the reviewed CI changes and authorised commit/publication through a PR. Implementation commit [`89d05b9`](https://github.com/bcinarli/pane-peek/commit/89d05b9f45e5cc81e96656989115660f7034b18b) is published in [PR #36](https://github.com/bcinarli/pane-peek/pull/36), targeting `main`.

## Hosted validation: 2026-10-17

The [first hosted run](https://github.com/bcinarli/pane-peek/actions/runs/39013877959) checked out the PR and selected the configured toolchain, then failed compiling [the Markdown background drawing override](../../../../sources/panepeek/MarkdownPreview.swift). Xcode 26.6 requires a non-optional `NSView` for the superclass call, while the override forwards an optional view. This is an existing application SDK-compatibility issue exposed by CI. No tests, bundle or artifact completed on that run.

GitHub reports the exact check name `macOS build and test`, supplied by the GitHub Actions app. Required-check enforcement remains disabled until hosted validation passes. A bounded application compatibility correction needs separate coding-unit approval; PR merge remains separately gated. The accepted workflow unit is published, but the overall task remains Active/Pending.
