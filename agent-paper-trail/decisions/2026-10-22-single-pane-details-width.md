---
status: Accepted
date: 2026-10-22
supersedes:
  - decisions/2026-10-22-expanded-details-in-fresh-windows.md
superseded_by: ""
---

# Single-pane Details width

## Decision

Details can use up to 66% of the window content width in One Pane and 50% in Two Panes, further limited by visible browser minimum widths and dividers. Divider dragging, keyboard adjustment and Expand use the same bounds. Expand requests the current mode's maximum; Restore returns to the preferred width retained before expansion. Temporary clamping during resizing or mode changes preserves that preference.

Fresh launch without a remembered configuration and explicit New Window use Home/Home, One Pane and expanded Details, retaining the compact preferred width for Restore. Saved configurations restore their browser mode, preferred width and expansion; missing or invalid expansion in an existing record remains unexpanded. Existing restoration, browser identity and editor-state safeguards remain binding under [A26/A27](../specs/001-mvp/spec.md#multiple-windows-and-remembered-directories) and [A34/A35](../specs/001-mvp/spec.md#browser-layout-modes-and-details-sizing).

## Rationale

The single-pane limit balances preview/editing space with readable file and folder names. The 50% dual-pane limit retains space for both browsers. A uniform 50% cap restricts single-pane previews; a uniform 66% cap reduces space available to two browsers.

Related: [#95](https://github.com/bcinarli/pane-peek/issues/95).
