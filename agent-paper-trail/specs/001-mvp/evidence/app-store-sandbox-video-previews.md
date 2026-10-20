---
task: app-store-sandbox-video-previews
verdict: Passed
closed: 2026-10-20
---

# Sandbox video previews

Read-only video uses bounded reads from the opened file and retains access through playback teardown. File-link previews are unavailable; macOS 26 and broader accessibility acceptance remain pending.

Reference: [implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826).
