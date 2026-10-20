---
status: Accepted
date: 2026-10-10
supersedes: []
superseded_by: ""
---

# Script, query and build-file highlighting

Status: Accepted

Date: 2026-10-10

## Context and decision

Shell/Bash/Zsh, SQL, C/C++, C#, Dockerfile and Makefile are included in A15 Preview and Edit. This extends [decision 0006](0006-extended-syntax-highlighting.md), preserving its accepted languages and exclusion of indented Sass.

Implement Preview support as further T06 units: Shell/Bash/Zsh, SQL, C/C++, C#, Dockerfile, then Makefile. Bilal’s request authorises the first Shell unit; retain manual review between units and separate commit/publication gates. T07 retains Edit coverage. Rendered Markdown remains a separate future proposal.

## Rationale and alternatives

These formats cover scripts, queries and build files in the existing Details preview. Keeping them suggested would omit Bilal’s requested scope. A single implementation batch would bypass the unit review workflow, so use separate visible slices. Recognition uses file extensions and explicit filenames where needed; no interpreter, database or build tool executes the previewed source.

The [spec](../specs/001-mvp/spec.md#details-sidebar-and-preview-editor) owns token expectations; the [plan](../specs/001-mvp/plan.md#t06-read-only-preview-and-highlighting) owns sequencing and the [tracker](../specs/001-mvp/tasks.md) records implementation state.
