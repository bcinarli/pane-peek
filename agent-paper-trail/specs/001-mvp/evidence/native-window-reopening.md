---
task: native-window-reopening
verdict: Passed
closed: 2026-11-04
---

# Native window reopening

The [closed-guard correction](https://github.com/bcinarli/pane-peek/commit/f9fceb818ea74c4bd2901a44e18ce516aaa5e1a5) preserves repeated restoration, fresh New Window defaults, quit/relaunch and dirty-draft guards. Full-suite and signed native checks pass, and the reviewed Dock reopening and window-geometry scope is accepted.

VoiceOver, Light appearance, macOS 26 and broader display-configuration checks remain unverified.
