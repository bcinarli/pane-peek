# UI and logo direction

Status: Accepted draft design

Date: 2026-10-04

## Context

Bilal prioritises quick directory navigation, text editing and access to absolute paths. Dense dual-pane managers add controls that obscure those workflows. Bilal accepted the refined Browse & peek draft and original peeking-P logo on 2026-10-03, then authorised spec/plan alignment and expanded highlighting on 2026-10-04.

## Decision

- Use native Mac surfaces with Catppuccin Macchiato Mauve accents and editor colours.
- Keep two independent directory panes beside a far-right Details preview/editor. Use compact clickable breadcrumbs with Home and a per-pane favourite star.
- Show focus with a thin Mauve underline. One shared toolbar/menu acts on the focused pane; file transfers use context menus and drag/drop.
- Keep the selected absolute path visible with a copy action. Highlight supported text in both Preview and Edit, including HTML, XML, CSS, SCSS and JSX/TSX.
- Retain the original curved peeking-P logo concept.

The [spec](../specs/001-mvp/spec.md#accepted-ui-design) owns detailed requirements. [Repository references](../design/001-mvp/README.md) preserve the selected UI screenshot and original logo.

## Rationale and consequences

Compact navigation keeps directory changes close to each list. Shared controls reduce repetition; the focus cue must remain visible when no file is selected. Context-menu transfers supersede the earlier button-based presentation of A20 without changing transfer safeguards.

The mockup establishes design direction, not native behaviour acceptance. AppKit editing, keyboard access, long paths, system appearance and filesystem safeguards still need running-app evidence. Native typography and accessibility can require spacing changes while preserving the layout. The [plan](../specs/001-mvp/plan.md#design-checkpoint) proposes earlier paths/favourites work and a separate shell review; it does not approve coding.

The logo is a raster concept. Production asset preparation must preserve its shape and verify small-size readability before bundle integration.

## Alternatives considered

- Full Macchiato app surfaces: native surfaces with palette accents/editor colours selected instead.
- Teal accents and repeated pane menus/transfer buttons: rejected during UI review.
- Wider Edit focus layout: exploratory; Browse & peek selected as the default reference.
- Explicit rear-pane logo variants: rejected; original peeking-P flow retained.

## Related documents

- [MVP spec](../specs/001-mvp/spec.md)
- [Implementation plan](../specs/001-mvp/plan.md)
- [Validation checklist](../validation/checklist.md)
