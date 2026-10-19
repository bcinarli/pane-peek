---
task: images-shortcuts
verdict: Passed
closed: "2026-10-19"
---

# Screenshot alignment and shortcuts

Publication: [PR #61](https://github.com/bcinarli/pane-peek/pull/61), targeting `main`.

2026-10-19, agent-observed in the local in-app browser: Paired-image checks pass at 1440, 1280, 851, 850, 580 and 320 px in Light/Dark, with a 900 px viewport height. The curated Support table passes eight Light/Dark cases at 1280, 850, 580 and 320 px. Paired editing frames have equal heights and caption baselines; stacked frames retain equal proportions. At 1280 px, each frame measures 544 × 296.648 px. No page or keycap overflows horizontally, and footers remain at the document bottom. Privacy and 404 also pass eight desktop/narrow Light/Dark regression cases.

2026-10-19, agent-observed: The common thumbnail ratio follows the visible light capture below its title bar, clipping the slightly taller dark capture to the same frame. Original asset files are unchanged. Both editing links open full-size modal images at their native 2436 × 1460 and 2200 × 1300 dimensions; scroll lock, Escape dismissal, focus return and scroll unlocking pass. The homepage shortcut-reference link reaches Support’s shortcuts section. No browser console errors are reported.

2026-10-19, source/browser inspection: Six homepage highlights link to ten Support actions in three labelled groups: Browsing, Files and paths, and Details. Every retained shortcut matches the usage guide and implementation; familiar selection, navigation, clipboard, editing and window combinations are absent. The browser accessibility tree exposes readable key names and the table caption. The homepage reference link has visible 3 px Mauve focus. Shortcut group text contrast is 4.79:1 in Light and 6.84:1 in Dark. Symbol alternatives, table captions/row headers, active-pane context and the optional Fn modifier are present. Apple’s reference is linked for familiar Mac commands.

Tighten retains static markup, one table and existing component styles, with low-specificity table rules and no new runtime code. Probe covers aspect-ratio differences, lazy images, wrapped key combinations, shortcut context, full-size fallback and shared-page layout. VoiceOver, actual browser zoom and executing every native shortcut were not exercised by this website unit.

2026-10-19, agent-observed: HTML nesting, unique IDs, section labels and external-link isolation pass across all four pages. All 75 local HTML references/fragments and local Markdown targets resolve. Whitespace and repository privacy/Gitleaks checks pass across the changed/new files with zero findings.

## Sources

- [App usage shortcuts](../../../../docs/usage.md#keyboard-shortcuts)
- [App command bindings](../../../../sources/panepeek/PanePeekApp.swift)
- [Browser, creation and Save bindings](../../../../sources/panepeek/BrowserWindow.swift)
- [Native list key handling](../../../../sources/panepeek/DirectoryTable.swift)
- [Quick Look controls](../../../../sources/panepeek/QuickLookPreview.swift)
- [Standard Mac keyboard shortcuts](https://support.apple.com/en-us/102650)
