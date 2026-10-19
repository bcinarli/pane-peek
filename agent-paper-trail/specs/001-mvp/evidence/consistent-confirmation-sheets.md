---
task: consistent-confirmation-sheets
verdict: Passed
closed: 2026-10-19
---

# Consistent confirmation sheets

Unsaved-edit and transfer-collision prompts share the adaptive native sheet presentation, with Cancel leading and the Mauve default action trailing. The [decision](../../../decisions/2026-10-16-browser-ui-and-preview-improvements.md#changed-2026-10-19-consistent-confirmation-sheets) defines the action orders.

## Validation

Native prompt/lifecycle checks, full app regressions and packaging pass; agent-observed attached Light/Dark sheets have matching surfaces and horizontal actions. Tighten shares sheet presentation and removes positional alert responses; probe verifies ownership, first-answer retention and live Save/Discard/Cancel, Return/Escape, Move Keep Both and Copy Replace outcomes. Full keyboard traversal, VoiceOver, increased contrast/reduced motion and text enlargement remain pending.
