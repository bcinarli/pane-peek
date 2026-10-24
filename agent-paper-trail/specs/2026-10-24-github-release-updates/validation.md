# GitHub release updates validation

The [spec](spec.md#acceptance-criteria) owns U1–U7. All contribute to native MVP A40; earlier release waivers do not cover this work. [Task state](tasks.md) and [evidence](evidence/github-release-updates.md) distinguish design acceptance from native behaviour.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| U1 Channel and release selection | Pending | Local release selection and GitHub-review/Store packaging checked; manual and hosted acceptance pending. |
| U2 Manual dialog and reminder ownership | Pending | Native current-version popup, repeated-command reuse and themed fixture copy/help checked; Manual flow accepted; automatic banner acceptance pending. |
| U3 Download and manual-installer handoff | Pending | Local cancellation/close guards and signed-sandbox download/verification/handoff checked; local manual flow accepted; macOS 26 and hosted acceptance pending. |
| U4 Automatic reminders | Pending | Opt-in scheduling, persistence, snooze/skip and lifecycle behaviour. |
| U5 Privacy | Pending | Fixed headers observed with a native local redirect fixture; real GitHub download exercised. Disclosure publication and final acceptance pending. |
| U6 Replaceable provider | Pending | An alternate provider uses the same owner and native popup; local manual flow accepted; macOS 26 and hosted acceptance pending. |
| U7 Native accessibility | Pending | Native names/help, Macchiato/Latte and calculated palette text contrast checked. Full keyboard, VoiceOver, rendered contrast, text-enlargement and system-setting checks pending. |
