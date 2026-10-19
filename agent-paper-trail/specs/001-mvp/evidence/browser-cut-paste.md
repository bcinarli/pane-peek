---
task: browser-cut-paste
verdict: Passed
closed: "2026-10-19"
---

# Browser Cut and Paste

- 2026-10-19: Xcode-selected `node scripts/test.mjs --filter BrowserFileCommandsTests` intentionally fails the seven new parameterised Cut cases because `DirectoryTableView` does not yet implement `cut:`. The seven existing functions pass. Checks use unique pasteboards and temporary files on macOS 27.0.1.
- 2026-10-19: Clipboard regressions pass after implementation; the final Xcode-selected full suite passes 595 functions (130 app + 465 core), including deferred mutation, cross-window Cut handoff, duplicate submission, clipboard replacement, collision/dirty cancellation and retry, partial moves and newer-clipboard preservation. Ten marked known issues exercise existing timeout diagnostics. `node scripts/build-app.mjs` packages successfully without compiler warnings.
- 2026-10-19: Agent-operated native review passes Cut menu availability, Command-X without mutation, Command-V move and retained Option-Command-V. Independent file checks confirm destination bytes/source removal. Native text Command-X/V changes/restores the buffer while preserving its source file. Tighten then probe checks clipboard ownership and outcome handling; the existing transfer engine remains the mutation owner.
- Live separate-window gestures, collision/dirty native prompts, full VoiceOver, Light/Dark and macOS 26 outcomes remain pending. Menu names/states were inspected through accessibility APIs. File-operation Undo/Redo remains excluded.

- 2026-10-19: Published in [PR #52](https://github.com/bcinarli/pane-peek/pull/52), targeting `main`; implementation commit [`5c65e57`](https://github.com/bcinarli/pane-peek/commit/5c65e575bdba05022f94b475d943aaaec4d0407e). Both presented units are accepted overall; staged and full-tree privacy/secret scans report no findings. Remaining individual native/accessibility checks above are unchanged.

## Additional native review

Cut a disposable file or mixed selection with Command-X; verify it stays in place. Focus the receiving browser and use Command-V; verify contents and source removal. Repeat across windows, in one-pane mode and with Option-Command-V.

Cancel a duplicate-name or unsaved-edit prompt, then retry in another directory. Copy another selection or text after Cut and verify Paste no longer moves the original files. Verify native text/rename-field Cut/Paste and Cut menu disabled states with no selection. Full VoiceOver, Light/Dark and macOS 26 checks retain separate outcomes.
