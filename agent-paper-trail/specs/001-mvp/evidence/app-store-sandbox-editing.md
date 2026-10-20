---
task: app-store-sandbox-editing
verdict: Passed
closed: 2026-10-20
---

# Sandbox editing and safe Save

Scoped editing and atomic Save retain writable containing-folder access, protect drafts and preserve native Undo across unchanged-file refresh. [Current sandbox limits](../../../notes/2026-10-20-app-store-sandbox-design.md#capabilities-and-limitations) apply.

Reference: [implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826).
