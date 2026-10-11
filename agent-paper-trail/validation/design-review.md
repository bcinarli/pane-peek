# Draft design review

Status: Draft UI and logo direction accepted. Native behaviour, production icon assets and revised task sequencing remain subject to their review gates.

## Reviewed result

On 2026-10-03, Bilal accepted the compact Browse & peek UI after requesting shorter breadcrumb headers, a favourite star and Home before `/`. The original peeking-P logo was also selected that day. The [repository references](../design/001-mvp/README.md) preserve the selected screenshot and generated concept without changing their image contents.

On 2026-10-04, Bilal authorised spec/plan alignment and confirmed highlighting for ordinary web development files, including HTML, XML, CSS, SCSS and JSX/TSX. [Decision 0003](../decisions/0003-ui-and-logo-direction.md) records the design direction; the [spec](../specs/001-mvp/spec.md) owns the full language list and requirements.

The illustrative interactive preview was checked before design acceptance for navigation, favourite state, dirty-buffer retention, path copying, long-header alignment and narrow layout. These were preview checks against sample in-memory data. They do not validate the native filesystem, AppKit editor, clipboard or persistence.

## Implementation review still required

Use the [native design checklist](checklist.md#native-design-checks) as tasks become available. Design approval does not complete native criteria or a task's running-app manual review. Record that evidence separately under the [task workflow](../specs/001-mvp/plan.md#task-workflow-and-exit-gates).

The wider Edit focus layout is exploratory. The carousel beneath the screenshot and design controls are preview UI. Production icon preparation and bundle integration have not been performed.

## Reusable source review

On 2026-10-04, Bilal requested reusable logo/app drafts. The [source pack](../design/001-mvp/README.md#reusable-sources) now includes a transparent SVG logo redraw, a generated SVG icon composition, the exact UI fragment and a standalone browser export. The original raster references remain unchanged.

The SVG paths/gradients were compared visually with the raster and rendered at 128/64/32/16 px. Transparent placement was checked on light/dark surfaces. The redraw preserves the concept but is not a pixel-exact conversion. Bilal accepted the reusable SVG/UI draft source pack on 2026-10-04. Production icon checks remain pending.

The standalone UI export renders both panes and Details, and its Preview/Edit switch works. Browser-preview libraries remain external; the SVGs and logo comparison page are self-contained. This source-export check does not complete native acceptance criteria or claim the sample highlighter covers all A15 languages.

## Highlighting scope extension

On 2026-10-10, Bilal requested the [additional configuration/code languages](../decisions/0006-extended-syntax-highlighting.md) and clarified that Sass meant SCSS, excluding indented `.sass`. The maintained spec/plan incorporate this accepted scope. Suggested extra formats remain subject to scope review, and each coding unit retains its approval gate. No native acceptance evidence for the new languages is claimed.
