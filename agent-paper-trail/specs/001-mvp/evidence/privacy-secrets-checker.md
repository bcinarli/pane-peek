---
task: privacy-secrets-checker
verdict: Pending
closed: ""
---

# Shared privacy and secrets checker

## Unit 1: 2026-10-17

`node --test tests/tooling/privacy-check.test.mjs`: the initial regression run produced nine expected failures out of 12 tests; the final 19 tests pass with checksum-verified, offline Gitleaks 8.30.1.

Coverage includes exact exceptions, sensitive filenames, partial staging, new files/type changes, introduced-then-deleted secrets, multiline private keys, symlink isolation, scanner/report failures and redacted diagnostics. Fixtures use synthetic credentials.

Committed-tree and `main..HEAD` scans each checked 322 file versions with zero findings and eight binary files requiring manual privacy review. [Usage](../../../../scripts/README.md) and the [policy](../../../../scripts/privacy-rules.json) define the scan boundaries.

## Demo identity cleanup, 2026-10-17

Both HTML drafts use the fictional `demo` identity for paths, the Home listing and owner/group labels. Regressions reject the previous personalised paths, unreviewed demo paths and use outside the permitted files.

Browser checks pass for all three variants and Home/Users navigation. Four refreshed screenshots were visually inspected: three 1218 × 730 layout references and the 1024 × 900 overview, with their light/dark states retained. Embedded-fragment parity, identity-only source differences and JavaScript syntax checks pass.

## Unit 2: CI configuration, 2026-10-17

Local validation of the [privacy workflow](../../../../.github/workflows/privacy.yml):

- actionlint 1.7.12 validates both workflows; all five new shell blocks parse.
- The official Linux scanner archive matches its pinned SHA256 and contains the expected x64 executable.
- The 19 regressions pass with the real scanner. Actual workflow commands pass the complete proposed tree (323 file versions) and clean PR/main ranges (645 versions each), with zero findings and eight binary files per tree version.
- A synthetic secret and private path added then deleted in a disposable repository leave the final tree clean, while the PR range command exits `1` with both findings and no matched values.

Local links and whitespace checks pass.

## Hosted CI and merge enforcement, 2026-10-17

[Privacy run 39036507574](https://github.com/bcinarli/pane-peek/actions/runs/39036507574) passes on Ubuntu 24.04 with Node.js 24.21.0 at `d0a8cbf`: all 19 regressions, checksum-verified scanner setup, complete-tree scan (323 file versions, zero findings, eight binary files) and introduced-PR-history scan (645 versions, zero findings, 16 binary versions). No scanner reports were uploaded. The hosted regression suite includes synthetic finding/error cases and verifies rejection and redaction.

Live readback of [Main PR checks](https://github.com/bcinarli/pane-peek/rules/25297015) and effective `main` rules confirms required `Privacy and secrets` and `macOS build and test` checks, both bound to GitHub Actions app `15368`, with strict up-to-date enforcement. PR/resolved-thread requirements, force-push/deletion blocks and no bypass actors are retained; the separate disabled Copilot ruleset is unchanged.

The initial [macOS run 39036507533](https://github.com/bcinarli/pane-peek/actions/runs/39036507533) completes all 557 tests but reports five unexpected issues in the restoration-gate timeout fixture; build/archive steps are skipped. [Attempt 2](https://github.com/bcinarli/pane-peek/actions/runs/39036507533/attempts/2) at the same commit passes all 557 tests and build/archive/upload steps. No source or test changes occurred between attempts; the first-attempt timing failure remains unresolved.

## Validation limits

The hosted main-push trigger remains unexercised before merge. Binary/screenshot content, arbitrary private prose and history outside the requested range require separate review. No new native application or accessibility validation is claimed.
