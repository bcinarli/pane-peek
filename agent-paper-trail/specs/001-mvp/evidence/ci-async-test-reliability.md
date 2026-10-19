---
task: ci-async-test-reliability
verdict: Passed
closed: 2026-10-19
---

# CI async test reliability

## Failure mechanism

The [native-move failure](https://github.com/bcinarli/pane-peek/actions/runs/39145527027) asserts a nil outcome while the move is still finishing its listing refresh. The [creation failure](https://github.com/bcinarli/pane-peek/actions/runs/39211928154/job/117927023532) reports a generic request timeout in both alias-publication cases. Both fixtures use five-second polling deadlines while competing with unrelated suite work.

The controlled regressions below reproduce those signatures when legitimate work exceeds the deadline. Polling with `Task.yield()` does not await operation completion; the [Swift task documentation](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Task.swift#L707-L718) also explains that yielding need not prevent starvation.

The native tests now observe completion state changes, with cancellation and an explicit thirty-second hang guard. Creation fixtures reuse the tested `OperationGate` request/release continuations and diagnostic failures, also with a thirty-second guard. The creation request gate replaces the redundant state poll. Original native delegate, filesystem, selection and publication-order assertions remain, with normal and deliberately delayed variants.

## Executed checks

- 2026-10-19, agent-observed baseline: all 573 tests pass locally. Constraining the unchanged suite to one cooperative worker reproduces both creation timeout cases and also exposes unrelated fixture deadlines; that extreme full-suite run fails and is not a passing validation claim.
- 2026-10-19, intentional red: a six-second post-move refresh delay reproduces the nil outcome, and a six-second initial alias-request delay reproduces both creation `ETIMEDOUT` cases. With the same injected delays, both corrected regressions pass and retain the real filesystem assertions.
- 2026-10-19, final green: all 574 tests pass (112 native and 462 core), with ten expected timeout self-test issues. The 31-test affected subset passes, including normal/slow cases and the new native-wait timeout/cancellation check. Under one cooperative worker, all 195 affected/highlighting stress tests pass. No test, suite or CI check is skipped by the change.
- 2026-10-19: standard app packaging, bundle metadata validation, whitespace and 389 local linked-path checks pass. An isolated review copy with separate preferences and disposable folders launches and remains running by process inspection. Individual native interaction outcomes remain unreported.

Local checks use macOS 27.0.1, Xcode 27.0 and Swift 6.4. Hosted jobs use macOS 26.6.2, Xcode 26.6 and Swift 6.3.3.

## Hosted listing-gate correction

The [first PR run](https://github.com/bcinarli/pane-peek/actions/runs/39232885318) at `f60128f` compiles on the hosted toolchain and passes both original regressions, including all slow cases, and the native-wait diagnostic check. [Privacy checks](https://github.com/bcinarli/pane-peek/actions/runs/39232885366) pass. The macOS job fails in three unchanged directory-browsing tests because their listing fixture's ten-second deadline spans multiple completed operations; expiry then removes pending requests and causes completion errors. Bundling/archive/upload are skipped on that run.

The listing gate now cancels and clears its timer once no reads or observers remain, and ignores cancelled expiry callbacks from an earlier phase. The default ten-second active-phase limit is retained.

- 2026-10-19, intentional red: three deterministic lifecycle tests fail against the old gate, covering success/error phase completion, preserving a deadline while another read remains, and a cancelled timer aborting a newer read. No clock sleeps are used to order these regressions.
- 2026-10-19, green: all 30 directory-browsing tests pass, including existing missing-request/unreleased-operation diagnostics. All 577 tests pass in an unchanged-source full recheck (112 native and 465 core), with ten expected diagnostic issues. The same 30 browsing tests pass in isolation with one cooperative worker; the hosted result is recorded below.

The first local full run of this follow-up passes all 465 core tests but fails one unchanged `WindowRestorationTests` diagnostic self-test: its one-second poll observes a nil error before the expected timeout result is assigned. This [previously recorded intermittent self-test](release-packaging.md#review-and-limits) is outside the listing-gate correction. That failed run remains part of the validation evidence; the passing unchanged-source full recheck is separate from it. The expanded 225-test single-worker stress set also fails: both `olderSuccessOrErrorCannotReplaceNewerNavigation` cases retain an overlapping read beyond the existing ten-second guard. Its 11 native tests pass. No broader stress pass or guarantee against every loaded-host timeout is claimed.

## Hosted result

2026-10-19, agent-observed: [macOS CI](https://github.com/bcinarli/pane-peek/actions/runs/39234552340/job/118000357161) passes at `0a0e824`, including all 577 tests in 74 suites with ten expected diagnostic issues. Both original normal/slow regressions and all listing lifecycle regressions pass on Xcode 26.6 / Swift 6.3.3. App bundling, bundle verification, archive creation and [artifact upload](https://github.com/bcinarli/pane-peek/actions/runs/39234552340/artifacts/12178590755) pass. [Privacy checks](https://github.com/bcinarli/pane-peek/actions/runs/39234552339) also pass. Published in [PR #49](https://github.com/bcinarli/pane-peek/pull/49).

## Review and limits

This unit changes test coordination only. Application UI, filesystem implementation and CI configuration are unchanged; no new product or accessibility acceptance is claimed. The task row owns the unit's acceptance state. The broader constrained-worker limit above remains outside the passing targeted and hosted checks.

Tighten reuses the existing operation gate, removes its duplicate polling implementation and shares one native completion wait across equivalent callers. Probe verifies timeout reporting, cancellation, delayed refresh/request completion and retained source/destination, selection and alias-publication checks. No affected UI/accessibility behaviour changes; no keyboard or VoiceOver pass is claimed.

For manual review, use two disposable folders with `source.txt` in the left folder. Command-drag it to the right and check source removal plus destination content. Create `.created.txt` in the active pane and check selection and hidden-file visibility. These smoke checks cover the unchanged A20/A21 and A24/A25 paths; their full acceptance verdicts remain separate.

Reproduce the affected checks:

```sh
node scripts/test.mjs --filter 'FileDropTests|BrowserCreationTests|OperationGateTests'
node scripts/test.mjs --filter DirectoryBrowsingTests
LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 node scripts/test.mjs --skip-build --filter 'DirectoryBrowsingTests|FileDropTests|BrowserCreationTests|OperationGateTests|.*HighlightingTests'
node scripts/test.mjs
```
