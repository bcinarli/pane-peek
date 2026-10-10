# Extended syntax highlighting

Status: Accepted scope

Date: 2026-10-10

## Context

The accepted A15 list covers Swift and ordinary web-development files. While reviewing the first native highlighting unit, Bilal requested wider support for configuration and code files. Swift/JSON Preview highlighting is implemented and awaits manual acceptance; the remaining languages are not implemented.

## Decision

Extend A15 with YAML/YML, TOML, PHP, Go, Rust and Java in both Preview and Edit. YAML/YML are filename aliases for one language. Bilal clarified that Sass meant SCSS; indented `.sass` is excluded.

The [spec](../specs/001-mvp/spec.md#details-sidebar-and-preview-editor) owns token expectations and accepted extensions. Preserve the bounded, local-only lexical presentation and plain-text fallback. Scope acceptance does not approve coding, manual results or source-control actions. T06 implements Preview support through small approved units; T07 retains it in Edit.

## Rationale and consequences

Configuration files and additional code languages can be inspected in the existing Details area without switching applications. The broader list increases fixture and native-review coverage; neither T06 nor A15 is complete after Swift/JSON alone.

Shell/Bash/Zsh, SQL, C/C++, C#, Dockerfile and Makefile are suggestions recorded in the spec, pending scope review. Their inclusion must not be inferred from this accepted extension.

## Alternatives considered

- Retain the original language list: smaller implementation scope, but omits the formats Bilal explicitly requested.
- Add every suggested format immediately: wider coverage, but would turn suggestions into unreviewed MVP requirements.

## Related documents

- [Earlier UI/highlighting direction](0003-ui-and-logo-direction.md)
- [T06 plan](../specs/001-mvp/plan.md#t06-read-only-preview-and-highlighting)
- [Current task review state](../specs/001-mvp/tasks.md)
- [Validation checklist](../validation/checklist.md)

## Subsequent review note (2026-10-10)

The context above describes the scope-extension checkpoint. Bilal subsequently accepted the Swift/JSON unit and authorised its local commit and YAML/TOML continuation. The task tracker owns current execution state; the accepted language decision is unchanged.
