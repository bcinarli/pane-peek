---
task: macos-tooling-coverage
verdict: Passed
closed: "2026-11-11"
---

# macOS tooling coverage

The CI step in `b02fc2a` runs the macOS tooling checks skipped on Linux alongside runner and release-numbering validation. The selected checks pass without skips on hosted macOS 26 with Node 24. [PR #187](https://github.com/bcinarli/pane-peek/pull/187)
