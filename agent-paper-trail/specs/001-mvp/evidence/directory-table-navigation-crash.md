---
task: directory-table-navigation-crash
verdict: Passed
closed: "2026-10-16"
---

# Directory table navigation crash

Native table reload ordering and row bounds checks prevent stale row callbacks from indexing a replacement listing during navigation.

Reference: [PR #32](https://github.com/bcinarli/pane-peek/pull/32).
