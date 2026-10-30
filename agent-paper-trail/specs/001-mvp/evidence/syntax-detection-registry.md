---
task: syntax-detection-registry
verdict: Passed
closed: "2026-10-29"
---

# Syntax detection and registry

The reviewed foundation in [PR #145](https://github.com/bcinarli/pane-peek/pull/145), originally committed as `550b78b`, is accepted: registry-based format selection is separate from existing lexical highlighters and retained through typing and Preview/Edit. Regression checks and signed sandbox Dark-mode editing/Save checks pass; same-configuration native measurements remain comparable and bundle size rises by about 32 KB (0.27%), while existing near-limit editing costs remain. Light appearance, VoiceOver, enlarged text/contrast and macOS 26 remain unverified; broader A15 acceptance and [further coverage](https://github.com/bcinarli/pane-peek/issues/144) retain separate scope.
