---
status: Accepted
date: 2026-11-09
supersedes: []
superseded_by: ""
---

# CLI entry point

## Context

The [CLI contract](../specs/2026-11-08-cli-support/spec.md) requires the physical caller directory, relative paths and exact app-copy targeting in both sandboxed distributions. A directly launched native sandbox executable starts in its container; inherited helper signing does not establish a Terminal execution route.

## Decision

Bundle `Contents/Resources/panepeek` as a shell entry point that captures the physical caller directory before sandbox initialisation. Forward that directory and unchanged arguments to early CLI mode in `Contents/MacOS/PanePeek`. Normal GUI launch enters the existing SwiftUI app; informational commands and CLI failures return before GUI state, favourites, restoration or updates initialise.

Keep parsing and path handling in Swift. Send destination data through a strictly decoded local URL event to the containing app with running-app substitution disabled. Reject self-handoff and validate the intended app identity; destination data grants no access. Preserve the existing capabilities and guarded browser flow.

## Alternatives and consequences

A separate Swift helper isolates CLI code but adds a target, per-distribution identity and nested signing. Shell-only `open` routing is viable, but reliable missing-versus-denied preflight depends on diagnostic parsing or a changed exit contract. Absolute-path-only native execution drops accepted current-directory and relative-path behaviour.

The shared executable keeps packaging smaller but couples CLI correctness to startup. Recheck normal launch whenever that boundary changes. Local signed prototypes support this design; actual Store export, quarantined installs, physical launch checks and production command acceptance remain in the [task evidence](../specs/2026-11-08-cli-support/evidence/cli-launcher.md).
