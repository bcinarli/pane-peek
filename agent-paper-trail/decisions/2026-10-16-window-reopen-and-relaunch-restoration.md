---
status: Accepted
date: 2026-10-16
supersedes:
  - decisions/2026-10-11-browser-layout-modes-and-details-sizing.md
superseded_by: ""
---

# Window reopen and relaunch restoration

## Context

Bilal clarified that remembering the working layout covers both closing the final window with X and reopening from the Dock, and quitting with Command-Q and launching again. The earlier T17 scope restored only the initial launch window, excluded browser-divider proportions and expanded Details, and did not record window geometry. Bilal approved this corrected scope and the first implementation unit on 2026-10-16.

## Decision

Restore the one remembered configuration when the app launches and when the Dock reopens it after all browser windows have closed. Preserve the record when quitting with no windows open. Explicit File → New Window remains a fresh home/home, two-pane, compact-Details window, including when no windows are open. Activating an existing or miniaturised window must not arm restoration for a later New Window.

The configuration includes the ordered directory pair, browser mode and active identity, preferred Details width, browser-divider proportions, Details expansion, window size and screen placement. Keep the preferred width separately from temporary clamping or expansion. Restore within usable native bounds when the available display arrangement changes. Continue independent unavailable-directory fallback and legacy preference defaults. Do not restore selection, sorting, hidden visibility, scroll positions or editor buffers across close/relaunch.

This record replaces the earlier layout decision's initial-window-only restoration scope. All other [layout, document-retention and sizing choices](2026-10-11-browser-layout-modes-and-details-sizing.md) carry forward unchanged. Dirty close/quit safeguards remain in force; a cancelled quit leaves the existing windows and drafts usable.

## Alternatives and rationale

Treating every later window as fresh preserves the original implementation but loses the closed working session. Restoring every New Window would violate the accepted independent-window defaults. Distinguishing Dock reopening from explicit creation restores the working session while keeping fresh creation predictable. Restoring all previous windows remains outside the single-configuration policy.

## Sequencing and validation

[T17's correction plan](../specs/001-mvp/plan.md#t17-restore-the-remembered-directory-pair) separates the lifecycle correction from the added sizing/geometry fields. Unit 1 covers the existing directory/mode/active/preferred-width snapshot through both reopen paths. Unit 2 adds the remaining layout fields and needs its own coding approval. Each unit requires automated evidence and native/manual review; record partial acceptance under A27.

### [Changed] 2026-10-16: focused expansion slice

After accepting lifecycle Unit 1, Bilal approved remembering expanded Details as a separate small unit. Split the sizing/geometry work into Unit 2a for expansion and Unit 2b for browser proportions and window geometry. Persist expansion independently from the underlying preferred width so Restore Previous Width remains useful. Explicit New Window stays compact. Unit 2b retains a separate coding approval gate.

### [Changed] 2026-10-16: proportions and frame ownership

Bilal accepted Unit 2a and approved Unit 2b. Store browser proportions by retained browser identity, rather than by temporary visible side, so mode/order changes retain each browser's requested share. Capture only deliberate divider changes; native clamping does not replace that preference. Store the actual native window frame in the same one-window configuration. Restore once at native attachment and fit it into available screen-visible bounds with native content minimums. Select the screen with greatest saved-frame overlap, or the nearest when the previous screen is unavailable. Explicit New Window keeps equal browsers and platform/default placement. Existing last-active ownership and dirty-buffer safeguards remain unchanged.
