---
task: hosted-signing-notarisation
verdict: Passed
closed: "2026-10-19"
---

# Hosted signing and notarisation

The [plan](../plan.md#hosted-signing-and-notarisation) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns acceptance and publication state. Implementation: [PR #55](https://github.com/bcinarli/pane-peek/pull/55), with the [timeout diagnostic correction](restoration-timeout-coordination.md) in [PR #57](https://github.com/bcinarli/pane-peek/pull/57).

## Executed checks

- Credential-lifecycle and explicit-Keychain regressions exercise runner/ref/source rejection, secret validation, temporary credential isolation, redacted failures, cleanup before outputs, preserved Keychain entries, retry cleanup and unowned-path preservation. Intentional red/green checks and all 77 tooling tests pass.
- Actual macOS tools import a synthetic PKCS12 identity into the temporary Keychain, confirm its matching key, reject it as an eligible Developer ID identity and remove the temporary Keychain/files. The original search list is unchanged and no workflow outputs are exposed. No existing private identity is exported by this check.
- Live environment metadata permits only the `main` branch and confirms all six required secret names. Workflow syntax/security checks pass, including trigger/ref/environment restrictions, step-scoped credentials, always-run cleanup, pinned actions and the artifact allowlist. Setup validation reads policy and secret-name metadata only.

## Hosted execution and download

- 2026-10-19: reviewed source `91fe361ffabfbbd65caf7fb12ef985454bca8095` has passing exact-commit main [build/test](https://github.com/bcinarli/pane-peek/actions/runs/39294978585) and [privacy](https://github.com/bcinarli/pane-peek/actions/runs/39294978511) checks.
- 2026-10-19: [hosted preparation](https://github.com/bcinarli/pane-peek/actions/runs/39295372972) succeeds for that exact source. All 595 release tests in 76 suites pass with twelve expected diagnostics. Signing/notarisation, temporary-credential cleanup, extracted-archive verification and artifact upload pass. Private inspection of all fourteen log files confirms the six release environment values are masked and finds no secret-scan findings.
- 2026-10-19: authenticated download of artifact `12209500086` matches GitHub digest `sha256:17879e6e129927055da57a48e5137008331e06f3a1640d00e6f01bdf2569e6f3`. Its exact three-file allowlist contains the app ZIP, adjacent checksum and app-only notes. The inner ZIP checksum and all twelve extracted bundle files and modes match; notes identify the selected source and contain no website or procedural signing content.
- 2026-10-19, local macOS 27.0.1 arm64: the downloaded app verifies against the installed trusted Developer ID certificate and Apple requirement, with Hardened Runtime, secure timestamp and no entitlements. Stapled-ticket validation and Gatekeeper assessment pass. Version 1.0.0 (5), arm64, minimum macOS 26.0, identifier, notices, resources and executable permissions match. The unchanged app launches with its exact process path confirmed; signature verification still passes after launch.

## Review passes and limits

Tighten reuses the source gate, bundler and artifact contract with one temporary-credential owner. Probe covers credential isolation, failure cleanup, exact source/artifact provenance, downloaded signature/ticket verification and launch.

API download adds no quarantine attribute. Real browser quarantine installation, public access and App Store preparation remain separate gates. Individual native/accessibility outcomes are unreported. No tag or public GitHub Release is created.
