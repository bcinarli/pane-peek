---
task: m3-m4-test-gate-diagnostics
verdict: Passed
closed: "2026-10-14"
---

# M3/M4 test gate diagnostics

C1.1 addresses reviewed finding F3 from the combined M3/M4 quality analysis. Bilal approved and accepted this unit on 2026-10-14. It is committed as `77c2306` on the remediation feature branch. Published in [PR #31](https://github.com/bcinarli/pane-peek/pull/31), targeting `main`, on Bilal's 2026-10-14 authorisation; merge retains separate approval.

## Scope

Copy and Move tests now share one test-only OperationGate, also used by the existing Trash callers. Missing requests and unreleased operations produce a diagnostic timeout, release pending continuations with an error and reject later work. Mutation fixtures return failure after a gate error instead of executing their queued filesystem step. The separate restoration gate bounds its pending read batch and count observers, propagating the same failure to concurrent readers. Successful completion cancels the deadline; cancelled deadline tasks cannot expire a later phase.

Production behaviour, filesystem services and UI are unchanged. Other asynchronous fixture helpers are outside this bounded unit. No new support package or runtime dependency was introduced.

## Checks

- 2026-10-14, intentional red: missing-request and unreleased-work regressions failed because CopyGate, MoveGate and RestorationReadGate produced no timeout diagnostic. Three test declarations covered six parameter cases; the corrected regression cleanup let the run exit with status 1 rather than hang.
- 2026-10-14, final green after tighten/probe: 102 affected tests across 13 suites passed, with five expected timeout issues from gate diagnostic self-tests. Coverage includes copy, move, batch transfer, Trash, restoration, concurrent-read failure propagation, duplicate observer cleanup and duplicate completion rejection. `swift build --product PanePeek` and `git diff --check` passed on macOS 27.0.1 with Swift 6.4.
- 2026-10-14, isolated review packaging and launch/process checks passed. The running review app is `.build/quality-c1-1-review/PanePeek C1.1 Review.app`, with a separate preference domain; existing app instances were retained. Bilal accepted the unit overall on 2026-10-14; individual native observations were not separately supplied. No product UI changed, so this unit adds no affected accessibility checks; the existing T18 audit remains pending.

Reproduce the affected checks:

```sh
node scripts/test.mjs --filter 'OperationGateTests|ItemCopyTests|BatchCopyTests|BrowserCopyTests|ItemMoveTests|BrowserMoveTests|BatchMoveTests|BrowserBatchMoveTests|ItemTrashTests|BrowserTrashTests|BatchTrashTests|BrowserBatchTrashTests|WindowRestorationTests'
swift build --product PanePeek
```

Tighten consolidated identical Copy/Move helpers and removed temporary regression cleanup scaffolding. Probe checked throwing timeout propagation, concurrent reader cleanup, sticky failures and cancelled deadline handling. No findings beyond C1.1 were implemented.

## Final diagnostic correction

The C2.2 full run exposed a scheduling race in the missing-request/release self-test: its one-second poll reached cleanup before the gate's scheduled zero-timeout failure, producing ten unexpected issues in the two cases. The final presented correction directly awaits the expected typed timeout before checking sticky failure. Bilal's final-unit commit/PR instruction on 2026-10-14 authorises this correction within C2.2; the four-unit list is unchanged. Production gate behaviour is unchanged. The correction is included in final implementation commit `f78fc8c`.

- 2026-10-14: three focused gate tests passed with two expected timeout diagnostics. The final full suite passed 416 core and 56 native tests (472 total), with nine expected timeout issues. Tighten removed the extra task/poll/failure capture; probe checked typed propagation, sticky failure and known-issue reporting under the full workload.
