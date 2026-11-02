---
task: preview-host-boundary
verdict: Passed
closed: "2026-11-02"
---

BuiltInPreviewHost now assembles existing previews through PreviewRoute, retaining document/media owners and exercised editor, Find, Copy, metadata and cleanup behaviour; publication is pending. Automated and exercised native checks pass, and matched comparisons show stable opening/mode switching, a 116,304-byte smaller bundle and small app-process CPU/RAM changes; the initial harness RAM increase did not reproduce in the final alternating-binary comparison. Full appearance/VoiceOver/enlargement/settings and native macOS 26 checks remain unverified; memory samples exclude unattributable WebKit workers.
