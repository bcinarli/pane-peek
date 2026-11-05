---
task: browser-column-width-restoration
verdict: Passed
closed: "2026-11-05"
---

# Browser column width restoration

[#163](https://github.com/bcinarli/pane-peek/issues/163) is accepted for the reviewed scope. The certificate-signed sandbox app restored all three manually entered widths after quit and relaunch on macOS 27. Native tests pass for both browser identities, repeated close/reopen, automatic Name fitting, invalid-width fallback, fresh New Window defaults and Restore Defaults. The full run retains the sandbox-video readiness timeout also reproduced on unchanged main. Physical header dragging, live Dock reopening, broader keyboard and appearance checks, VoiceOver, system text enlargement and macOS 26 remain pending.
