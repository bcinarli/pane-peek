---
task: visible-collection-ownership
verdict: Passed
closed: "2026-10-31"
---
# Visible collection ownership

Pane-owned visible snapshots remove repeated filtering while preserving selection, sorting, hidden-file/search transitions, mutation recovery and independent panes; automated checks, signed native smoke checks and manual behaviour review pass on macOS 27.0.1. Matched optimised comparisons against `f55db59` remove the repeated getter cost without a reproducible opening/switching regression; the release bundle grows by 1,104 bytes and retaining visible rows raises stress-process peak memory from 84.4 MB to 93.8 MB, with search results sharing storage. Spoken VoiceOver announcements and macOS 26 validation remain unverified; [PR #154](https://github.com/bcinarli/pane-peek/pull/154) carries the reviewed implementation.
