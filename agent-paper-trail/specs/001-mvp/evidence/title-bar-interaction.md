---
task: title-bar-interaction
verdict: Pending
closed: ""
---

# Title-bar interaction

Physical dragging and native Fill pass on title text and empty centre in [#101](https://github.com/bcinarli/pane-peek/issues/101); the compact toolbar uses a bounded passive title, retains native frame painting and leaves toolbar controls operable. Edge Fill, both pane layouts and Dark keyboard smoke checks pass, alongside existing window regressions; the change is unpublished. Other double-click settings, narrow/Light layouts, full accessibility and macOS 26 acceptance remain pending, and AppKit's internal failure mechanism is unconfirmed.
