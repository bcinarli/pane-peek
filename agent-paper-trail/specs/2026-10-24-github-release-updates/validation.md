# GitHub release updates validation

The [spec](spec.md#acceptance-criteria) owns U1–U7. All contribute to native MVP A40; the 1.0.0 waiver does not cover this work. The [1.2 release waiver](../../decisions/2026-10-26-1-2-release-acceptance-waivers.md) accepts remaining unverified coverage only for 1.2.0 (10), without turning Pending coverage into Passed results. [Task state](tasks.md) and [evidence](evidence/github-release-updates.md) retain the deferred scope.

| Criterion | Verdict | Evidence / remaining scope |
| --- | --- | --- |
| U1 Channel and release selection | Pending | Local GitHub-review/Store isolation and selection checked; native macOS 26 acceptance pending. |
| U2 Manual dialog and reminder ownership | Passed | Manual flow and automatic popup review accepted; shared window, copy/help, manual result reuse and editor focus/draft retention verified. |
| U3 Download and manual-installer handoff | Pending | Real redirected download, digest/quarantine/publisher validation and native system handoff pass in a signed macOS 27 sandbox fixture; complete macOS 26 acceptance remains unverified. |
| U4 Automatic reminders | Pending | Daily reminder flow and local preferences checked; automatic popup review accepted. Native macOS 26 lifecycle verification remains pending. |
| U5 Privacy | Passed | Fixed native check/redirect headers verified; unchanged production transport exercised by a real download. Bundled and live disclosures cover the actual hosts, default-off checks and connection metadata. |
| U6 Replaceable provider | Pending | An alternate provider exercises manual and automatic flows through the same boundary; native macOS 26 acceptance pending. |
| U7 Native accessibility | Pending | Current-result dialog Light/Dark rendering, normal-text colour pairs, Return, VoiceOver speech/navigation and Increase Contrast/Reduce Motion checked on macOS 27; full app-wide, available/error-state and macOS 26 accessibility coverage remains unverified. |
