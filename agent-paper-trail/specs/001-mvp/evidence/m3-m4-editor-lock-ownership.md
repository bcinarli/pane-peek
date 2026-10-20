---
task: m3-m4-editor-lock-ownership
verdict: Passed
closed: "2026-10-14"
---

# M3/M4 editor-lock ownership

The shared coordinator owns affected-path edit and Save exclusion through operation decisions and completion. Unrelated editing remains available; cancellation releases the reservation.

Reference: [PR #31](https://github.com/bcinarli/pane-peek/pull/31).
