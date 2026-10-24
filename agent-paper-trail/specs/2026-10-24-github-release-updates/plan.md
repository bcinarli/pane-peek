# GitHub release updates implementation plan

Status: Active

The [spec](spec.md) owns behaviour and limits; [tasks](tasks.md) owns implementation/manual-review state; [validation](validation.md) owns acceptance. The [shared checklist](../../validation/checklist.md) defines unit review and separate publication gates.

## Integration

One app-wide owner coordinates provider-independent state, local preferences and a single operation. The native Updates window serves both explicit checks and automatic reminders. Browser/editor state remains independent of update presentation and storage.

The composition root selects the provider once. The GitHub adapter owns release selection, transport, bounded storage, artifact validation and macOS handoff. Future providers use the same boundary; dependencies, packaging and signing remain provider-specific work. No runtime plugin registry is included.

| Surface | Responsibility |
| --- | --- |
| App commands and lifecycle | Opt-in preference, shared owner/window and launch/activation/wake scheduling. |
| Native Updates window | Explicit check outcomes, automatic available-only reminders and requested download actions. |
| Provider adapter | Release eligibility, fixed-metadata requests, validated downloads and manual-installer handoff. |
| Channel packaging | Positive GitHub capability and Store exclusion. |
| Privacy disclosures | Actual check/download hosts, local preferences and unavoidable connection metadata. |

## Review units

| Unit | Scope | Acceptance boundary |
| --- | --- | --- |
| 1: Manual updates | Manual checking, requested DMG download and system handoff through the replaceable provider. | Native flow, privacy, artifact validation and GitHub/Store isolation. |
| 2: Automatic reminders | Opt-in daily checking and local Later/Skip choices in the shared window. Depends on the manual flow. | Quiet outcomes, scheduling, cancellation/manual takeover, editor focus and native accessibility. |

## Validation and release gates

Meaningful behaviour requires red/green coverage and native seam verification, including real requests, sandbox handoff and channel packaging. Simulated design checks do not establish runtime acceptance. Signed-app review and affected accessibility checks remain separate from automated results; [validation](validation.md) records unverified scope.

Preserve the existing sandbox capabilities, offline previews, guarded quitting and release metadata owners. Signing/notarisation, release allocation, website publication and App Store submission retain their own gates. [Task evidence](evidence/github-release-updates.md) records current outcomes and material limits.
