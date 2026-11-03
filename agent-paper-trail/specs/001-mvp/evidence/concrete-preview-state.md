---
task: concrete-preview-state
verdict: Passed
closed: "2026-11-02"
---

Concrete renderer ownership is accepted for the reviewed scope in [PR #167](https://github.com/bcinarli/pane-peek/pull/167), with dirty Markdown presentation/editor identity retained across listing refreshes. Matched comparisons with the pre-activation candidate improve Markdown opening by about 8 ms, while native-control Preview is about 2 ms slower and programmatic Preview about 2 ms faster; CPU/RAM remain steady and the bundle is 37,520 bytes larger than original main. Full appearance/VoiceOver/enlargement/settings and native macOS 26 checks remain unverified; app-process samples exclude unattributable WebKit workers.
