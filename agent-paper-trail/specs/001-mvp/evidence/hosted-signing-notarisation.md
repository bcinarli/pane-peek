---
task: hosted-signing-notarisation
verdict: Pending
closed: ""
---

# Hosted signing and notarisation

The [plan](../plan.md#hosted-signing-and-notarisation) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns review and publication state.

## Executed checks

- 2026-10-19: six initial credential-lifecycle regressions fail against no-op functions; all six pass after implementation. They cover supported runner/event/ref/source, missing/invalid secrets, temporary credential isolation, redacted failures, output ordering, preserved Keychain entries, retry cleanup and unowned-path preservation. An additional notary protocol regression fails without explicit temporary-Keychain selection, then passes for every service operation. All 77 final tooling tests pass.
- 2026-10-19: actual macOS tools import a newly generated synthetic PKCS12 identity into the temporary Keychain, confirm it contains the matching key, reject it as an eligible Developer ID identity and remove the temporary Keychain/files. The original search list is unchanged and no workflow outputs are exposed. No existing private identity is exported or used by this check.
- 2026-10-19: the live release environment permits only the `main` branch. All six required environment secret names are present. Validation inspects policy and secret-name metadata only; it does not read or write secret values. Authentication remains unverified until the hosted run. Workflow YAML parses successfully; syntax/whitespace checks pass. Workflow shell/security checks pass, including trigger/ref/environment restrictions, step-scoped credentials, always-run cleanup, pinned actions and artifact allowlist. Privacy scanning of all 15 proposed file versions finds no issues or changed binaries and preserves the real Git index; all 518 local documentation links/anchors checked in changed Markdown resolve. Hosted execution/download remains pending.

- 2026-10-19, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: all 595 release tests pass with `--no-parallel` (130 app, 465 core; ten expected known issues). The actual existing signed-only build and ZIP checksum/extraction/signature/notices/permissions checks pass. Version metadata remains byte-identical at 1.0.0 (5); no new notarisation upload occurs in this compatibility check. This does not establish a hosted execution result.

## Review passes

Tighten reuses the existing source gate, bundler and artifact contract, with one temporary-credential owner and shared identity validation. Probe covers private file modes, explicit Keychain selection, redacted errors, failure cleanup and deferred outputs; real synthetic-Keychain and signed archive checks exercise native seams. Hosted submission state is not restored across disposable runners; inspect service history before another upload after an uncertain result.

## Review and limits

Hosted app/package review remains pending. Existing app UI is unchanged. After trusted publication and credential setup, validate the actual hosted package and downloaded app before claiming hosted signing/notarisation success. Real browser quarantine installation, public access and App Store preparation retain separate units; native/accessibility outcomes remain unreported.
