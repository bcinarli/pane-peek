---
task: github-1-2-candidate
verdict: Waived
closed: "2026-10-26"
---

# GitHub 1.2 candidate

The signed and notarised PanePeek 1.2.0 (10) candidate from [`3dfa4fb`](https://github.com/bcinarli/pane-peek/commit/3dfa4fbb6181a1dfaae0ad4744df2c4e42fbf134) passes downloaded DMG/ZIP integrity, metadata/notices, production signature, Hardened Runtime, exact sandbox, stapled-ticket and Gatekeeper checks; both formats contain the same app and the DMG retains its verified Finder layout. Reported functional smoke review passes on macOS 26, and scoped macOS 27 native checks cover the current-version dialog, Light/Dark appearance, keyboard/VoiceOver and platform display scaling; [PR #124](https://github.com/bcinarli/pane-peek/pull/124) owns metadata and Unreleased notes. The [1.2 release waiver](../../../decisions/2026-10-26-1-2-release-acceptance-waivers.md) accepts remaining unverified coverage; public release and published-download verification remain pending.
