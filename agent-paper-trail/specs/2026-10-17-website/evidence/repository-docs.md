---
task: repository-docs
verdict: Passed
closed: "2026-10-19"
---

# Repository documentation alignment

Publication: [PR #61](https://github.com/bcinarli/pane-peek/pull/61), targeting `main`.

2026-10-19, source inspection: docs/usage.md contains 36 actions and 39 key combinations across Navigation and previews, Files and paths, Text editing, View and Details, Dialogs and popovers, and Windows and app. All 14 explicit app-command bindings are covered. Support’s ten curated actions remain a subset. The guide explains active-pane scope, Cut/Paste moves, text-only Undo/Redo and the possible Fn modifier.

2026-10-19, source inspection: PRIVACY.md preserves its existing app-specific file, preview, settings, draft and clipboard sections. Public support contact, iCloud Mail handling, three-month email retention and its GitHub Issues exclusion match the website policy. Website hosting and browser-theme storage are clearly labelled separately from app processing. The policy date remains consistent across both forms.

Tighten keeps one detailed usage reference and one concise website selection. Probe checks source bindings, group/action counts, retained app-policy detail and shared operational facts. No native app code or privacy behaviour changes. Native execution of every shortcut and the Swift suite were not repeated for this documentation change.

2026-10-19, agent-observed: All 188 local Markdown targets and 75 local HTML references/fragments resolve. HTML structure and accessible labels pass across four pages. The staged privacy/Gitleaks scan checks 16 file versions with zero findings; whitespace checks pass.

## Sources

- [Full keyboard reference](../../../../docs/usage.md#keyboard-shortcuts)
- [Repository privacy policy](../../../../PRIVACY.md)
- [Website privacy policy](../../../../website/privacy/index.html)
- [App commands](../../../../sources/panepeek/PanePeekApp.swift)
- [Creation, navigation and Save bindings](../../../../sources/panepeek/BrowserWindow.swift)
- [Native list shortcuts](../../../../sources/panepeek/DirectoryTable.swift)
- [Apple’s standard Mac shortcuts](https://support.apple.com/en-us/102650)
