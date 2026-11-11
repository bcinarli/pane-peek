---
task: cli-busy-incoming-open
verdict: Passed
closed: 2026-11-11
---

# Busy-window incoming opens

Signed manual review of the changes based on `4cc1c4d` confirmed that only the newest request opens after the Go to Folder sheet closes. Save resumes the newest request in its captured pane. Cancel leaves the unsaved draft selected without an alert. Broader accessibility and release checks remain pending.
