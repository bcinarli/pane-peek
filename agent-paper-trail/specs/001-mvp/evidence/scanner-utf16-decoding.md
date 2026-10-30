---
task: scanner-utf16-decoding
verdict: Passed
closed: "2026-10-30"
---

# Scanner UTF-16 decoding

Shared forward UTF-16 decoding in [PR #146](https://github.com/bcinarli/pane-peek/pull/146) (`c776ed1`) preserves existing language-specific identifier, escape and source-range behaviour; automated regression and signed sandbox-build checks pass. Before/after comparisons retain the existing large-document editing costs and establish no speedup, with a small bundle-size increase and no new dependency. Signed-app Dark Preview/Edit, Unicode selection, typing, Undo/Redo, normal Save and BOM/CRLF preservation checks pass; the reviewed unit is accepted, while Light appearance, full VoiceOver, enlarged text/contrast and native macOS 26 checks remain unverified.
