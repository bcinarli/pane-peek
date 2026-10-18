---
task: dark-macchiato-appearance
verdict: Passed
closed: 2026-10-18
---

# Dark Macchiato appearance

App-owned Dark surfaces follow the [accepted roles](../../../decisions/2026-10-18-dark-macchiato-surfaces-and-controls.md): Base for lists/previews, Mantle for headers/Details/floating content, Crust for the frame and Surface 0 for owned borders. Shared adaptive colours retain native Light roles. Active Mauve-filled buttons and the selected Preview/Edit segment use Base ink; inactive controls retain native text colours. The [drag-state follow-up](command-drag-and-preview-contrast.md) preserves Mauve fill and Base text while the control remains disabled during dragging.

Native button and segmented-control adapters use public AppKit APIs. The segment customises only its content drawing, retaining the native bezel, focus and accessibility. The editor view and separate muted browser selection are retained. Duplicate-dialog layout and Copy collision choices are outside this unit.

## Executed checks (2026-10-18)

- Red/green: the two new control behaviour tests first produced five issues with unwired action/update paths, then passed after wiring. They exercise Return, disabled actions, Preview/Edit routing, external selection changes and dirty-draft/document retention.
- Final focused run passed 29 tests in seven suites: `AccentControlsTests`, `BrowserLayoutToggleTests`, `PreviewTextViewTests`, `MarkdownPreviewTests`, `BrowserLifecycleTests`, `MoveCollisionPromptTests` and `DirectoryTableTests`. Full `node scripts/test.mjs` passed 563 tests (108 app, 455 core), with nine expected timeout self-test diagnostics. Environment: macOS 27.0.1, Xcode 27.0, Apple Swift 6.4, arm64; Xcode selected explicitly.
- Temporary native fixture renders were visually inspected in Light and Dark. The inactive grey bezels exposed unreadable forced labels; native inactive text colours corrected that result. Disabled presentation and the Mantle fixture background were inspected. The rendering helper was removed after inspection; active Mauve pixels were not verified by these inactive fixtures.
- Base on Mauve has calculated 6.84:1 contrast. This calculation supports the chosen pair, not a claim about every rendered control state.
- `node scripts/build-app.mjs`, `git diff --check` and changed-document local links pass. An isolated review bundle was packaged and its running process verified; active presentation remains unchecked.
- Unlocked live follow-up: the browser's Dark surfaces and active Preview segment were visually inspected, with dark Base text on the Mauve selection. The active duplicate sheet also has dark Mauve-button text, but its attached backdrop remains neutral grey; [backdrop follow-up](collision-sheet-backdrop.md) owns that gap. Light/Dark switching and full accessibility review remain pending.

## Review passes and remaining checks

Tighten keeps the palette in one small role collection and control handling in two native adapters. Probe covers disabled/default actions, retained editor state and inactive contrast. The live desktop was unavailable for active-window checks; no live appearance or accessibility pass is inferred from tests.

- [ ] Review the packaged app in Dark: list/preview Base, header/Details Mantle, frame Crust, selected Preview/Edit and default sheet/alert actions with dark labels on Mauve.
- [ ] Switch Light to Dark and back without reopening; check active/inactive windows, disabled states, app-owned sheets/popovers, browser focus and muted selection.
- [ ] Check Return/Escape, keyboard traversal and segmented-control selection; verify native focus rings and VoiceOver names/selected/disabled states. Repeat with increased contrast, enlarged text and narrow Details.
- [ ] Edit a disposable text file, toggle Preview/Edit and resize Details; confirm the draft, caret and Undo survive.

The presented unit is accepted overall. Individual live appearance/accessibility outcomes remain unreported. Existing full-criterion and app-wide accessibility verdicts are unchanged.

Published in [PR #40](https://github.com/bcinarli/pane-peek/pull/40), targeting `main`. Merge remains separately gated.
