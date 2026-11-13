---
task: cli-incoming-open-restoration-and-save
verdict: Passed
closed: 2026-11-12
---

# Startup fallback and Save proof

An uncommitted incoming listing cannot displace the saved startup path. Successful Save writes provide replacement evidence even when a preview loads and saves while preparation is suspended. Signed manual review for [PR #192](https://github.com/bcinarli/pane-peek/pull/192) confirmed that Dock reopen restores the saved folder and that same-file Save displays the updated text without an open error.
