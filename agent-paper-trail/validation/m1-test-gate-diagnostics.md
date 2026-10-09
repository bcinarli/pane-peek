# M1 test gate diagnostics validation

Status: accepted. Bilal confirmed the C3/F3 review checklist passed on 2026-10-09 and authorised commit, push and PR creation. Implementation and agent validation are complete. C1/F2 and C2/F1 are committed as `2480e38` and `13cfae1` on `bcinarli/m1-quality-remediation`.

## Change

The local `ListingGate` and `SortGate` retain their URL and integer request identities. Each starts a ten-second watchdog on its first suspension. If it expires with pending work, it records the request/observer identities and releases every continuation. Missing or repeated completions throw a diagnostic error; duplicate registrations abort rather than overwrite continuations.

The sort helper keeps each request and its continuation together. Its non-throwing API releases sorts with their calculated result after a gate failure is reported. No production API or app source changes. Existing tests still choose completion order explicitly; the watchdog is a failure bound, not a product latency assertion.

Seven new tests cover unexpected/repeated completions, absent requests, unfinished reads/sorts, all pending operation cleanup and duplicate registrations. Timeout cases also check that late completions throw instead of resuming a released continuation.

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4, SDK 27.0, Node 26.1.0. Minimum macOS 26 runtime remains untested.

- Red: `node scripts/test.mjs --filter 'GateRejectsUnexpectedCompletions'` compiled successfully, then failed with five intended expectations across two tests because missing/repeated completions threw no error.
- Green: the diagnostic tests and existing navigation/sorting suite passed after implementation. `node scripts/test.mjs --filter 'Gate|gatesReject'` passed all seven new tests.
- Final full suite: `node scripts/test.mjs` passes 39 tests in five suites, including the late-completion checks. Four known issues are deliberately injected zero-duration timeout diagnostics, matched to their exact expected errors. Missing diagnostics or unrelated failures would fail the tests.
- Build/package, `Info.plist` lint and matching built/bundled executable hashes pass. The previous generated executable was preserved through the [documented recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery). The freshly packaged bundle launches. Known non-fatal CLT search-path warnings remain; normal compiler-cache access used escalation.
- Native smoke in the retained [selection fixture](m1-selection-interaction.md#manual-review): both directories load; left Name descending/ascending and Command-R retain selected `file2.txt`, its Details path and right selected `right2.txt` with independent Name ascending order. Both panes finish Name ascending with hidden files off. Initial Home loading remains the previously recorded observation; explicit fixture navigation succeeds.
- Whitespace and scope checks pass. App/core source, package and build scripts are unchanged by C3.

Standard tighten kept the helpers local, combined the sort request/continuation dictionaries and removed the resulting forced lookup. A small amount of watchdog duplication keeps the two gate contracts readable. Standard probe checked timeout reporting, missing/repeated/late completion, duplicate registration, actor-serialised removal/resumption and cleanup. No further C3 blocker was found.

## Review checkpoint

- [x] Review the local gate diagnostics and cleanup tests, including the four deliberately matched timeout issues.
- [x] In the running app, sort and Refresh one pane; selection, Details and the other pane remain intact.

At handoff, the rebuilt app was running in the disposable fixture. To repeat validation or relaunch:

```sh
node scripts/test.mjs
open .build/PanePeek.app
```

See the [build/run instructions](../../README.md#build-and-run) and [selection fixture recipe](m1-selection-interaction.md#manual-review) for fresh setup. Bilal accepted all three units and authorised their publication through a PR. Merge retains its separate approval gate.
