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
