---
task: visible-collection-ownership
verdict: Passed
closed: "2026-10-31"
---
# Visible collection ownership

Pane-owned visible snapshots preserve selection and publication guards, with verified snapshot reuse in panes unaffected by batch Trash; automated checks and the signed native build pass on macOS 27.0.1, and the unit's manual behaviour review passed. Matched optimised comparisons at `a2745a3` against `f55db59` remove the repeated getter cost without a reproducible opening/switching regression; the corrected release bundle grows by 1,104 bytes and retaining visible rows raises measured stress-process peak memory from 84.4 MB to 93.8 MB, with search results sharing storage. Spoken VoiceOver announcements and manual macOS 26 validation remain unverified; [PR #154](https://github.com/bcinarli/pane-peek/pull/154) carries the reviewed implementation.
