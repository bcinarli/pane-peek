---
task: dmg-packaging
verdict: Passed
closed: "2026-10-19"
---

# DMG packaging

The [plan](../plan.md#dmg-packaging) owns scope; the [task tracker](../tasks.md#build-and-repository-automation) owns acceptance and publication state.

## Executed checks

2026-10-19, macOS 27.0.1 arm64, Xcode 27/Swift 6.4, Node.js 26.1.0:

- All 86 tooling tests and 595 parallel release tests pass. DMG ticket/resume and output-gating regressions pass; the output-rejection case has observed intentional red/green evidence. Unsafe app links, wrong Applications destinations and failed inspection detach only the owned device. The real unsigned release bundler produces both formats and matching workflow outputs.
- The local DMG contains the 1.0.0 (5) app and maintained resources. Actual Developer ID signing/timestamp, Accepted notarisation with a matching clean container log/ticket, stapling and Gatekeeper checks pass. Resume retains the same receipt and upload.
- Independent read-only mounting confirms the UDZO volume, exact Applications link, fixed Finder layout, portable background bookmark and 1×/2× artwork. All 12 app files and permissions match the source, ZIP extraction and copy from the mounted image. The copied app launches from its verified review location. Both copied/extracted app signatures, Hardened Runtime, timestamp, absence of entitlements, stapled tickets, arm64/macOS 26 metadata and maintained notices/resources pass.
- Finder displays the clean Macchiato app/arrow/Applications layout with no instruction text. Native accessibility exposes both file names; keyboard selection moves from the app to Applications. System appearance/preferences are unchanged. Normally hidden metadata is positioned below the initial viewport.
- Both download checksums, the exact DMG/ZIP/checksums/notes allowlist and app-only notes pass. Container metadata has no detected private home/cache paths or credential material. Proposed-file privacy scan: zero findings; the native Finder screenshot is visually reviewed for private content. Workflow YAML/shell syntax, 534 local links, SVG syntax and diff whitespace checks pass. Tighten followed by probe is complete.

## Hosted execution and downloads

2026-10-19: [PR #59](https://github.com/bcinarli/pane-peek/pull/59) is merged with passing required checks. The exact merged source `05c01efc2d3961034a6886c593856106fba9c5c9` passes both main workflows and [hosted release preparation](https://github.com/bcinarli/pane-peek/actions/runs/39306042099), including release tests, app/DMG signing and notarisation, cleanup and upload. Required job steps and logs are inspected; credential cleanup passes.

Independent authenticated download of artifact `12214530255` verifies GitHub's digest, the exact DMG/ZIP/checksums/notes allowlist and both final checksums. On macOS 27, native checks verify the selected Developer ID certificate, runtime/timestamp/absence of entitlements, container signature, both stapled tickets and Gatekeeper. Read-only mounting confirms the same 12 app files/modes as ZIP extraction, the Applications shortcut, portable background bookmark and 1×/2× artwork. Metadata/resources and source/app-only notes pass for 1.0.0 (5), arm64, macOS 26+. Both downloaded app copies launch from their verified paths. Actual Finder appearance, native names and keyboard selection pass.

| Verified download | SHA-256 |
| --- | --- |
| GitHub artifact | `7e9d4a23ecea36b291b9ed168af6836732e97ec71102b662f50c92b3d5f0c409` |
| DMG | `3405d661b6fb7994f7a0484933cd3b0e910fa67ec05ef5bfb569a2ce9aa38cb1` |
| ZIP | `40be7c33e383bf84ed0416025c314ccac068bebe2a2c2d0717d4ad438a60b4c9` |

## Limits

VoiceOver, Light appearance and other accessibility settings are unreported; native AX/keyboard checks do not establish the app-wide accessibility audit. The authenticated API downloads have no quarantine attribute. Actual browser quarantine installation, public download access and publication retain separate gates. No tag or public release is created.
