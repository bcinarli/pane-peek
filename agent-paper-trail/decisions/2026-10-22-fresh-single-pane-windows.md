---
status: Superseded
date: 2026-10-22
supersedes:
  - decisions/2026-10-16-window-reopen-and-relaunch-restoration.md
superseded_by: decisions/2026-10-22-expanded-details-in-fresh-windows.md
---

# Fresh single-pane windows

The [expanded-Details decision](2026-10-22-expanded-details-in-fresh-windows.md) replaces the compact fresh default and carries forward the remaining policy below.

## Decision

With no remembered configuration, launch with One Pane and compact Details. Explicit File → New Window uses the same fresh layout and Home/Home directory defaults, including when no browser windows remain open. Both browser identities remain retained.

Restore the saved One Pane or Two Panes mode on launch and Dock reopening. Existing records with missing or invalid mode fields retain their two-pane fallback and usable directories. Do not reset or migrate saved configurations merely to apply the new fresh default.

This replaces the fresh dual-pane default in the [previous restoration decision](2026-10-16-window-reopen-and-relaunch-restoration.md) and its carried-forward layout policy. All other restoration, sizing, window-independence and dirty-document safeguards from that decision remain binding.

## Rationale and alternatives

One Pane gives a fresh window more browsing space while preserving the option to show the retained second browser. Applying One Pane to every launch would discard a chosen working layout. Changing the fallback for older saved records would also alter existing layouts without a deliberate choice, so retain that compatibility behaviour.

The [spec](../specs/001-mvp/spec.md#multiple-windows-and-remembered-directories) owns the current contract. [Issue #91](https://github.com/bcinarli/pane-peek/issues/91) tracks implementation and acceptance.
