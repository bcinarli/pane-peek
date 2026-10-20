---
status: Accepted
date: 2026-10-11
supersedes: []
superseded_by: ""
---

# Name grouping and global Modified ordering

## Context

Global Modified ordering keeps file and directory dates comparable without separate category groups. The [spec](../specs/001-mvp/spec.md) owns the current comparator contract.

## Decision and rationale

Name keeps folders first and applies its selected direction within each group. Modified sorts files and folders together by actual timestamp; ties use ascending natural name and stable path ordering. Unknown dates remain globally last in either date direction. Sorting preserves selected URL identities and pane independence.

This makes Modified useful for recency without removing familiar Name grouping. Kind grouping is deferred. [A30](../specs/001-mvp/spec.md#breadcrumbs-and-sorting) owns the detailed contract.

## Alternatives considered

- Group folders first for both fields: superseded within the T03 requirement review because date groups obscured chronology.
- Add a grouping preference: deferred to keep the current behaviour simple.

## Consequences

Sorting uses actual values rather than labels and runs away from the UI thread. Date-label updates must not reread or reorder the directory. Task and criterion acceptance remain in their own records.
