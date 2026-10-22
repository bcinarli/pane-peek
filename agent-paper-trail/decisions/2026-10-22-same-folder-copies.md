---
status: Accepted
date: 2026-10-22
supersedes:
  - decisions/2026-10-16-browser-ui-and-preview-improvements.md
superseded_by: ""
---

# Same-folder copies

Copying selected items into their containing folder creates new items with unused numbered names before the file/package extension, without a routine naming prompt. Determine folder sameness by filesystem identity, including aliased paths and different panes/windows. Reserve names across the batch and revalidate captured sources, directories and destinations before writing; never overwrite an original or a late winner.

This replaces only the same-folder copy rejection in the [UI and transfer decision](2026-10-16-browser-ui-and-preview-improvements.md#copy-and-move-collisions). Its other requirements remain binding. Ordinary cross-folder collision choices, duplicate-input rejection, link and ancestry rules, sandbox access, affected-document safeguards and partial outcomes remain unchanged. Cut/Paste and explicit Move retain move semantics and reject moving an item onto itself. The Duplicate context-menu action applies this same contract to the guarded displayed selection in either layout, without changing clipboard contents or pending Cut intent, under [#94](https://github.com/bcinarli/pane-peek/issues/94).

Automatic numbering makes repeated Copy/Paste useful while preserving source data. Keeping rejection prevents this workflow; prompting for each same-folder name adds an unnecessary decision. The [spec](../specs/001-mvp/spec.md#copy-and-move) owns the transfer contract.
