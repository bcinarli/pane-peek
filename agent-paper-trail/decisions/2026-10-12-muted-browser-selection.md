---
status: Accepted
date: 2026-10-12
supersedes: []
superseded_by: ""
---

# Muted browser selection

## Context and decision

The native file list used the global Mauve accent for selection, producing a brighter Dark highlight than the accepted draft. Bilal accepted the submitted native-table change on 2026-10-12.

Use the draft's separate muted selection role for active browser rows: `#F0E9F8` in Light and `#3B304A` in Dark. Retain Mauve controls and focus indicators. The file highlight uses this app palette even when the system accent differs; controls retain their existing system-accent handling.

Own the AppKit table and customise selection through public row drawing. Reuse the existing row content, inline editor and guarded BrowserState transitions. Keep inactive selection neutral and distinguish selection with a contrasting outline. Selected text must remain readable, including dates; increased contrast strengthens the outline.

This refines the appearance carried forward by the [layout decision](2026-10-11-browser-layout-modes-and-details-sizing.md). It does not replace the browser layout or other appearance/logo choices. The [spec](../specs/001-mvp/spec.md#accepted-ui-design) owns requirements and [unit evidence](../specs/001-mvp/evidence/muted-selection-prototype.md) owns executed checks and acceptance.

## Alternatives and rationale

Darkening the global accent is smaller but also alters native controls. A separately owned native table gives deterministic selection styling through supported APIs while retaining native selection and accessibility behaviour. Painting over SwiftUI selection or modifying its private backing views would create competing ownership and is excluded.
