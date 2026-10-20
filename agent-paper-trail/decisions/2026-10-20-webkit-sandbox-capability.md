---
status: Accepted
date: 2026-10-20
supersedes:
  - 2026-10-20-production-sandbox-distribution.md
superseded_by: ""
---
# WebKit sandbox capability

## Decision and rationale

Allow WebKit's outgoing-network permission in sandbox builds so WebKit can render local SVG and static HTML. WebKit's [macOS service startup check](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/Shared/EntryPointUtilities/Cocoa/XPCService/XPCServiceEntryPoint.mm) requires this capability even for local content. The entitlement permits outgoing connections at the OS level; offline preview behaviour is enforced by renderer policies.

Carry forward the [production sandbox decision's](2026-10-20-production-sandbox-distribution.md) identity, manual setup, persistence and release gates, extending its entitlement policy only by the network-client capability. Review and production packages require exactly App Sandbox, user-selected read/write access, app-scoped bookmarks and network-client access. Debugging, incoming connections, Apple Events, broad filesystem exceptions and Hardened Runtime exceptions remain excluded.

Keep SVG in its inert image context with a data-image-only content policy. HTML requires content JavaScript disabled, a resource blocker installed before loading and a restrictive Content Security Policy before source markup. Both receive source text without the original file URL or local-file access. Only deliberate HTML HTTP/HTTPS links open externally. Keep the existing byte, size and lifecycle limits.

## Alternatives and limits

The [local HTML asset policy](2026-10-20-html-local-assets.md) governs app-mediated CSS, image and font reads; WebKit still receives no filesystem grant.

Retaining OS-level network denial prevents these WebKit-backed previews; it requires a different renderer or deferring rendered support. Deprecated WebView and broad filesystem or service exceptions are excluded. This capability does not add networking features, telemetry or app-operated services, and does not establish App Store acceptance. Production packages retain the [release gates](2026-10-20-production-sandbox-distribution.md#release-gates).
