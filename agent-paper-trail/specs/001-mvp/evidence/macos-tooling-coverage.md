---
task: macos-tooling-coverage
verdict: Pending
closed: ""
---

# macOS tooling coverage

The [#186](https://github.com/bcinarli/pane-peek/issues/186) native CI step in local commit `b02fc2a` selects the existing Store asset/metadata, package-note and signing checks, covering the macOS-only cases skipped on Linux alongside runner and release-numbering validation. Workflow syntax and the selected command pass locally on macOS 27 with Node 24; hosted macOS 26 execution remains pending.
