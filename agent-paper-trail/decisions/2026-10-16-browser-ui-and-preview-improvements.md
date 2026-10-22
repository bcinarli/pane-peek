---
status: Superseded
date: 2026-10-16
supersedes: [0001-product-boundaries.md]
superseded_by: decisions/2026-10-22-same-folder-copies.md
---

# Browser UI and preview improvements

[Same-folder copies](2026-10-22-same-folder-copies.md) governs same-folder copy semantics. The remaining requirements below are binding.

## Current decision

- Use the existing pinned Lucide library for recognisable file categories with a generic fallback. Retain folder/package/link distinctions; specialised folder artwork is available but this change does not infer directory purpose from its contents.
- Rename both Finder actions to Reveal in Finder. Continue opening selected directory contents and revealing files/packages/file links, preserving listed URLs and existing error handling.
- Present One Pane / Two Panes as one joined, mutually exclusive icon-and-text toggle. Preserve current layout/state behaviour and View-menu access.
- Replace the toolbar Favourites dropdown with an anchored popover. Rows show folder name, subdued full path and separate open-in-active-pane/remove icons. Reuse shared persistence, unavailable-path removal and guarded navigation. Keep menu-bar keyboard access; do not add a permanent favourites column.
- Browser Space toggles native Quick Look for the selected files; Escape closes it. System-supported previews include images, PDFs and media. Keep text-field/editor/rename keyboard behaviour local. Quick Look reads saved files and does not replace or save/discard PanePeek drafts.
- Details supports read-only image and video previews above metadata. Fit images without distortion; videos start paused and have native playback controls. No media editing actions. Bound resources, discard stale loads and stop playback when its selection/window is replaced or closed. Unsupported/corrupt media has a clear fallback.
- Execute Move and Trash without the routine operation-confirmation dialogs. Keep captured requests, conflict and duplicate rejection with explicit collision choices, shared operation locks, affected-document Save/Discard/Cancel and honest partial outcomes. Trash never falls back to permanent deletion.
- Replace the permanent operation-status strip with compact in-window notifications. Successful copy/move/Trash results disappear after about five seconds. Errors/partial failures remain dismissible with their details accessible. Preserve accessible announcements and keyboard dismissal without taking focus; old timers must not dismiss newer results.

## Category and hidden-state presentation

Retain the category/directory/package/link icon and add the existing Lucide eye-off badge from listing hidden metadata. Expose Hidden through row accessibility/help without a second decorative accessibility element. The badge preserves category information that a replacement hidden icon would lose.

## Size display and ordering

Columns are Name, Size, Modified. Regular files use metadata byte counts; directories, packages, links and unavailable sizes display the unknown marker without recursive scans. Size sorts per pane, largest first then reversed, with unknowns last in both directions and natural-name/stable-path ties.

## Favourites

The anchored popover searches saved folder names and full paths locally without filesystem reads or reordered persistence. Search/header stay fixed while rows scroll; available space and text size limit visible rows. Menu-bar entries use folder names, adding only enough parent context to distinguish duplicates, with full-path help/accessibility retained.

## Copy and Move collisions

Both operations offer editable numbered Keep Both, Cancel and explicit regular-file Replace. Resolve known batch conflicts before mutation, reserving names across the batch and revalidating captured identities after decisions. Cancel aborts before transfer. Same-item, duplicate-input and ancestry conflicts remain rejected; folders/packages/links offer no merging or Replace.

Replacement protects affected drafts and retains the old destination recoverably until publication succeeds. Late winners remain untouched and partial/recovery paths are reported. Copy always retains its sources. Exclusive publication and shared locks remain binding.

## Confirmation sheets

Unsaved edits and transfer collisions share one adaptive app-owned native sheet with horizontal actions and a trailing Mauve default. Order is Cancel, Discard, Save for edits; Cancel, Replace, Keep Both for replaceable collisions; Cancel, Keep Both otherwise. Return selects Save or Keep Both; Escape cancels. Preserve editable-name focus, window ownership and first-answer handling. Native system alerts control their own layout; private hierarchy changes are excluded.

## Operation notifications

Single-item success names the item/action; batch success uses the completed count. Success expires after about five seconds without a details popup. Errors and partial outcomes retain accessible details until dismissal; older timers cannot remove newer results or take editor focus.

## Rationale and alternatives

Pinned Lucide artwork retains the visual system. An anchored popover keeps navigation close to its owner; a separate modal interrupts browsing. Quick Look provides system file previews while the inline editor retains its own drafts. Direct operations remove routine confirmation while explicit collision and unsaved-edit choices protect data. Transient success keeps the workspace clear; retained failures preserve recovery information.

The [spec](../specs/001-mvp/spec.md) owns requirements and the [task tracker](../specs/001-mvp/tasks.md) owns current acceptance. This record supersedes [decision 0001](0001-product-boundaries.md) only where identified by the maintained scope; unrelated product boundaries remain binding.
