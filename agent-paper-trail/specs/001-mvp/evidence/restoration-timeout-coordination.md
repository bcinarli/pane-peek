---
task: restoration-timeout-coordination
verdict: Passed
closed: "2026-10-19"
---

# Restoration timeout coordination

The [plan](../plan.md#restoration-timeout-coordination) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns review and publication state.

## Failure mechanism

The [hosted release run](https://github.com/bcinarli/pane-peek/actions/runs/39286111949) reports a nil error in `missingReadsOrReleaseReportsTimeout`. The read gate publishes its timeout and resumes its continuations before the requesting task necessarily runs its error handler. A one-second `Task.yield()` poll observes a separate mutable error variable, then asserts and releases the gate before awaiting that task. Neither elapsed time nor yielding establishes operation completion; early release can also change the gate's terminal failure.

The diagnostic now directly awaits the operation's exact thrown error before testing release and subsequent reads. Immediate and two-second timeout cases cover both waiting states. The two-second cases exceed the removed polling limit; the gate implementation and normal ten-second guard are unchanged. A separate [Swift Testing time limit](https://developer.apple.com/documentation/testing/limitingexecutiontime) bounds each test case rather than deciding when its result is ready.

## Executed checks

- 2026-10-19, intentional red: with the old polling unchanged, both new two-second cases fail at the nil-error assertion and subsequent terminal-state checks. The two immediate cases retain their expected diagnostics.
- 2026-10-19, green: the same four cases pass after direct awaiting, with four expected timeout diagnostics and no unexpected issues. Exact timeout identity, release rejection and both subsequent-read rejections remain asserted.

- 2026-10-19, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: normal parallel release validation passes all 595 tests (130 app, 465 core) with twelve expected diagnostics and no unexpected failures. The two additional diagnostics come from the delayed cases. All 23 restoration tests pass; the two affected diagnostic tests also pass with `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`. All 77 tooling tests pass.

- 2026-10-19: actual unsigned release packaging, checksum, ZIP extraction, every bundle file/content mode, arm64/macOS metadata and packaged notices pass. Version metadata remains byte-identical at 1.0.0 (5). The extracted app launches and its running process is confirmed; native interaction/accessibility outcomes are unreported.

- 2026-10-19: proposed-file privacy scan checks all seven changed/new versions with zero findings or changed binaries; all 447 local links/anchors in six changed Markdown documents resolve. Whitespace checks pass. Only the restoration test file changes executable Swift code; app, release workflow, credentials and version metadata are unchanged.

## Review passes

Tighten removes the extra task, mirrored mutable error and polling loop, following the existing direct-await diagnostic pattern. Probe retains exact error matching and all terminal-state assertions, demonstrates failure beyond the old observation limit, and exercises normal parallel and constrained cooperative scheduling. The known-issue matcher is unchanged; each added delayed case emits its own expected timeout diagnostic.

## Review and limits

The parallel release, restoration, constrained-scheduling and tooling checks pass. Release packaging and launch pass. No app, workflow, credential or version metadata change is part of this unit; no new native/accessibility acceptance is claimed. The failed hosted run's signing steps were skipped and it produced no artifact. Actual hosted authentication and downloaded-app verification remain pending after trusted publication.
