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

2026-10-17: Bilal accepted the reviewed CI changes and authorised commit/publication through a PR. The workflow unit is accepted; hosted validation, artifact download and live enforcement remain pending.
