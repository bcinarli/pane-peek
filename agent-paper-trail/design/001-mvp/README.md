# PanePeek draft design

Status: Original UI and logo direction accepted on 2026-10-03; browser layout direction accepted on 2026-10-11. The draft and screenshot refresh follows the current native UI and is accepted on 2026-10-18. Native feature acceptance and the production icon retain their separate gates.

The [spec](../../specs/001-mvp/spec.md#accepted-ui-design) owns behaviour and appearance requirements. [Decision 0003](../../decisions/0003-ui-and-logo-direction.md) records the choices and alternatives; the [plan](../../specs/001-mvp/plan.md#design-checkpoint) assigns their implementation and review.

The [accepted dark-surface refinement](../../decisions/2026-10-18-dark-macchiato-surfaces-and-controls.md) defines Macchiato backgrounds and dark labels on Mauve-filled controls. The editable draft uses these roles for its dark surfaces and filled controls. Layout/logo acceptance and native-review limits remain separate.

> **Visual UI samples:** The HTML drafts demonstrate layout and colours with in-memory files and simulated actions. The MVP spec and native task reviews govern app behaviour. Keep the native implementation in its existing Swift views.

Review these drafts for presentation and fidelity to the accepted design. Report misleading states or broken preview interactions as preview issues, separately from native app correctness and acceptance.

The draft and native documentation screenshots use the shared Project and Reference sample folders with fictional documents. Owner/group labels in the draft use `demo` and `staff`. Keep the exact sample-path exceptions in the [privacy rules](../../../scripts/privacy-rules.json). The [refresh evidence](../../specs/001-mvp/evidence/design-docs-refresh.md) records the 2026-10-18 captures and checks.

## Reusable sources

| File | Use |
| --- | --- |
| [peeking-p.svg](peeking-p.svg) | Transparent vector logo master: two editable paths and Mauve gradients. Use for logo placement and as the geometry source for icon artwork. |
| [app-icon-draft.svg](app-icon-draft.svg) | Generated square icon composition with a separate background layer. Uses the logo master's exact paths/gradients and original placement. |
| [export-icon.mjs](export-icon.mjs) | Regenerates the icon composition from the logo master using Node's built-in libraries. |
| [logo-preview.html](logo-preview.html) | Original raster beside the SVG redraw, with 128/64/32/16 px previews and transparent artwork on light/dark surfaces. Opens locally without network dependencies. |
| [app-draft.fragment.html](app-draft.fragment.html) | Editable UI source, including the accepted single/dual-browser and Details expansion visuals. |
| [app-draft.html](app-draft.html) | Standalone browser preview exported from the fragment. Preview icons/tooltips load pinned external libraries; this is design tooling, not native app code. |

The SVGs contain real paths/gradients, with no embedded raster, fonts or external assets. Named groups separate the mark and icon background. The SVG redraw was created on 2026-10-04 and compared visually with the accepted raster. Bilal accepted the reusable source pack that day. It is a draft reconstruction, not a pixel-exact conversion; keep the raster as a comparison reference. [T01 Unit 2](../../validation/t01-launchable-shell.md#unit-2-static-alignment-and-development-icon) packages the development icon with transparent margins and a rounded background. Final production refinement and small-size acceptance remain in T18.

For future agents: reuse these sources instead of generating a replacement from screenshots. Edit `peeking-p.svg` for geometry/colour changes, then run this command from the repository root:

```sh
node agent-paper-trail/design/001-mvp/export-icon.mjs
```

Treat `app-icon-draft.svg` as derived artwork. Keep its square background separate from the transparent mark; platform icon packaging and masking belong to the native icon task. The transparent master can be placed in other application artwork without rebuilding its geometry.

Edit the UI fragment for layout/interaction changes, then regenerate the browser export with the visualize skill's export tool. The starting variants remain in the source; Browse & peek retains the compact default. The sample Markdown renderer and highlighter cover the displayed examples. Use native code and A15 for the full language and format support.

## Current browser samples

The [accepted layout direction](../../decisions/2026-10-11-browser-layout-modes-and-details-sizing.md) provides one/two-browser modes and expandable Details. The current samples also show the implemented Size column, hidden-file badges, searchable Favourites, inline rename and horizontal duplicate choices. Move and Trash run directly; operation results use temporary notifications. The [earlier layout review](../../validation/layout-modes-design.md) remains the record of the 2026-10-11 visual acceptance.

- One pane / Two panes in the shared toolbar retain the active browser and hide the other without losing its state. Returning to two keeps the current browser on the left and restores the preserved browser on the right. Preview/Edit remains an independent control.
- The Details header has Expand / Restore. Its divider can be dragged or adjusted with left/right arrow keys. The View menu provides the same layout and expansion actions.
- Details can occupy half the window width, subject to visible browser minimums. Single-pane context menus disable transfers to the hidden browser.

| Starting variant | Layout | Reference |
| --- | --- | --- |
| Browse & peek | Dual browser with compact Details | [Light reference](layout-browse-peek.png) |
| Single & peek | Active browser beside 50% Details | [Light reference](layout-single-peek.png) |
| Edit focus | Dual browser beside 50% Details, Edit selected, with an unsaved draft | [Dark reference](layout-edit-focus.png) |

Each variant supports both browser modes and Details sizing. Edits and file actions change the sample data in memory. PanePeek targets macOS; mobile and iPad designs are outside the MVP scope. The compact host presentation below 800 pixels keeps the design inspectable inside a narrow preview. Native window sizing and pane layout continue to follow the Mac spec.

## Browse & peek

![Current Browse & peek draft, with Size columns and a Markdown preview.](browse-and-peek.jpg)

The reference shows two directory lists beside Details, with compact breadcrumbs and favourite stars. The window image comes from the editable draft; variant controls belong to its browser preview.

Browse & peek and Single & peek start in Light; Edit focus starts in Dark. The draft follows native Light and Macchiato Dark surface roles. Sample dimensions guide proportions; native sizing follows the spec. See the [product screenshots](../../../docs/usage.md) for current captures of the running app.

The native [UI asset pack](../../../assets/README.md) reuses the draft's pinned Lucide geometry and accepted Mauve colours. Its [integration validation](../../validation/ui-icons-accent.md) records the current manual review gate. This does not change the production app-icon review in T18.

## Original peeking-P

![Accepted original peeking-P logo concept](peeking-p.png)

Retain the curved Mauve P peeking behind the angled foreground pane. This generated raster is the accepted concept reference, not a production app icon. Native icon assets, small-size readability and bundle integration require their own review. Later variants with a more explicit rear rectangle were rejected.
