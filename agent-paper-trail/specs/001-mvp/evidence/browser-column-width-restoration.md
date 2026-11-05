---
task: browser-column-width-restoration
verdict: Passed
closed: "2026-11-05"
---

# Browser column width restoration

[PR #178](https://github.com/bcinarli/pane-peek/pull/178) restores preferred column widths for both browsers, with the reviewed scope accepted. The signed macOS 27 app restored manually entered widths after relaunch, and native restoration tests pass. The full local suite retains the video readiness timeout also reproduced on unchanged main. Physical header dragging, live Dock reopening, broader appearance and keyboard checks, VoiceOver, system text enlargement and macOS 26 remain unverified.
