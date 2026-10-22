---
status: Superseded
date: 2026-10-16
supersedes:
  - decisions/2026-10-11-browser-layout-modes-and-details-sizing.md
superseded_by: decisions/2026-10-22-fresh-single-pane-windows.md
---

# Window reopen and relaunch restoration

The [fresh-window decision](2026-10-22-fresh-single-pane-windows.md) replaces the fresh dual-pane default and carries forward the remaining restoration policy below.

## Decision

Restore the one remembered configuration when the app launches and when the Dock reopens it after all browser windows have closed. Preserve the record when quitting with no windows open. Explicit File → New Window remains a fresh home/home, two-pane, compact-Details window, including when no windows are open. Activating an existing or miniaturised window must not arm restoration for a later New Window.

The configuration includes the ordered directory pair, browser mode and active identity, preferred Details width, browser-divider proportions, Details expansion, window size and screen placement. Keep the preferred width separately from temporary clamping or expansion. Restore within usable native bounds when the available display arrangement changes. Continue independent unavailable-directory fallback and legacy preference defaults. Do not restore selection, sorting, hidden visibility, scroll positions or editor buffers across close/relaunch.

This record replaces the earlier layout decision's initial-window-only restoration scope. All other [layout, document-retention and sizing choices](2026-10-11-browser-layout-modes-and-details-sizing.md) carry forward unchanged. Dirty close/quit safeguards remain in force; a cancelled quit leaves the existing windows and drafts usable.

Persist Details expansion independently from its underlying preferred width. Store browser proportions by retained browser identity, capturing deliberate divider changes rather than temporary native clamping. Restore the actual window frame once at native attachment within content minimums and visible screen bounds, selecting the greatest saved-frame overlap or the nearest available screen. Explicit New Window stays compact with equal browsers and platform/default placement.

## Alternatives and rationale

Treating every later window as fresh preserves the original implementation but loses the closed working session. Restoring every New Window would violate the accepted independent-window defaults. Distinguishing Dock reopening from explicit creation restores the working session while keeping fresh creation predictable. Restoring all previous windows remains outside the single-configuration policy.

The [spec](../specs/001-mvp/spec.md) owns the complete current contract; the [criterion matrix](../specs/001-mvp/validation.md) retains acceptance limits.
