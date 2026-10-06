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

Refresh reuses navigation's latest-request/error handling and preserves sort/visibility settings. Shared actions capture the focused pane before starting asynchronous work. Native selection remains URL-based: keep a visible URL through sorting/Refresh, and clear it when the row becomes hidden or disappears. [T03 evidence](../validation/t03-sorting-hidden-visibility.md#unit-2-hidden-visibility-and-refresh) covers the native selection seam.
