---
task: document-find-match-feedback
verdict: Passed
closed: "2026-11-08"
---

# Document Find match feedback

Zero-match feedback is resolved, and native match reveal and ordinary resize retention preserve selection, drafts and Undo in [PR #183](https://github.com/bcinarli/pane-peek/pull/183).

[#182](https://github.com/bcinarli/pane-peek/issues/182) tracks reproducible gaps above and below the active match after mode, Details-width and query changes. Find navigation can repaint the missing rows. The cause remains open.

## Incremental Find highlights

The editor skips the native reveal when the entire match is visible outside the Find bar. Clipped and offscreen matches still use native scrolling. In the signed app on macOS 27.2.1, Python and plain-text documents show active and inactive marks in Preview and Edit. Light appearance, VoiceOver and native macOS 26 acceptance remain unverified.
