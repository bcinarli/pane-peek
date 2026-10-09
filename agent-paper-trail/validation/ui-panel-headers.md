# Panel header alignment validation

Status: accepted. Bilal authorised commit of the reviewed divider/header changes on 2026-10-09. The individual light-appearance and always-visible-scrollbar checks were not separately reported.

## Change

Home, breadcrumb labels, favourite stars and the Details title now centre vertically in a shared 52-point header. This replaces the 44-point rows whose bottom-only scrollbar padding moved labels towards the toolbar. Symmetric breadcrumb padding retains space for the native horizontal scrollbar and its accessibility actions.

The extra 8 points let centred text clear the scrollbar. The [spec](../specs/001-mvp/spec.md) treats the draft's 44 px height as a guide and requires accessible long paths. Fonts, breadcrumb anchors and navigation handlers retain their existing implementation.

## Executed checks

Same local environment as the [divider unit](ui-toolbar-dividers.md#executed-checks).

- Build/package, Info.plist lint and whitespace checks pass.
- Native dark screenshots show a shared centre line for both location headers and Details, with short and overflowing paths.
- At the 250-point file-pane minimum, header controls remain aligned. Native Scroll Left/Right actions remain exposed and move the long path towards each end. The trailing endpoint remains reachable after narrowing.
- An ancestor breadcrumb navigates its own pane. Right-pane Command-L navigation and item selection still update the listing and Details.

Light appearance and the system's always-visible scrollbar setting remain manual. No new behaviour tests or suite rerun for this spacing change, following the [plan](../specs/001-mvp/plan.md#task-workflow-and-exit-gates).

Light tighten kept one shared height and local padding changes. Light probe checked long-path access and narrow-pane alignment, retaining the native scroll controls required by the earlier breadcrumb review.

## Manual review

The rebuilt app is running with a long path in the left pane and scripts in the right.

- [ ] Confirm the centred baseline and slightly taller headers look right in light and dark appearance.
- [ ] Check a long breadcrumb path while scrolling, including always-visible scrollbars if enabled. Confirm readable labels and reachable ancestors/current directory.

Bilal accepted the reviewed changes and authorised commit plus the next UI unit. Push remains separately gated.
