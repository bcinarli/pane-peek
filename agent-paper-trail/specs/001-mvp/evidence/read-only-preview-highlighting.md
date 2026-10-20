---
task: read-only-preview-highlighting
verdict: Passed
closed: 2026-10-11
---

# Evidence: read-only-preview-highlighting

Text preview is bounded UTF-8 with lexical highlighting and stale-read protection. Highlighting is not a parser; unsupported or binary text uses unavailable-preview behaviour.

Reference: [PR #13](https://github.com/bcinarli/pane-peek/pull/13).
