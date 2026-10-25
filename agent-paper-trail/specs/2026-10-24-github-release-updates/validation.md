# GitHub release updates validation

The [spec](spec.md#acceptance-criteria) owns U1–U7. All contribute to native MVP A40; earlier release waivers do not cover this work. [Task state](tasks.md) and [evidence](evidence/github-release-updates.md) distinguish design acceptance from native behaviour.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| U1 Channel and release selection | Pending | Local GitHub-review/Store isolation and selection checked; native macOS 26 acceptance pending. |
| U2 Manual dialog and reminder ownership | Passed | Manual flow and automatic popup review accepted; shared window, copy/help, manual result reuse and editor focus/draft retention verified. |
| U3 Download and manual-installer handoff | Pending | Local manual flow accepted; native macOS 26 acceptance pending. |
| U4 Automatic reminders | Pending | Daily reminder flow and local preferences checked; automatic popup review accepted. Native macOS 26 lifecycle verification remains pending. |
| U5 Privacy | Pending | Native fixed-header boundary checked; local opt-in/preferences disclosures updated. Publication and final acceptance pending. |
| U6 Replaceable provider | Pending | An alternate provider exercises manual and automatic flows through the same boundary; native macOS 26 acceptance pending. |
| U7 Native accessibility | Pending | Shared popup names/help, themed controls and editor Return checked. Full VoiceOver, rendered contrast, text-enlargement and system-setting checks pending. |
