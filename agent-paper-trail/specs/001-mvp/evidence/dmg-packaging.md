---
task: dmg-packaging
verdict: Pending
closed: ""
---

# DMG packaging

The [plan](../plan.md#dmg-packaging) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns acceptance and publication state.

## Executed checks

2026-10-19, macOS 27.0.1 arm64, Xcode 27/Swift 6.4, Node.js 26.1.0:

- All 86 tooling tests and 595 parallel release tests pass. DMG ticket/resume and output-gating regressions pass; the output-rejection case has observed intentional red/green evidence. Unsafe app links, wrong Applications destinations and failed inspection detach only the owned device. The real unsigned release bundler produces both formats and matching workflow outputs.
- The local DMG wraps the unchanged 1.0.0 (5) app from the [verified hosted candidate](https://github.com/bcinarli/pane-peek/actions/runs/39295372972). App source/resources/metadata match main base `0c770c7`. Actual Developer ID signing/timestamp, Accepted notarisation with a matching clean container log/ticket, stapling and Gatekeeper checks pass. Resume retains the same receipt and upload.
- Independent read-only mounting confirms the UDZO volume, exact Applications link, fixed Finder layout, portable background bookmark and 1×/2× artwork. All 12 app files and permissions match the source, ZIP extraction and copy from the mounted image. The copied app launches from its verified review location. Both copied/extracted app signatures, Hardened Runtime, timestamp, absence of entitlements, stapled tickets, arm64/macOS 26 metadata and maintained notices/resources pass.
- Finder displays the clean Macchiato app/arrow/Applications layout with no instruction text. Native accessibility exposes both file names; keyboard selection moves from the app to Applications. System appearance/preferences are unchanged. Normally hidden metadata is positioned below the initial viewport.
- Both download checksums, the exact DMG/ZIP/checksums/notes allowlist and app-only notes pass. Container metadata has no detected private home/cache paths or credential material. Proposed-file privacy scan: zero findings; the native Finder screenshot is visually reviewed for private content. Workflow YAML/shell syntax, 534 local links, SVG syntax and diff whitespace checks pass. Tighten followed by probe is complete.

Current local DMG SHA-256: `23308f76bdfdf363e928d341a55aa60127475b39f20c7da8f423f99c784e681c`.

## Limits

VoiceOver, Light appearance and other accessibility settings are unreported; native AX/keyboard checks do not establish the app-wide accessibility audit. The updated hosted workflow has not run. Actual browser quarantine installation, public download access and publication retain separate gates. No tag or public release is created.
