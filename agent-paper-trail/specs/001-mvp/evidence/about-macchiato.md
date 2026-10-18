---
task: about-macchiato
verdict: Passed
closed: "2026-10-18"
---

# About Macchiato appearance

The [plan](../plan.md#about-macchiato-appearance-follow-up) owns scope; the [task row](../tasks.md#app-information-and-open-source-documentation) owns review state. About now uses one retained, non-restorable native panel with the shared adaptive floating surface and underlined Mauve links. Existing metadata, description and link generation remain authoritative. The panel resizes and scrolls, closes with Escape or the normal close action and stays outside browser registration. Link clicks use the native workspace handoff.

## Automated and packaged checks

- 2026-10-18: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer node scripts/test.mjs --filter 'AboutPanelTests|BrowserLifecycleTests'` passes all 13 functions. The added lifecycle regression verifies repeated opening, Escape/close, browser-window retention, a dirty draft and quit cancellation; existing tests retain bundle metadata, five links and honest unbundled fallbacks. This presentation replacement has native rendering evidence rather than a claimed behavioural TDD red.
- 2026-10-18: `node scripts/build-app.mjs` passes with Xcode 27.0/Swift 6.4 on macOS 27.0.1. The isolated review bundle retains packaged version/build 0.1.0 (3), the existing icon and notice resources. No macOS 26 runtime or hosted-CI result is inferred. The first full run hits the previously recorded restoration timeout self-test assertion; that test passes in isolation and a subsequent full run passes all 573 functions with nine expected known issues. The final full run after explicit link handoff also passes all 573 functions (111 app and 462 core), with nine expected known issues.

## Native checks

- 2026-10-18, agent-observed: the packaged Dark panel shows Mantle and Mauve links, readable copy, the existing icon, version/build and all five accessible link roles. The shared Mauve/Mantle pair has calculated 7.48:1 contrast. Escape returns to the browser. Opening About with an unsaved disposable draft and cancelling Quit retains the selection, Edit mode and exact draft; the file remains unchanged on disk. Privacy and Acknowledgements open the actual bundled text in the default text app, including licence/attribution content.
- 2026-10-18, isolated native rendering: Light followed by Dark repaints the shared surface and text. At the minimum 340 × 320 content size, doubled fixture fonts wrap and the last links remain reachable by scrolling. This is a layout stress check, not proof of a system-operated 200% text-enlargement mechanism. The live packaged icon is verified separately from offscreen rendering.

## Review limits and handoff

Full link-keyboard navigation, VoiceOver, increased contrast/reduced motion, the actual system text-enlargement mechanism and final-close/Dock-reopen behaviour remain unverified. A Tab check reached the panel rather than establishing focus on each link; no full keyboard pass is claimed. Overall appearance acceptance does not establish individual passing outcomes for version copying, project links or resizing beyond the executed checks above.

Tighten retains existing content generation and shared colour roles with a local native window, without new theme infrastructure. Probe covers ownership, draft/quit guards, adaptive repaint, narrow scrolling and explicit native link handoff. Whitespace and all 410 local links/anchors in the changed documents pass. The completed appearance unit does not establish full app-information or app-wide accessibility acceptance. Source-control publication remains separate.
