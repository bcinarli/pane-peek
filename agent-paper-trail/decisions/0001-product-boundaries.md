# Product boundaries

Status: Accepted

Date: 2026-10-02

## Context

Bilal is building PanePeek for his own local workflow. He chose macOS 26+ and accepted the product defaults during spec review. A focused feature set keeps the application practical to build and maintain.

## Decision

- Target macOS 26 and later with native macOS technologies.
- Keep connection management local-only, with no cloud accounts or remote protocols.
- Support independent panes, multiple selection, drag and drop, a Details preview/editor, file management and multiple windows.
- Copy is the default drag operation; reject filename collisions rather than overwrite or merge.
- Delete uses Trash, with no permanent-deletion fallback.
- Relaunch restores the last active window’s directory pair. Explicit New Window always opens both panes at home.

The spec owns detailed behaviour, including text limits, path semantics and open interaction proposals.

## Rationale and consequences

Supporting older macOS versions is unnecessary for the initial personal workflow. The transfer and Trash policies reduce accidental destructive actions. Restoring one directory pair serves everyday use without implementing full window/session restoration.

The application needs coordination between window-local state and shared filesystem mutations. Distribution signing and remote-service features remain outside the MVP.

## Alternatives considered

- Retain macOS 14 compatibility: dropped when Bilal selected the newer baseline.
- Restore every prior window: deferred in favour of one remembered pair and predictable home-directory defaults for new windows.
- Overwrite or merge collisions: deferred to keep the initial transfer policy explicit.

## Related documents

- [MVP spec](../specs/001-mvp/spec.md)
- [Implementation plan](../specs/001-mvp/plan.md)
