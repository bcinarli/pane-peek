# Swift package application foundation

Status: Accepted

Date: 2026-10-03

## Context

T01 needs a native shell that can be built and launched locally. The spec prefers a Swift package with a small bundling script, with an Xcode app project as the fallback for a concrete lifecycle or packaging limitation. Bilal approved this foundation with T01 Unit 1.

## Decision

- Use a Swift package executable and a SwiftUI application entry point.
- Bundle the executable locally with a Node script using only built-in libraries. Read the bundle's minimum macOS version from the package manifest so the deployment requirement has one owner.
- Start with a single window and static pane/sidebar areas. Introduce the core and behaviour tests with actual filesystem/document work; independent windows remain in T16.

## Rationale and consequences

The shell builds with Command Line Tools and launches as a local app bundle. Native close/reopen and quit/relaunch checks pass; no full Xcode requirement has emerged for this unit. Manual task acceptance remains pending in the [validation record](../validation/t01-launchable-shell.md).

The bundle is for local development outside the App Sandbox. Distribution signing and notarisation remain deferred. Revisit the foundation through review if a later native integration exposes a concrete limitation.

## Alternatives considered

- Xcode app project: conventional bundle/signing support, with additional project configuration and a full Xcode requirement.
- Generate an empty core and test target immediately: deferred until there is meaningful behaviour to protect.

## References

- [MVP architecture](../specs/001-mvp/spec.md#proposed-architecture)
- [SwiftUI Window scene](https://developer.apple.com/documentation/swiftui/window)
- [Swift package manifest API](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)

## Acceptance update: 2026-10-04

Bilal accepted the current T01 shell and development icon after Unit 2. The [validation record](../validation/t01-launchable-shell.md) retains unverified per-check outcomes. This satisfies the task's overall manual acceptance; publication and subsequent coding gates remain separate.
