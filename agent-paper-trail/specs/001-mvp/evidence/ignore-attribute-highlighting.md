---
task: ignore-attribute-highlighting
verdict: Passed
closed: "2026-10-30"
---

# Ignore and attribute highlighting

The [ignore/attribute inventory](../spec.md#ignore-and-attribute-file-highlighting) is accepted for the reviewed scope against key/value baseline `e92f984`, with passing regression checks and signed-app Dark checks covering all five names and native editing/Undo/Save. Small-file highlighting/presentation is about 1–3 ms, near-900 KB ignore/attributes take 332–393 ms and the bundle grows 29 KB (0.24%); the existing near-limit insertion cost remains. Light, VoiceOver, enlarged-text/contrast and macOS 26 checks remain unverified; specialised #133 formats and [helper refactoring](https://github.com/bcinarli/pane-peek/issues/143) stay separate.
