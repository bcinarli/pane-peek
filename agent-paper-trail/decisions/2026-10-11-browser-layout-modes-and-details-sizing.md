---
status: Superseded
date: 2026-10-11
supersedes:
  - decisions/0003-ui-and-logo-direction.md
superseded_by: decisions/2026-10-16-window-reopen-and-relaunch-restoration.md
---

# Browser layout modes and Details sizing

## Context and confirmed direction

The layout supports one or two browsers beside expandable Details. Single-pane mode retains the active browser and preserves the hidden browser state.

The [restoration decision](2026-10-16-window-reopen-and-relaunch-restoration.md) owns persisted layout scope. Other layout and appearance choices below remain applicable.

## Decision

### Details width

- Interpret 50% as half the window's content width. Resize the whole far-right Details column, including its preview/editor and metadata.
- Retain the compact starting layout. Allow divider dragging up to the smaller of half the content width and the space remaining after visible browser minimum widths and dividers. At narrow dual-pane sizes, the achievable maximum can be below 50%.
- Add Expand Details / Restore Previous Width actions, available through a visible control and the View menu. Entering Edit does not resize automatically.
- Apply bounds continuously during dragging and window resizing, following the existing native split ownership. Preserve a requested width when temporarily clamped, so widening the window can restore it.
- Resizing preserves the document buffer and undo history. Metadata and the full path stay accessible. Preview height follows the [fluid Details contract](../specs/001-mvp/evidence/fluid-details-preview.md).

### Single and dual browser modes

- Provide a shared One Pane / Two Panes control and equivalent View menu actions. Mode belongs to each window; dual-pane remains the initial default.
- Switching to one pane keeps the most recently active browser visible, including when the editor or toolbar has keyboard focus. The other browser is hidden, retaining its directory, selection/primary item, sorting, hidden-file visibility and scroll position. Returning to two panes keeps the currently visible browser on the left and restores the preserved browser on the right. This also applies when the visible browser was formerly on the right; browser identity/state and the active document are retained.
- Preserve the current preview/editor, dirty buffer and undo history through layout changes. A layout-only change does not trigger Save / Discard / Cancel. Actual selection or navigation changes continue to follow A12.
- Shared directory actions target the visible browser. Hidden controls leave keyboard and VoiceOver navigation; they cannot become the active command target.
- Disable and reject new Copy / Move to Other Pane requests while only one browser is visible, including keyboard or stale menu requests. Finder transfers and drops into visible panes remain in scope under their existing safeguards.
- An already submitted operation retains its captured source/destination through a layout change, following A8.

## Rationale and alternatives

Keeping the active browser preserves the selected file and avoids an unnecessary document transition. Always retaining the left browser would give a fixed pane identity, but switching while the right browser supplies a dirty document could require an extra guard. Destroying the hidden browser would lose useful navigation state. Restoring original sides could move the current single browser to the right; The design uses to keep it left and reveal the preserved browser on the right.

Continuous resizing supports intermediate widths; Expand makes the wider view accessible without dragging. A fixed 50% editor preset alone would offer fewer useful widths. Automatically expanding on Edit would move the layout during an otherwise simple document-mode change.

Remembering mode and preferred width restores the chosen working layout on relaunch. Resetting them every launch would discard that preference. Explicit New Window retains a predictable fresh layout.

## Implementation sequencing and validation

T19 is a separate M2 task after accepted/merged T07 and before M3, with independently approved Details sizing and browser-mode units. T07 retains its existing scope and acceptance gates. T17 persists the last active window’s directory pair in presentation order, browser mode, active-browser identity and preferred Details width before clamping. Restoration follows the [reopen contract](2026-10-16-window-reopen-and-relaunch-restoration.md); keep legacy directory-only preferences usable and apply safe defaults for invalid layout values. Explicit New Window starts dual/home/compact.

The [criterion matrix](../specs/001-mvp/validation.md) owns native and accessibility acceptance.

This record supersedes decision 0003’s always-dual layout. The compact default remains, with wider Details now available in either browser mode. It carries forward all remaining native appearance/Mauve, compact breadcrumb/star, focus cue, shared toolbar/menu, path-copy, highlighting and original peeking-P logo choices. The spec’s R1–R3/R8 and A27/A34/A35 own the detailed contracts; the plan maps T19 and later transfer/window/restoration checks. No layout product decisions remain open. Native coding, manual review and source-control approval gates remain separate.

## Related documents

- [MVP spec](../specs/001-mvp/spec.md)
- [Implementation plan](../specs/001-mvp/plan.md)
- [Native split validation](../validation/ui-toolbar-dividers.md)
- [Design sources](../design/001-mvp/README.md)
- [Layout design review](../validation/layout-modes-design.md)
