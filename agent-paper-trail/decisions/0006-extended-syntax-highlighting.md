---
status: Accepted
date: 2026-10-10
supersedes: []
superseded_by: ""
---

# Extended syntax highlighting

## Decision and rationale

YAML/YML, TOML, PHP, Go, Rust and Java are included in Preview and Edit alongside the other [A15 languages](../specs/001-mvp/spec.md#details-sidebar-and-preview-editor). YAML/YML are aliases; SCSS is included and indented `.sass` is excluded. Lexical highlighting remains bounded and local, with plain-text fallback and no code execution or language-server integration.

Configuration and code files share the existing Details surface. A smaller language list reduces implementation scope but omits supported everyday formats. [Decision 0007](0007-script-query-and-build-highlighting.md) owns script, query and build-file extensions; the [task tracker](../specs/001-mvp/tasks.md) owns current acceptance.
