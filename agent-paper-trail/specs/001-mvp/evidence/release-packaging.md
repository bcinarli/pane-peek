---
task: release-packaging
verdict: Passed
closed: "2026-10-18"
---

# Local release packaging

The [plan](../plan.md#local-release-packaging) owns scope and validation; the [task row](../tasks.md#build-and-repository-automation) owns review state. Signing, notarisation, uploads and publication remain separate.

## Executed checks

- 2026-10-18, macOS 27.0.1 arm64, Xcode 27.0 / Swift 6.4, Node.js 26.1.0: the pre-change `--release` command builds for debugging and creates no release archive. After implementation, the default command still builds the development app; `node scripts/build-app.mjs --release` builds for production with explicit arm64 selection. Both packaging builds complete without compiler diagnostics. Thirteen invalid-argument/metadata checks reject before creating build output.
- 2026-10-18: ZIP/checksum and extraction checks pass for version 0.1.0, build 3, minimum macOS 26.0. All ten bundle files retain identical bytes and modes after extraction, including the executable, plist, compiled assets, icon and original/offline notices. The final ZIP is 2,106,980 bytes. A second run uses a different output directory, excludes a stale-file fixture from the earlier bundle and leaves every development-bundle file unchanged.
- 2026-10-18: all 42 existing tooling tests pass. The first full release-suite run hits the previously recorded `missingReadsOrReleaseReportsTimeout` assertion; it passes in isolation, then the complete unchanged release rerun passes all 573 functions (111 app and 462 core) with nine expected known issues. Initial compilation reports three unused-expression warnings in existing rename tests; application builds have no diagnostics. No tests were changed or skipped.
- 2026-10-18, agent-observed native launch: a copy of the extracted app uses a separate review bundle identifier and disposable sample directories; its executable is byte-identical to the archive. Native accessibility inspection confirms the running window, both sample listings and normal toolbar/Details roles. The native read substantially exceeds its requested timeout; preview interaction and keyboard/VoiceOver outcomes remain unverified.

## Review and limits

Check About shows version 0.1.0 (3), select the sample Markdown file and inspect its preview, then open the bundled Privacy and Acknowledgements. Review the ZIP/checksum and contributor instructions. Bilal accepted the presented packaging unit overall on 2026-10-18. Individual About/preview/notices and keyboard/VoiceOver outcomes were not separately reported; signing, public distribution and app-wide acceptance remain outside this verdict.

Tighten keeps one bundler and the existing metadata/deployment owners. Probe checks archive fidelity, invalid inputs, repeated-run isolation and release optimisation. No UI changes, app-wide accessibility pass, macOS 26 runtime check, Developer ID signature, notarisation or real browser-download/Gatekeeper result is claimed. The existing restoration self-test remains intermittent.
