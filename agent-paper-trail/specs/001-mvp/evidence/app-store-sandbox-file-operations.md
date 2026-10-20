---
task: app-store-sandbox-file-operations
verdict: Passed
closed: 2026-10-20
---

# Sandbox file operations

File operations retain captured source/destination grants through naming, decisions, filesystem work and recovery. [Volume compatibility](app-store-sandbox-volumes.md) and [current sandbox limits](../../../notes/2026-10-20-app-store-sandbox-design.md#capabilities-and-limitations) define the supported scope.

Reference: [implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826).
