---
task: app-store-sandbox-volumes
verdict: Passed
closed: 2026-10-20
---

# Sandbox volume compatibility

Sandbox Copy and Move work across a separately mounted APFS image, preserving contents and executable permissions; system Trash retains files, folders and listed links for recovery. Cancelled replacement and denied writes preserve their sources. Physical removable media, network volumes and macOS 26 remain unverified.

Reference: [implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826).
