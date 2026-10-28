---
task: selective-codeql
verdict: Pending
closed: ""
---

# Selective CodeQL scans

[PR #140](https://github.com/bcinarli/pane-peek/pull/140) is merged and advanced CodeQL is active, with the two pinned CodeQL actions allowed under the existing repository restrictions. The full main scan of [102cca1](https://github.com/bcinarli/pane-peek/commit/102cca1ae255ae6840c6a4d1d9f4952c301c826c) passed for Swift, JS/TS and Actions, with successful uploads and application/core Swift source coverage verified. Main-push and weekly triggers are preserved; hosted PR scan/skip cases and the first actual weekly execution remain pending, with no application UI or accessibility behaviour changes.
