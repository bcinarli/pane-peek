---
task: app-information
verdict: Pending
closed: ""
---

# App information and open-source documentation

The [T21 plan](../plan.md#t21-app-information-and-open-source-documentation) owns scope and review gates. Bilal accepted the five-unit plan and approved Unit 1 on 2026-10-17. Later units, commit and publication need separate approval.

## Unit 1: Licence, NOTICE and privacy

The root [LICENSE](../../../../LICENSE) uses Apache's official, unmodified 2.0 text. [NOTICE](../../../../NOTICE) identifies PanePeek, Bilal Cinarli and the original repository; separate Lucide/Feather notices are retained. [PRIVACY.md](../../../../PRIVACY.md) describes the current app rather than future About integration.

Privacy evidence: `Package.swift` has no external package dependencies; source review covers `Favourites.swift` and `WindowRestoration.swift` persistence, `PathClipboard.swift` and drag/drop pasteboards, `MarkdownPreview.swift` local rendering/link attributes, `ImagePreview.swift` decoding, `VideoPreview.swift` local-file/reference restrictions, `QuickLookPreview.swift` system file-URL handoff and `ReadOnlyPreview.swift` in-memory text/undo. The source search found no app-managed network client, telemetry, account or crash-report submission. This is source evidence, not a network-capture or OS-service audit.

- 2026-10-17: `LICENSE` matches the [official Apache download](https://www.apache.org/licenses/LICENSE-2.0.txt) byte-for-byte (11,358 bytes; SHA-256 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`). `git diff --check` and 17 added local-link/anchor checks pass; added prose has no trailing whitespace or private filesystem paths. GitHub confirms the privacy-contact repository has Issues enabled.
- Tighten then probe keeps the standard licence unmodified and NOTICE informational, distinguishes app-operated crash reporting from macOS diagnostics and makes the third-party notice filename usable in source and bundled distributions. The mapped review binding is updated. Bilal accepted the documents on 2026-10-17.
- The isolated task starts at verified merged [PR #35](https://github.com/bcinarli/pane-peek/pull/35), `b0d48b6`; a final fetch finds `HEAD` and `origin/main` equal. No commit or publication was performed. Runtime code, tooling, CI workflows and third-party notices are unchanged, so no app build/test/launch or unit-level native accessibility check was run. Future packaging and About integration remain Unit 4.

## Document review

Confirm the author/project credit in NOTICE and the file access, stored-path, clipboard and system-service descriptions in PRIVACY.md. Bilal accepted Unit 1 on 2026-10-17 and authorised its commit, merged-PR/main reconciliation and Unit 2 implementation. Push and later units remain separately gated.


## Unit 2: Version and build metadata

Bilal approved this unit on 2026-10-17. Root `version.json` now owns release `0.1.0` and build `2`; `scripts/build-app.mjs` validates both before invoking tools and writes the bundle's version/build and copyright. The build number distinguishes this review build from the former hardcoded build 1. The README describes manual increments; normal rebuilds do not bump metadata. About customisation and notice packaging remain Unit 4.

- Red: with configured build 2, the successful unchanged bundler still packaged build 1. The metadata comparison exited 1 for that mismatch. Green: the updated bundler succeeds; actual plist version/build match `version.json`, copyright is present, plist lint passes and executable/icon/catalog/third-party-licence resources remain valid. Nine temporary invalid-metadata cases (including malformed JSON, invalid version/type/newline and invalid numeric build values) fail before any build tool runs. No production test scaffolding was added for this packaging change.
- Environment: macOS 27.0.1, Xcode 27.0 (27A266a), Swift 6.4, Node 26.1.0. The bundler's existing full-Xcode fallback works with Command Line Tools selected; global selection is unchanged. This is not macOS 26 runtime evidence or a new hosted CI run.
- An isolated review bundle with a separate preferences domain and disposable document directories launches and has a matching live process. Its executable is byte-identical to the packaged build; its plist retains version 0.1.0/build 2. No native UI capture, VoiceOver or distribution-signing claim is made. Check the existing About panel's version/build/copyright and ordinary fixture browsing/editing before acceptance.

Tighten then probe keeps metadata lookup/validation in the existing bundler, with no new runtime abstraction or automatic versioning scheme. Current app-information verdicts are in [validation](../validation.md#app-information-and-repository-documentation).
