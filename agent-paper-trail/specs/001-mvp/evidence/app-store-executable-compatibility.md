---
task: app-store-executable-compatibility
verdict: Passed
closed: 2026-10-20
---

# Executable-file and quarantine compatibility

Sandbox script Copy and Save retain executable permissions with OS-managed quarantine; ordinary atomic Save preserves existing quarantine. Sandbox operations may replace quarantine provenance. Other executable types, full Finder/Gatekeeper launch acceptance and macOS 26 remain unverified.

Reference: [implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826).
