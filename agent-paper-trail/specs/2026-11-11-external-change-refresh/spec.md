---
status: Proposed
date: 2026-11-11
supersedes: []
superseded_by: ""
---

# External change refresh specification

## Scope

Reflect external filesystem changes in visible browsers and Details through the existing listing and preview paths. Once accepted, this package owns the automatic watching that [A4](../001-mvp/spec.md#directory-panes) defers and the external-change reconciliation [A21](../001-mvp/spec.md#multiple-selection-and-drag-and-drop) leaves to Refresh. Manual Refresh, transfer refreshes and their guards remain unchanged.

Watch only the directory displayed by each visible browser and the file whose content Details shows. Exclude recursive watching, search indexing, content search, Git status refresh, merging external changes into a draft and any change to file-access, sandbox or network boundaries. The [Git and agent worktrees spec](../2026-10-27-git-worktrees/spec.md) can reuse the change signal for its status refresh through its own review.

Automatic refresh is always on and has no setting. Manual Refresh remains available for reconciliation.

## Browser listings

An external creation, removal, rename or metadata change in a displayed directory updates that browser's listing. Reuse the existing reload behaviour: retain sort field and direction, hidden-file visibility, column widths and scroll position, and keep surviving selected identities and the primary item. Removed or newly hidden selected items follow the existing selection reconciliation. Automatic refresh does not add history visits, move keyboard focus or interrupt an inline rename; a rename in progress keeps its field and applies the update when it ends.

A displayed directory that is removed, renamed or becomes inaccessible keeps the last usable listing and shows the existing unavailable state. It does not navigate elsewhere.

An active recursive search is not watched or rerun. Its results keep their current behaviour until the query changes, the search ends or the user chooses Refresh. Details for a file selected from search results follows the Details rules below.

## Details

When the previewed file changes on disk and has no draft, reload it through the existing preview load in its current mode, retaining the scroll position where the content allows. This applies to text, Markdown, SVG, HTML, image, video and PDF previews. A video that was playing stops and returns to the paused state. A removed or replaced-by-another-type file shows the existing unavailable or selection outcome.

When a draft exists, never replace the draft, dirty state, selection, scroll position or Undo history. Show a short, non-modal changed-on-disk notice in Details while the saved file differs from the draft's baseline. Discarding the draft while the notice is shown loads the disk version directly, without a separate Refresh. Save keeps its existing conflict check and failure message. The notice clears when the draft is discarded or the saved file returns to the draft's baseline. A saving document ignores its own write.

Changes caused by PanePeek's own Save, transfers, rename and Trash keep their existing refresh and recovery paths and must not produce a duplicate reload or a changed-on-disk notice.

## Coalescing and lifecycle

Coalesce bursts of changes into bounded, debounced refreshes per browser and per Details document. Listing and preview work stays off the main thread, cancellable and subject to existing stale-result rejection. A burst must not cause visible flicker, lost focus or interrupted typing.

Watchers follow browser identity through layout changes, navigation, Back/Forward, window restoration and window close. Hidden browsers, closed windows and departed directories hold no watchers. Returning to the foreground reconciles the visible browsers and Details once, covering events missed while the app was inactive or the source was unavailable.

The change source must work with security-scoped access in the signed sandbox build, atomic-replace saves by other tools and paths backed by OS-managed cloud storage or mounted volumes. Where a volume cannot report changes, the browser keeps manual Refresh and foreground reconciliation; it never presents a stale listing as current.

## Accessibility

Automatic refresh does not move focus or announce routine listing changes. The changed-on-disk notice is reachable by keyboard and announced once to VoiceOver when it appears. Existing accessibility for listings, Details and unavailable states remains binding.

## Acceptance criteria

| ID | Outcome |
| --- | --- |
| E1 | External creation, removal, rename and metadata changes in a displayed directory update its listing in either pane and across windows without Refresh. |
| E2 | Automatic refresh retains sort, hidden-file visibility, column widths, scroll position, surviving selection and focus, adds no history visit and does not interrupt inline rename. |
| E3 | A clean previewed document reloads after an external change in Preview and Edit across supported preview types; removed and unsupported outcomes use existing states. |
| E4 | A dirty or saving document keeps its draft, dirty state and Undo; a non-modal changed-on-disk notice appears, Discard loads the disk version and Save conflict handling is unchanged. |
| E5 | PanePeek's own operations produce no duplicate reload or notice; bursts are coalesced, cancellable and stale-safe without flicker or interrupted typing. |
| E6 | Watchers are released for hidden browsers, closed windows and departed directories; foreground return reconciles missed changes; unsupported volumes fall back honestly. |
| E7 | Behaviour holds in the signed sandbox build with existing grants and no new entitlement, including atomic-replace saves and cloud-backed folders. |
| E8 | Affected keyboard, VoiceOver and focus behaviour satisfies the native baseline; idle and burst resource use are measured against the previous build. |

[Validation](validation.md) owns verdicts; accepted scope does not establish implementation or native acceptance.
