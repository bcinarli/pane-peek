---
status: Accepted
date: 2026-10-12
supersedes: []
superseded_by: ""
---

# File double-click starts inline rename

## Context and decision

Extend the [inline keyboard decision](2026-10-12-inline-rename-and-browser-keyboard.md): double-click a single non-navigable item to open the same inline editor used by Return/context/File Rename. This includes files, packages and file links. Double-click navigable folders and directory links still opens them.

Retain existing single-item targeting, dirty-document transitions, validation and focus recovery. A rejected selection change must not rename the previously selected item. This accepts the added gesture; its implementation/manual review and publication gates remain separate.

## Rationale and alternatives

Files are previewed internally, so their double-click can provide a direct pointer route to Rename. Keeping file double-click inactive leaves no equivalent direct pointer route. Launching an external application expands the MVP boundary and is not part of this change. Existing keyboard and context actions remain available.

## Related records

- [A23](../specs/001-mvp/spec.md#file-management)
- [T09 plan](../specs/001-mvp/plan.md#t09-rename-and-affected-document-handling)
- [T09 evidence](../specs/001-mvp/evidence/rename-affected-document-handling.md)
