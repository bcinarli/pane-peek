# Listing and pane state

## Listing timestamps and links

Read each listed link's own modification date and link flag without resolving its target. Target resolution is used separately to establish whether it navigates as a directory or represents a package. Reordering must retain the listed URL identity and apply the pane's current settings after an asynchronous read completes.

Name groups folders first; Modified compares raw timestamps across all kinds. Equal timestamps use ascending natural names, then paths, even in descending date order. Keep this in the existing comparator and filter the sorted listing for visibility; [A30](../specs/001-mvp/spec.md#breadcrumbs-and-sorting) owns the accepted rule. Kind grouping remains deferred.

Sample the current wall clock when rendering relative date labels. A minute timeline's context date can precede timestamps loaded by Refresh, briefly sending just-modified items into the future-date fallback. Keep the timeline for ageing labels and preserve raw timestamps for sorting.

## Background sorting

Apply a column and direction as one request, then sort an immutable snapshot away from the main actor. Retain the displayed rows while sorting. Publish only the latest sort; publishing a new listing invalidates sorts of the previous listing. If settings change while a loaded listing is being sorted, sort it again with the current settings before publishing its directory and rows together. Keep the existing navigation request guard across that extra asynchronous boundary.

A superseded worker can finish, but its result is discarded. Controlled completion-order tests cover these races; an optimised large-list probe checks UI-actor responsiveness without a timing threshold in the test suite. See [T03 evidence](../validation/t03-sorting-hidden-visibility.md#sorting-performance-follow-up-2026-10-06).

## Hidden visibility and Refresh

The core listing reads all immediate entries, including dot-prefixed and filesystem-hidden items. Each pane stores that sorted listing once and filters its exposed entries using its own visibility setting. Toggling uses the cached listing; new files or changed hidden flags appear after Refresh or navigation. No filesystem watcher is installed.

Refresh reuses navigation's latest-request/error handling and preserves sort/visibility settings. Shared actions capture the focused pane before starting asynchronous work. Selection is pane-owned and URL-based: retain surviving visible identities through sorting/Refresh and prune rows that become hidden or disappear. [T03 evidence](../validation/t03-sorting-hidden-visibility.md#unit-2-hidden-visibility-and-refresh) covers the native selection seam.

## Selection and primary item

Each pane owns one selected URL set and an explicit primary URL. Details derives its item from the focused pane; list-local state records only the last interaction for native keyboard endpoint reporting. Do not choose a primary from unordered set iteration. Reconcile selection when the latest successful listing is published or visibility changes, using [A19](../specs/001-mvp/spec.md#multiple-selection-and-drag-and-drop).

Keep native list selection for Command/Shift input and Edit → Select All. Report click/keyboard endpoints after native selection has completed, rejecting a deferred endpoint after directory changes. When the keyboard's row disappears, track its surviving visible position so the next range shrink reports the endpoint rather than retaining a fallback primary. A complete visible-list selection uses the same Select All behaviour, retaining the primary. Programmatic pruning must not change pane focus; do not focus panes from a general selection-change observer. Return/double-click navigation requires one selected directory rather than choosing an arbitrary item from a multiple selection.
