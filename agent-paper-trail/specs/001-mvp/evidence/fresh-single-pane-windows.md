---
task: fresh-single-pane-windows
verdict: Passed
closed: "2026-10-22"
---

# Fresh single-pane windows

[Issue #91](https://github.com/bcinarli/pane-peek/issues/91) changes fresh creation to One Pane with expanded Details while retaining saved layouts and legacy-record fallback. The unpublished implementation passes automated validation and native New Window, half-width expansion, Restore and saved-layout checks on macOS 27; Home loads promptly after the [recorded privacy waits](../../../notes/0004-protected-folder-permissions.md). Native Dock reopening, Light appearance, VoiceOver, enlarged text/contrast and interactive macOS 26 checks remain unverified.
