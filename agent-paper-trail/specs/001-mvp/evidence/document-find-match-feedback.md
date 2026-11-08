---
task: document-find-match-feedback
verdict: Passed
closed: "2026-11-08"
---

# Document Find match feedback

Native range reveal and ordinary reflow retention pass automated and signed-app checks under [#182](https://github.com/bcinarli/pane-peek/issues/182), preserving nonempty offscreen selection, drafts and Undo through native resizing. [PR #183](https://github.com/bcinarli/pane-peek/pull/183) covers the accepted reviewed correction. A transient blank region after rapid mode/width/query changes remains under review; the original intermittent zero-count variant, broader accessibility and native macOS 26 acceptance remain unverified.
