---
task: notarisation-stapling
verdict: Passed
closed: "2026-10-19"
---

# Notarisation and stapling

The [plan](../plan.md#notarisation-and-stapling) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns review and publication state. Merged in [PR #53](https://github.com/bcinarli/pane-peek/pull/53); [build/test](https://github.com/bcinarli/pane-peek/actions/runs/39270671840) and [privacy](https://github.com/bcinarli/pane-peek/actions/runs/39270671702) checks pass.

## Executed checks

- 2026-10-19: the six initial protocol regressions fail against a no-op implementation. All eight final focused checks pass, covering acceptance, pending/rejected/mismatched results, reported issues, unchanged submission recovery, altered code/upload bytes, missing receipts, lock preservation, stapling/ticket failures and final packaging under the job lock. External tools are bounded injected seams; real-service checks are recorded separately.
- 2026-10-19, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: all 70 tooling tests pass. Two full parallel release runs hit the [previously recorded restoration diagnostic self-test](ci-async-test-reliability.md), which observes a nil error before timeout delivery; its unchanged isolated recheck passes. The full release suite with `--no-parallel` passes all 595 tests (130 app, 465 core), with ten expected known issues and four existing test-only warnings. App/test source is unchanged by this unit; this controlled result does not establish parallel-run reliability.
- 2026-10-19: candidate 1.0.0 (5) uses the merged app source at [4cd7775](https://github.com/bcinarli/pane-peek/commit/4cd77756831dd96319e17d97df18c56a0305955c), including the Favourites and clipboard/Trash fixes, with the current release-tooling changes. Apple's real service returns Accepted, with no log issues and matching job/upload/code hashes and arm64 tickets. Stapling, ticket validation and pinned Developer ID/runtime/timestamp/signature verification pass. The real resume CLI reuses that submission and completes packaging without another upload.
- 2026-10-19: final ZIP checksum and all five workflow outputs match 1.0.0 (5). Extraction preserves the arm64 executable's permissions, macOS 26.0 minimum, compiled assets and notices. Both original and extracted apps pass strict/deep signature and stapled-ticket validation; the archive excludes operational notarisation records. Local Gatekeeper assessment accepts the extracted app as Notarized Developer ID. The exact extracted app launches and its running process is confirmed; native UI outcomes remain unreported.
- 2026-10-19: development, unsigned release and signed-only builds pass and preserve byte-identical version metadata. Unsigned and signed-only packages create no notarisation job. Syntax and whitespace checks pass. Privacy scanning of all 15 proposed file versions finds no issues or changed binaries and leaves the real Git index unchanged; all 508 local documentation links/anchors checked in changed Markdown files resolve.

## Manual review

Review scope: the exact notarised 1.0.0 (5) app/package, About metadata, browsing, preview/edit/save and the merged clipboard shortcuts on disposable documents. The task tracker owns overall review acceptance. Individual keyboard/VoiceOver and other native/accessibility outcomes remain unreported; app-wide acceptance remains T18. Preserve the signed bundle during review; changing its identifier or resources invalidates the ticket/signature.

## Review passes

Tighten shares the existing final archive/checksum/output operation between build and recovery and keeps the notary protocol in one helper. Probe covers fail-closed service results, saved-submission integrity, overlapping jobs and packaging failures, then exercises the real service, resume CLI and ZIP round trip. No app behaviour or signing exceptions are added.

## Limits

Hosted signing/notarisation credentials, public download access, real browser quarantine/Gatekeeper installation and App Store submission remain separate units. Local Gatekeeper assessment does not establish browser installation acceptance. Raw service records and credentials are excluded from Git.
