---
task: browser-edit-menu
verdict: Passed
closed: "2026-10-19"
---

# Browser Edit menu

- 2026-10-19: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer node scripts/test.mjs --filter BrowserFileCommandsTests` intentionally failed in all seven initial parameterised cases because the native browser Copy/Paste/Move/Trash selectors were absent. After implementation, all five initial test functions passed. Runs used macOS 27.0.1 and Xcode's Swift toolchain; unique pasteboards and temporary filesystem fixtures isolate test data.
- 2026-10-19: Affected `BrowserFileCommandsTests|DirectoryTableTests|FileDropTests|PreviewTextViewTests` pass all 29 functions; the full `node scripts/test.mjs` run with the same Xcode selection passes 589 functions (124 app + 465 core). The ten marked known issues exercise existing diagnostic/timeout guards. `node scripts/build-app.mjs` packages successfully without compiler warnings. No distribution signing or publication is included.
- 2026-10-19: Agent-operated native review passes Edit Copy/Paste/Move availability, Command-V copy, Option-Command-V move and Command-Delete Trash on disposable files. Independent filesystem checks confirm copy bytes/source preservation and move bytes/source removal. Finder-to-PanePeek copy works in one-pane mode; PanePeek-to-Finder copy also preserves expected bytes.
- 2026-10-19: Native text-editor Copy/Paste and Command-Delete retain text behaviour while Move Item Here and File > Move to Trash disable appropriately. Accessibility inspection exposes the menu names and enabled/disabled states. Tighten then probe checks reuse, captured destinations, stale/invalid inputs and text-focus isolation. Full VoiceOver, Light/Dark appearance, inline-rename/Go-to-Folder and live cross-window clipboard checks remain pending; macOS 26 was not exercised. File-operation Undo/Redo and Cut are excluded.

- 2026-10-19: Published in [PR #52](https://github.com/bcinarli/pane-peek/pull/52), targeting `main`; implementation commit [`5c65e57`](https://github.com/bcinarli/pane-peek/commit/5c65e575bdba05022f94b475d943aaaec4d0407e). Both presented units are accepted overall; staged and full-tree privacy/secret scans report no findings. Remaining individual native/accessibility checks above are unchanged.

## Additional native review

Use disposable source/destination folders with text files, a folder and a listed symlink. From a browser list, copy a mixed selection with Command-C, focus the receiving pane and paste with Command-V. Repeat with Option-Command-V and check source removal. Exercise one-pane mode and files copied from Finder. Copy remains distinct from Copy Absolute/Relative Path.

Check Edit menu and File > Move to Trash availability for empty/selected listings, text-only clipboard contents and busy transfers. Use Command-Delete on a disposable file and verify Trash. In Details Edit, inline rename and Go to Folder, verify normal text Copy/Paste and Command-Delete without changing browser files. Check collision cancellation and unsaved-edit cancellation. Review keyboard access, accessible menu names/disabled states, VoiceOver and Light/Dark presentation.
