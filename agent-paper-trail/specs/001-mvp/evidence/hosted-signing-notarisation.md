---
task: hosted-signing-notarisation
verdict: Failed
closed: ""
---

# Hosted signing and notarisation

The [plan](../plan.md#hosted-signing-and-notarisation) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns review and publication state. Implementation: [PR #55](https://github.com/bcinarli/pane-peek/pull/55).

## Executed checks

- 2026-10-19: six initial credential-lifecycle regressions fail against no-op functions; all six pass after implementation. They cover supported runner/event/ref/source, missing/invalid secrets, temporary credential isolation, redacted failures, output ordering, preserved Keychain entries, retry cleanup and unowned-path preservation. An additional notary protocol regression fails without explicit temporary-Keychain selection, then passes for every service operation. All 77 final tooling tests pass.
- 2026-10-19: actual macOS tools import a newly generated synthetic PKCS12 identity into the temporary Keychain, confirm it contains the matching key, reject it as an eligible Developer ID identity and remove the temporary Keychain/files. The original search list is unchanged and no workflow outputs are exposed. No existing private identity is exported or used by this check.
- 2026-10-19: the live release environment permits only the `main` branch. All six required environment secret names are present. Validation inspects policy and secret-name metadata only; it does not read or write secret values. Authentication remains unverified until the hosted run. Workflow YAML parses successfully; syntax/whitespace checks pass. Workflow shell/security checks pass, including trigger/ref/environment restrictions, step-scoped credentials, always-run cleanup, pinned actions and artifact allowlist. Privacy scanning of all 15 proposed file versions finds no issues or changed binaries and preserves the real Git index; all 518 local documentation links/anchors checked in changed Markdown resolve. Hosted execution/download remains pending.

- 2026-10-19, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: all 595 release tests pass with `--no-parallel` (130 app, 465 core; ten expected known issues). The actual existing signed-only build and ZIP checksum/extraction/signature/notices/permissions checks pass. Version metadata remains byte-identical at 1.0.0 (5); no new notarisation upload occurs in this compatibility check. This does not establish a hosted execution result.

## Hosted execution

- 2026-10-19: [PR #55](https://github.com/bcinarli/pane-peek/pull/55) is merged as `19ecb19d08ae638ad066f5a68c5c8998c3da7723`. Exact-merge main [build/test](https://github.com/bcinarli/pane-peek/actions/runs/39282795393) and [privacy](https://github.com/bcinarli/pane-peek/actions/runs/39282795545) pass.
- 2026-10-19: the single [hosted preparation run](https://github.com/bcinarli/pane-peek/actions/runs/39286111949) passes source/CI eligibility but fails its parallel release suite: 595 tests in 76 suites report eleven issues, ten expected. `WindowRestorationTests.missingReadsOrReleaseReportsTimeout(missingReads: false)` reaches its one-second polling deadline before the asynchronous error is assigned, so the assertion observes `nil`. This matches the [recorded diagnostic limitation](ci-async-test-reliability.md#hosted-listing-gate-correction).
- 2026-10-19: signing/notarisation, archive verification and upload are skipped; always-run cleanup passes. The artifact API reports zero artifacts. Hosted Apple credential authentication and downloaded-app validation remain unexercised. No workflow retry or new notarisation submission is made.

## Review passes

Tighten reuses the existing source gate, bundler and artifact contract, with one temporary-credential owner and shared identity validation. Probe covers private file modes, explicit Keychain selection, redacted errors, failure cleanup and deferred outputs; real synthetic-Keychain and signed archive checks exercise native seams. Hosted submission state is not restored across disposable runners; inspect service history before another upload after an uncertain result.

## Review and limits

Hosted execution is Failed at the release-test gate. The [local test correction](restoration-timeout-coordination.md) passes full parallel release validation; a hosted retry from corrected main is still required before validating actual authentication, packaging and the downloaded app. Hosted app/package review remains pending; existing app UI is unchanged. Real browser quarantine installation, public access and App Store preparation retain separate units; native/accessibility outcomes remain unreported.
