> Historical detail and fixtures. Current verdict: [Panel header alignment validation](../specs/001-mvp/evidence/panel-headers.md). Earlier publication/checkpoint statements below are historical.

Status: Archived

# Panel header alignment validation

Status: accepted. Bilal authorised commit of the reviewed divider/header changes, then confirmed the remaining manual review checks work OK on 2026-10-09.

## Change

Home, breadcrumb labels, favourite stars and the Details title now centre vertically in a shared 52-point header. This replaces the 44-point rows whose bottom-only scrollbar padding moved labels towards the toolbar. Symmetric breadcrumb padding retains space for the native horizontal scrollbar and its accessibility actions.

The extra 8 points let centred text clear the scrollbar. The [spec](../specs/001-mvp/spec.md) treats the draft's 44 px height as a guide and requires accessible long paths. Fonts, breadcrumb anchors and navigation handlers retain their existing implementation.

## Executed checks

Same local environment as the [divider unit](ui-toolbar-dividers.md#executed-checks).

- Build/package, Info.plist lint and whitespace checks pass.
- Native dark screenshots show a shared centre line for both location headers and Details, with short and overflowing paths.
- At the 250-point file-pane minimum, header controls remain aligned. Native Scroll Left/Right actions remain exposed and move the long path towards each end. The trailing endpoint remains reachable after narrowing.
- An ancestor breadcrumb navigates its own pane. Right-pane Command-L navigation and item selection still update the listing and Details.

Light appearance and the system's always-visible scrollbar setting were left for Bilal's manual review. No new behaviour tests or suite rerun for this spacing change, following the [plan](../specs/001-mvp/plan.md#task-workflow-and-exit-gates).

Light tighten kept one shared height and local padding changes. Light probe checked long-path access and narrow-pane alignment, retaining the native scroll controls required by the earlier breadcrumb review.

## Manual review

The rebuilt app is running with a long path in the left pane and scripts in the right.

- [x] Confirm the centred baseline and slightly taller headers look right in light and dark appearance.
- [x] Check a long breadcrumb path while scrolling, including always-visible scrollbars if enabled. Confirm readable labels and reachable ancestors/current directory.

Bilal accepted the reviewed changes and authorised commit plus the next UI unit. The implementation was subsequently pushed with separate approval.

[Accepted, 2026-10-09] Bilal confirmed the remaining manual review checks were reviewed and working OK, and requested `done` status. The conditional scrollbar check retains its original scope.

[Changed, 2026-10-09] Bilal directed that the enlarged-text-header concern in the [PR review](https://github.com/bcinarli/pane-peek/pull/10#pullrequestreview-5470676963) be ignored. It is dismissed without a layout change.
