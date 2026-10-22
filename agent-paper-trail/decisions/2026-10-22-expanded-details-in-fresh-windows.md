---
status: Accepted
date: 2026-10-22
supersedes:
  - decisions/2026-10-22-fresh-single-pane-windows.md
superseded_by: ""
---

# Expanded Details in fresh windows

## Decision

Fresh launch without a remembered configuration and explicit File → New Window start with One Pane and expanded Details. Expansion uses the existing half-width maximum, subject to browser minimums and divider bounds. Retain the compact preferred width underneath expansion so Restore returns to the compact layout.

Saved windows restore their chosen browser mode, Details width and expansion. Existing records with missing or invalid expansion fields remain unexpanded; do not reset or migrate preferences.

This replaces the compact fresh default in the [single-pane decision](2026-10-22-fresh-single-pane-windows.md). Its Home/Home defaults, retained browser identities, saved-mode compatibility and carried-forward restoration safeguards remain binding. The larger single-pane width limit in [#95](https://github.com/bcinarli/pane-peek/issues/95) remains separate.

## Rationale and alternatives

Expanded Details gives preview/editing space immediately in a fresh window. Keeping the compact default would require expansion each time. Applying expansion to restored windows would override the saved working layout, so restrict the new default to fresh creation.

The [spec](../specs/001-mvp/spec.md#browser-layout-modes-and-details-sizing) owns sizing behaviour; [#91](https://github.com/bcinarli/pane-peek/issues/91) tracks the current unit's acceptance.
