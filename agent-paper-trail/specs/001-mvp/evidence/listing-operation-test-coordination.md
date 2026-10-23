---
task: listing-operation-test-coordination
verdict: Passed
closed: "2026-10-23"
---

# Listing and operation test coordination

Controlled listing and operation tests use explicit request acknowledgement and scoped cleanup; paired gates close before owned workers are joined. Validation passes locally on Swift 6.4 and in CI on Swift 6.3.3 and macOS 26. Other operation tests still contain callback polling.

Reference: [PR #107](https://github.com/bcinarli/pane-peek/pull/107).
