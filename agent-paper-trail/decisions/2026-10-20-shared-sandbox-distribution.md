---
status: Superseded
date: 2026-10-20
supersedes: []
superseded_by: 2026-10-20-production-sandbox-distribution.md
---
# Shared sandbox behaviour for distribution

## Decision and rationale

GitHub and Mac App Store releases will use the same sandboxed folder-access and file-operation behaviour. A shared access model avoids maintaining different permission and operation paths for distributed apps. The isolated sandbox review identity remains a validation tool until production migration and packaging are ready.

GitHub releases retain Developer ID signing, notarisation and DMG/ZIP downloads. The App Store retains its own signing, provisioning and submission pipeline. Sandbox acceptance alone does not establish either channel's readiness.

## Readiness requirements

Migration from existing unsandboxed GitHub installations must cover settings, favourites and remembered folders. Legacy paths cannot grant sandbox access; retain them as reconnection hints and request folder selection where needed. Verify existing and fresh installations, relaunch persistence and channel coexistence before switching production releases. Preserve existing published downloads and production identity unless a separately reviewed migration requires otherwise.

## Alternatives and consequence

Separate sandboxed Store and unsandboxed GitHub apps would preserve the current GitHub access model but require continuing validation of divergent behaviour. The shared model requires a migration and renewed signed-package, notarisation and installation checks. Implementation and publication retain their atomic review gates; the [distribution plan](../specs/001-mvp/plan.md#shared-sandbox-distribution-readiness) owns the remaining work.
