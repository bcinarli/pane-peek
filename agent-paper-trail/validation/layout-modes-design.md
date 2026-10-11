---
task: layout-modes-design
verdict: Passed
closed: 2026-10-11
---

# Layout modes design review

Status: Bilal accepted the updated visuals on 2026-10-11: “The design looks good.” Browser-preview checks pass. This closes the visual design review; native implementation and task acceptance retain their separate gates.

## Scope

Extend the existing editable UI source and regenerate its standalone preview for single/dual browsers and an expandable Details column. Retain the original accepted Browse & peek screenshot and SVG/logo sources. The revision demonstrates [the layout proposal](../decisions/2026-10-11-browser-layout-modes-and-details-sizing.md), with native implementation mapped to T19 and restoration to T17.

Work is isolated on a separate design branch. Parallel T07 implementation, task status and its manual review are unaffected. This record supplies design evidence, not completion evidence for T07 or a future native layout task.

## Executed preview checks, 2026-10-11

The standalone preview was exercised in installed Chrome through browser automation, then its screenshots inspected visually. The design script parses and the running preview reports no script errors.

| Check | Result |
| --- | --- |
| Three starting variants | Browse & peek, Single & peek and Edit focus render; the carousel selects each. |
| Active browser retention | Switching to single keeps either the selected left or right browser, according to its active state. Returning to dual keeps the current browser on the left and restores the hidden browser on the right with its selection retained. |
| Dirty document retention | Repeated layout changes keep the same editor element, exact buffer, dirty state and caret selection, without a dirty prompt. Native browser textarea undo still works afterwards. |
| Transfer targeting | Copy/Move to Other Pane are disabled in single-pane file menus; the handler also rejects single-pane requests. |
| Details expansion | Expand reaches 50% at a wide desktop size; Restore returns to the prior width. |
| Narrow bounds and recovery | At an 850-pixel browser viewport, dual browser minimum widths clamp expansion below 50%. Returning to the wide size restores the requested half-width. |
| Divider operation | Pointer dragging clamps during the drag; left/right arrow keys adjust from the actual visible width, including when the requested width is temporarily clamped. |
| View menu | Browser-mode actions retain the active document and target the visible browser. |
| Appearance and compact host | Light and dark screenshots inspected. A 360-pixel host reflows without horizontal overflow; its stacked presentation is preview-only. |

These checks use illustrative in-memory files. Browser textarea undo is not AppKit undo evidence. Filesystem safeguards, real transfers, native VoiceOver, app accessibility and macOS window restoration require their later implementation checks.

## Review passes

Standard tighten reuses the original product styles, sample state, editor and menu handlers. Layout changes update visibility and sizing without rebuilding the document. The native implementation should retain its existing split sizing owner.

Standard probe checked both active-pane identities, hidden targets, dirty retention and live resize limits. Hidden carousel variants defer width calculations until visible. Removed the sample renderer's unconditional editor scroll reset so layout/mode review does not imply deliberate loss of scroll state. Saved layout state follows the selected browser mode. A targeted probe first reproduced an unresponsive arrow-key step at a clamped width. Corrected the resize path to use the visible width and share one bounds calculation; the final browser checks pass.

## Visual review accepted, 2026-10-11

Bilal accepted the revised design overall. The toolbar controls, Details sizing and light/dark presentation were covered by the preview checks above; individual native checks remain pending.

PanePeek remains a macOS application. The narrow-host reflow serves the design preview and does not add a mobile or iPad product requirement.

Use the [editable source and standalone preview](../design/001-mvp/README.md#reusable-sources). The [reference images](../design/001-mvp/README.md#layout-revision-2026-10-11) capture the new starting states. Approval here does not authorise application coding, commit, push or merge.

## Spec and plan alignment, 2026-10-11

Added native A34/A35 and separate T19 sizing/mode units after T07; extended T17 with accepted layout restoration. Document checks confirm 35 distinct criteria, 19 task rows, linked targets and pending native acceptance. T07’s plan section/tracker row and all application source match the pre-alignment baseline.

The right-side return check first failed against the prior original-side preview. Updated browser presentation order without replacing browser/editor state, then reran the interaction checks successfully for both active identities, retained selection/buffer/caret/undo, sizing bounds and hidden transfers. No native implementation or relaunch validation was run. Light tighten reduced repeated status wording; standard probe checked identity versus displayed side, active-browser persistence updates, malformed-preference fallback, transfer snapshots and T07 isolation.
