---
status: Superseded
date: 2026-10-20
supersedes:
  - 2026-10-20-shared-sandbox-distribution.md
superseded_by: "2026-10-20-webkit-sandbox-capability.md"
---
# Production sandbox distribution

## Decision and rationale

GitHub and Mac App Store releases share sandboxed folder access and file operations. Retain production identity `com.bcinarli.PanePeek`, Home as the default permission choice and a separate sandbox review identity. GitHub keeps Developer ID signing, notarisation and DMG/ZIP downloads; Store signing, provisioning and upload remain separate.

Automatic migration from unsandboxed preferences is outside the initial sandbox distribution scope. Manual setup of favourites, remembered folders and layout is acceptable. Do not delete existing preferences or user files. Any available legacy paths are reconnection hints, never folder grants. New sandbox settings and security-scoped bookmarks must persist after relaunch.

Production packages require App Sandbox, user-selected read/write access and app-scoped bookmarks. Developer ID verification rejects missing, disabled or additional entitlements, including debugging, network and broad filesystem exceptions. Preserve Hardened Runtime, secure timestamps, strict signatures and existing notarisation gates. Ordinary development builds retain their unsandboxed mode.

## Release gates

Validate first launch and persisted access under the production identity before acceptance. Revalidate signed packages and hosted DMG/ZIP installation before publication. Build the submission candidate from current main after all intended app features merge, reserve its release metadata and repeat candidate validation. The packaging unit does not authorise a release or App Store submission.

## Alternatives and consequences

Automatic settings import adds migration code and upgrade support that the initial sandbox release does not require. Manual setup can require re-adding favourites and folder permission. Separate access models for GitHub and Store would preserve unsandboxed GitHub behaviour but require continuing validation of divergent apps. Shared sandbox behaviour keeps one access model with channel-specific signing.
