---
task: muted-selection-prototype
verdict: Passed
closed: 2026-10-12
---

# Evidence: muted-selection-prototype

Bilal accepted the submitted native selection change on 2026-10-12 and authorised commit and PR creation. Mauve controls remain, file selection uses the draft's muted colours, and the requested keyboard/multi-selection/rename/VoiceOver checks are recorded below. The [accepted selection decision](../../../decisions/2026-10-12-muted-browser-selection.md) owns the adopted appearance. Merge requires separate approval.

## Implementation

The browser lists use an explicitly owned AppKit table and custom row selection drawing. Existing SwiftUI row content, inline name fields, BrowserState selection/dirty-document guards and path menus are reused. No private SwiftUI hierarchy inspection or runtime replacement is used.

The named `selection` asset resolves to `#F0E9F8` in Light and `#3B304A` in Dark. Mauve controls retain the existing accent asset and registration. Active selection has a thin Mauve outline; increased contrast thickens it. Inactive selection uses native neutral colours. Selected dates use primary text so the lighter fill retains readable foreground contrast.

File selection uses the dedicated app palette, including when the system accent differs. Controls retain their existing system-accent handling.

## Executed checks

Environment: macOS 27.0.1 (26A434), Apple Swift 6.4, Node 26.1.0, deployment target macOS 26. No macOS 26 runtime check is claimed.

- Intentional native seam red: keyboard range/primary, URL selection through reorder and rejected dirty selection failed before integration. After integration, the focused tests passed. Repeated rejected arrow/range changes also retain the dirty document and selected row.
- A native probe reproduced context targeting without first-responder transfer. Its added test failed the expected first-responder assertion. The accepted context-target completion now focuses the explicitly owned table. The final full suite passes 292 core tests and 20 app/native tests, including this regression, with four existing expected gate diagnostics.
- `node scripts/build-app.mjs` and Info.plist lint pass. Compiled named assets resolve to the intended colours in both appearances. Whitespace checks pass. Final native readback confirms Down after dismissing a cross-pane context menu acts on the targeted table and retains the other pane's selection.
- Agent observed Dark appearance: arrows, Shift-arrow range extension/shrink, Command-click, Select All retaining primary, Escape clearing selection, basename/multi-extension selection, Escape focus recovery, successful rename with selected new path, collision retry and directory double-click navigation. These checks used disposable files.
- Bilal confirmed VoiceOver correctly reads filenames and selected states and supports entering/cancelling inline Rename. Agent inspection verified native table/row/selected roles, filename/type/date text and named rename fields. Agent did not hear the speech. VoiceOver's originally off setting was restored after the check.

Calculated from the compiled assets and resolved AppKit text roles: primary text on active selection is 13.09:1 Light and 9.32:1 Dark; the Mauve outline against the fill is 4.51:1 and 5.72:1. Light secondary text would be 3.82:1, which motivated the selected-date change. These are colour calculations, not rendered-pixel measurements or a whole-app accessibility pass.

Standard tighten retained existing row/editor/guard implementations and limited height updates to affected rename rows. Standard probe checked native keyboard and context focus, rejected dirty transitions, asset packaging and selected foreground contrast. The repository accessibility baseline and T18 audit retain their separate scope.

## Run and review

From the prototype checkout, follow the [build/run instructions](../../../../README.md#build-and-run). Quit PanePeek before rebuilding. Reuse the [T09 disposable fixture recipe](rename-affected-document-handling.md#disposable-fixture-and-run-instructions). The running prototype is already open on a disposable directory.

- [x] Bilal accepted the submitted active/inactive styling, outline and selected date text on 2026-10-12.
- [x] Bilal confirmed the requested VoiceOver interaction check.
- [x] Bilal approved adopting the native table change and requested commit/PR creation.

This acceptance does not supply individual Light/increased-contrast/system-setting measurements. Detailed settings coverage remains part of T18; no full-app accessibility pass is claimed.

## Publication

Published [PR #21](https://github.com/bcinarli/pane-peek/pull/21) targets `main`. Implementation commit: [`8e944db`](https://github.com/bcinarli/pane-peek/commit/8e944dbab4172a823078060dac3f43801e24a955). Bilal approved commit and PR creation on 2026-10-12; merge remains pending separate approval.
