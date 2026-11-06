---
status: Accepted
date: 2026-11-05
---

# Prerelease identity in About

The published `v1.3.0-beta.1` shows `Version 1.3.0 (11)` in About. Subsequent candidates use the [About suffix contract](README.md#candidate-identity) so testers can identify the installed candidate. The published beta remains immutable.

## Display draft

Use the existing selectable version line directly below the app name. These values illustrate the format.

| Build | About version line |
| --- | --- |
| Beta | `Version 1.3.0-beta.2 (12)` |
| Release candidate | `Version 1.3.0-rc.1 (13)` |
| Stable, App Store or ordinary local build | `Version 1.3.0 (14)` |

An explicitly prepared local beta or RC review package displays the same suffix as the equivalent hosted candidate. About uses its ordinary version display when the suffix is absent or invalid, or when the numeric version is unavailable.

The [About coding unit](README.md#about-candidate-label) owns packaging and native review.
