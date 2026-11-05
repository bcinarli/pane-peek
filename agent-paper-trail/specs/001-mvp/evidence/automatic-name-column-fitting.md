---
task: automatic-name-column-fitting
verdict: Passed
closed: "2026-11-05"
---

# Automatic Name column fitting

The viewport fitting and Modified resize gutter in [PR #177](https://github.com/bcinarli/pane-peek/pull/177) are accepted for the reviewed [#135](https://github.com/bcinarli/pane-peek/issues/135) scope. Manual Name overrides and browser-local metadata widths are preserved; the 8 pt gutter remains available at the horizontal scroll limit, with focused checks and the certificate-signed sandbox build passing on macOS 27. The full native run’s sandbox-video readiness timeout also reproduces on unchanged main.

Complete physical divider/header-drag coverage, live multi-window isolation, Light appearance, actual VoiceOver, system text enlargement and macOS 26 validation remain unverified.
