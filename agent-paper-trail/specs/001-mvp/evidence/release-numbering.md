---
task: release-numbering
verdict: Passed
closed: "2026-10-18"
---

# Release numbering

The [plan](../plan.md#release-numbering) owns scope and validation. The [task tracker](../tasks.md#build-and-repository-automation) owns acceptance and publication state. Closing publication: [PR #46](https://github.com/bcinarli/pane-peek/pull/46), whose checks and merge state provide hosted evidence.

## Executed checks

- 2026-10-18: six initial CLI regressions fail against a non-mutating scaffold, including build 3 instead of 4, unchanged requested version, missing validation/lock handling and duplicate concurrent allocations. After implementation, all eight numbering regressions and all 50 tooling tests pass. Checks cover consecutive allocation, explicit version selection, invalid-input preservation, exhausted counters, foreign-lock preservation, eight overlapping processes with continuous valid-JSON reads, file permissions and the shared packaging-validation boundary.
- 2026-10-18, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: actual preparation reserves version 0.1.0, build 4. Development and two release builds complete without diagnostics and retain byte-identical version metadata. Both ZIP names, app plists and checksums match 0.1.0 (4). Final extraction preserves all ten bundle files and modes. An actual build-tool failure in a disposable checkout leaves allocated build 4 intact; its next preparation allocates 5.
- 2026-10-18: an isolated review app is launched from the extracted package, using a separate preferences domain and disposable sample directories. Its executable matches the archive. About/version display, preview interaction and native accessibility remain manual checks. App sources are unchanged; local checks did not rerun the full Swift suite. Hosted results are recorded on the linked PR.

## Review and limits

Check About displays 0.1.0 (4) and the sample preview opens. Rebuilding with the documented development or release command must retain that metadata. Use preparation only when reserving a new candidate; use its version option only when selecting a new release version. Individual native/accessibility outcomes remain unreported; overall acceptance is recorded in the task tracker.

Tighten retains one shared metadata validator and removes optional fixture dependency checks. Probe verifies same-file concurrency, atomic JSON visibility, unchanged invalid inputs and consumed numbers after later build failures. Independent worktrees/clones require release coordination. An interrupted preparation can leave its lock for explicit recovery; automatic stale-lock removal is excluded. Signing, notarisation, public release and app-wide accessibility retain separate gates.
