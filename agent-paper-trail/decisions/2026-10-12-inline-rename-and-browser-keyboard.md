---
status: Accepted
date: 2026-10-12
supersedes: []
superseded_by: ""
---

# Inline rename and browser keyboard

## Context

During T09 review, Bilal requested Finder-like renaming and approved the proposed inline follow-up on 2026-10-12. PanePeek's previous single-item rename opened a name sheet; Return/double-click opened a selected directory.

## Decision

Edit the selected filename inline in its browser row. Return on one selected item begins rename, Return in the field submits and Escape cancels while restoring list focus. Initially select the basename without its final extension, keeping the extension editable; directory names are selected whole. A dotfile without a further extension is selected whole. Context-menu and File-menu Rename open this same editor.

Double-click and Command-Down open a selected navigable directory. Return is reserved for rename when the browser list has focus. Editor and other text-field key handling remains local to those controls. Preserve single-item targeting, selection/browser identity, collision checks and affected-document Save/Discard/Cancel safeguards.

This accepts the interaction direction, not the native implementation or accessibility result. Each coding unit and manual/source-control gate still applies.

## Rationale and alternatives

Inline editing keeps the filename in context and avoids a separate name-entry sheet. The sheet is simpler to implement but interrupts this common operation. Keeping Return for directory opening would differ from the requested rename interaction; Command-Down and double-click preserve keyboard and pointer directory access.

Apple documents [Return to begin/confirm rename](https://support.apple.com/en-ie/guide/mac-help/mchlp1144/27/mac/27) and [Command-Down to open the selected item](https://support.apple.com/en-us/102650). PanePeek continues to preview files internally; this decision adds no external-application launching or batch rename.

## Related records

- [A23 and file-management rules](../specs/001-mvp/spec.md#file-management)
- [T09 plan](../specs/001-mvp/plan.md#t09-rename-and-affected-document-handling)
- [T09 evidence](../specs/001-mvp/evidence/rename-affected-document-handling.md)
