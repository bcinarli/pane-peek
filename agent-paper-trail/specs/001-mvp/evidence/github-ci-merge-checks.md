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

GitHub reports the exact check name `macOS build and test`, supplied by the GitHub Actions app. Required-check enforcement remains disabled until hosted validation passes. The accepted workflow unit is published, but the overall task remains Active/Pending.

## SDK compatibility correction: 2026-10-17

Bilal approved the correction and requested another CI run. Commit [`1b78976`](https://github.com/bcinarli/pane-peek/commit/1b789762c223c9e02730cfabc4506e59d07f4387) keeps custom fill drawing and forwards to the superclass only when its optional view is present, satisfying both SDK signatures without force-unwrapping. The existing two `MarkdownPreviewTests`, app bundle build and metadata/resource checks pass. Tighten then probe checked the optional/non-optional forwarding and unchanged custom fill; documentation links, path hygiene and whitespace pass. No native visual/accessibility pass is claimed. The compiler failure is SDK/build evidence, not behavioural red/green TDD.

The [hosted rerun](https://github.com/bcinarli/pane-peek/actions/runs/39015466241) compiles the corrected application and tests with Xcode 26.6, confirming the SDK fix. The test process then aborts with signal 6 and `freed pointer was not the last allocation`; a same-revision retry reproduces it. No unexpected assertion failure was reported before the abort. The full suite, bundle and artifact did not complete, so CI remains failed. The allocator crash needs a separately approved investigation/correction unit; its root cause is not established. Required-check enforcement and PR merge remain pending.

## Test-process crash correction: 2026-10-17

Bilal approved investigation/correction and CI rerun. The [diagnostic run](https://github.com/bcinarli/pane-peek/actions/runs/39016518029) reproduces the abort even with serial diagnostic execution. Its stack identifies `swift_task_dealloc` in the default highlighting closure of `PreviewState.init`, called during `mixedSelectionMovesAndRefreshesBothPanes`. This matches the [reported Swift default-argument async-closure code-generation issue](https://github.com/swiftlang/swift/issues/92017).

The correction resolves optional highlighting and write operations inside the initializer, following its existing optional-read pattern. Default operation bodies and injected closures are preserved. The hosted crash is the regression evidence; no assertion or test is removed. The full local suite passes (101 application and 455 core tests, nine intentional timeout known issues), and the app bundle builds. Three existing unused-result warnings in rename tests remain. Tighten then probe checked unchanged operation bodies, injected closure use and suite coverage. The next hosted run progressed further but still aborted. A [second diagnostic stack](https://github.com/bcinarli/pane-peek/actions/runs/39016782324) identifies the same default-closure pattern in `ItemMove.Batch.move`. The correction therefore also moves the remaining public async closure defaults in browser operations, batch copy/move/trash and notification timing into their defining implementations. Operation bodies, cancellation and injected test hooks are preserved. Final full-suite validation and removal of temporary diagnostics remain pending.
