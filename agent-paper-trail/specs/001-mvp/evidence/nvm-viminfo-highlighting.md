---
task: nvm-viminfo-highlighting
verdict: Passed
closed: "2026-10-30"
---

# Nvm version and Vim history highlighting

The [nvm/Vim history inventory](../spec.md#nvm-version-and-vim-history-highlighting) is accepted for the reviewed scope against ignore/attribute baseline `41d7c4e`, with passing regression and signed-app Dark checks covering both names, native editing/Undo/Save and unknown-name fallback. Small-file highlighting/presentation is about 1 ms, near-900 KB fixtures take 283–329 ms and the bundle grows 28 KB (0.23%); the existing near-limit insertion cost remains. Light, VoiceOver, enlarged-text/contrast and macOS 26 checks remain unverified; [scanner-helper refactoring](https://github.com/bcinarli/pane-peek/issues/143) stays separate.
