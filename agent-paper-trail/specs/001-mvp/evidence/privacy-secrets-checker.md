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

## Validation limits

Hosted Linux/Node.js 24 execution and the live required-check binding remain unverified. Binary/screenshot content, arbitrary private prose and history outside the requested range require separate review. No new native application or accessibility validation is claimed.
