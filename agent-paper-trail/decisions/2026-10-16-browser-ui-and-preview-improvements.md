---
status: Accepted
date: 2026-10-16
supersedes: []
superseded_by: ""
---

# Browser UI and preview improvements

## Context and decision

Bilal accepted the first five UI refinements and added read-only image/video Details previews, direct Move/Trash and transient operation feedback on 2026-10-16. Bilal also selected five-second success notifications with errors/partial failures retained until dismissal. This records accepted intent; implementation, native review and source-control approval remain separate.

- Use the existing pinned Lucide library for recognisable file categories with a generic fallback. Retain folder/package/link distinctions; specialised folder artwork is available but this change does not infer directory purpose from its contents.
- Rename both Finder actions to Reveal in Finder. Continue opening selected directory contents and revealing files/packages/file links, preserving listed URLs and existing error handling.
- Present One Pane / Two Panes as one joined, mutually exclusive icon-and-text toggle. Preserve current layout/state behaviour and View-menu access.
- Replace the toolbar Favourites dropdown with an anchored popover. Rows show folder name, subdued full path and separate open-in-active-pane/remove icons. Reuse shared persistence, unavailable-path removal and guarded navigation. Keep menu-bar keyboard access; do not add a permanent favourites column.
- Browser Space toggles native Quick Look for the selected files; Escape closes it. System-supported previews include images, PDFs and media. Keep text-field/editor/rename keyboard behaviour local. Quick Look reads saved files and does not replace or save/discard PanePeek drafts.
- Details supports read-only image and video previews above metadata. Fit images without distortion; videos start paused and have native playback controls. No media editing actions. Bound resources, discard stale loads and stop playback when its selection/window is replaced or closed. Unsupported/corrupt media has a clear fallback.
- Execute Move and Trash without the routine operation-confirmation dialogs. Keep captured requests, conflict/collision/duplicate rejection, shared operation locks, affected-document Save/Discard/Cancel and honest partial outcomes. Trash never falls back to permanent deletion.
- Replace the permanent operation-status strip with compact in-window notifications. Successful copy/move/Trash results disappear after about five seconds. Errors/partial failures remain dismissible with their details accessible. Preserve accessible announcements and keyboard dismissal without taking focus; old timers must not dismiss newer results.

## Rationale and alternatives

Lucide category artwork preserves the accepted visual style; Finder-associated icons could offer application-specific artwork but introduce a different appearance. An anchored favourites popover keeps navigation close to its toolbar control; a modal window adds an interruption. Native Quick Look provides the requested Finder behaviour while the Details text editor keeps its existing draft and Save contract.

The earlier Move/Trash dialogs make routine operations slower. Direct execution meets Bilal's requested interaction while existing preflight and unsaved-edit safeguards protect the same data invariants. Auto-dismissing all outcomes risks losing partial-failure details; Bilal chose transient success and retained failure notifications.

## Records and validation

The [MVP spec](../specs/001-mvp/spec.md) owns the revised behavioural criteria. [T20](../specs/001-mvp/plan.md#t20-browser-ui-and-preview-refinements) owns the bounded unit sequence; the [tracker](../specs/001-mvp/tasks.md) and [evidence](../specs/001-mvp/evidence/ui-behaviour-improvements.md) own approval and execution state. Existing decisions and historical evidence remain intact; this additive record changes the specific spec requirements above without replacing unrelated restoration, appearance or editor choices.

### [Changed] 2026-10-16: hidden-item badge

After accepting the category-icon appearance, Bilal approved adding the existing Lucide eye-off symbol as a small badge for hidden files and folders. Retain each item's category/directory/package/link icon. Use the listing's hidden metadata rather than a separate filename-only check, keep row names aligned and expose Hidden through row accessibility/help without a duplicate decorative element. A dedicated hidden-item icon would lose the file category; the badge preserves both. This follow-up has its own native/manual review and does not authorise the later T20 coding units.
