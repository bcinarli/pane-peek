---
task: cli-busy-incoming-open
verdict: Passed
closed: 2026-11-11
---

# Busy-window incoming opens

Signed manual review of `6eaf8f0` verified that only the newest request opens in the captured pane after Go to Folder closes or Save completes. Cancel keeps the unsaved draft selected without an alert.
