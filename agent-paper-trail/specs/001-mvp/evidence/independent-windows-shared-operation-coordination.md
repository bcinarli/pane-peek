---
task: independent-windows-shared-operation-coordination
verdict: Passed
closed: "2026-10-13"
---

# T16 independent windows and shared operation coordination

Windows retain independent browser, selection and draft state while sharing favourites and affected-path operation exclusion. Captured transfers and native drag ownership survive initiating-window changes; only actually removed sources trigger document recovery.

Reference: [PR #29](https://github.com/bcinarli/pane-peek/pull/29).
