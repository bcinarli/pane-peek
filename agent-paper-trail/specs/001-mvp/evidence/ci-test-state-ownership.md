---
task: ci-test-state-ownership
verdict: Pending
closed: ""
---

# Concurrent test-state ownership

Shared test completion state has checked `Sendable` reference ownership and mutex-protected access, retaining task-join and sort-result assertions. Local validation passes on Swift 6.4; confirmation on CI’s Swift 6.3.3 and macOS 26 remains pending.

Reference: [PR #107](https://github.com/bcinarli/pane-peek/pull/107).
