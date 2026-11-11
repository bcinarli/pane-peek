---
task: cli-open-save-retries
verdict: Passed
closed: 2026-11-11
---

# Save during incoming opens

Incoming opens accept verified same-file Saves during access acquisition and listing retries. A different replacement at the same path leaves the prior pane state intact. Signed review confirmed same-file Save and selection for [PR #192](https://github.com/bcinarli/pane-peek/pull/192).
