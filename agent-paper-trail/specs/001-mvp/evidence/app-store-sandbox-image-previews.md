---
task: app-store-sandbox-image-previews
verdict: Passed
closed: 2026-10-20
---

# Sandbox image previews

Read-only image previews retain granted access through decoding, preserve image bounds and reject file-link targets. macOS 26 and broader accessibility acceptance remain pending.

Reference: [implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826).
