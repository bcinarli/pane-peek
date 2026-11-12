---
task: cli-recovered-profile-cleanup
verdict: Passed
closed: 2026-11-11
---

# Profile cleanup after recovery

A launcher-only reinstall after stale-link recovery retains the prior receipt’s profile ownership. Uninstall removes the unchanged managed PATH block and reports edited profiles for retry. Signed manual review confirmed that uninstall removes the recovered launcher and restores the original profile bytes for [PR #192](https://github.com/bcinarli/pane-peek/pull/192).
