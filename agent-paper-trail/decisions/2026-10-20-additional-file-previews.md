---
status: Accepted
date: 2026-10-20
supersedes: []
superseded_by: ""
---

# Additional file previews

## Decision

Extend Details with highlighted Markdown YAML front matter, SVG rendering and source editing, read-only PDF rendering, then static offline HTML rendering, in that order. The [specification](../specs/001-mvp/spec.md#additional-file-previews) owns behaviour and limits; the [plan](../specs/001-mvp/plan.md#additional-file-previews) owns separately reviewed units.

Keep rendered Markdown in the existing native text presentation. Reuse lexical YAML/XML highlighting and the guarded text editor rather than introducing metadata conversion or a second editing lifecycle. SVG editing is source editing only.

Use native PDF rendering and prefer native static SVG decoding. HTML requires a web renderer with content JavaScript and automatic remote resource loads disabled. Keep the first HTML scope self-contained; loading related files from a directory requires a separately reviewed access policy.

## Rationale and limits

These additions extend local document inspection while preserving draft identity, safe saving and the local-only boundary. Lexical front-matter highlighting needs no YAML parser or reserialisation. Native preview facilities avoid a new document engine, but format fidelity, resource limits and unavailable states still need validation on supported macOS versions.

Graphical SVG editing, PDF editing, script-driven HTML and automatic external resource loading are excluded. New scope is not covered by the 1.0.0 acceptance waivers.

## Alternatives

- Retain source-only previews and system Quick Look: less inline functionality, with the existing system preview boundary.
- Use WebKit for all rendered formats: broader web support, with unnecessary resource and navigation policy for native Markdown/PDF and ordinary SVGs.

## Related records

- [Rendered Markdown limitations](../notes/0006-rendered-markdown-preview.md)
- [Preview and editor contract](../specs/001-mvp/spec.md#details-sidebar-and-preview-editor)
