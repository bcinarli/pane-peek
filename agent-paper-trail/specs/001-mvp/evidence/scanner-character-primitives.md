---
task: scanner-character-primitives
verdict: Passed
closed: "2026-10-30"
---

# Scanner character and prefix primitives

Shared prefix, ASCII digit/hex and distinct spacing/newline primitives in [#143](https://github.com/bcinarli/pane-peek/issues/143) preserve the expanded scanners’ format-specific behaviour; regression and signed sandbox-build checks pass. Before/after comparisons show comparable responsiveness and a smaller bundle without new dependencies, and Dark Preview/Edit, Unicode selection, typing, Undo/Redo, Save and BOM/CRLF checks pass. The reviewed unit is accepted; broader Light/VoiceOver/enlarged-text/contrast/macOS 26 checks remain unverified, and an intermittent video-readiness failure also reproduced on the accepted baseline remains undiagnosed.
