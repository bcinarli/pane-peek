---
status: Accepted
date: 2026-10-16
supersedes: [0001-product-boundaries.md]
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

### [Changed] 2026-10-16: browser Size column

Bilal added a ninth refinement: browser columns in Name | Size | Modified order. Show regular-file sizes from listing metadata, with an accessible unknown fallback. Show `-` for directories rather than recursively scanning their contents; filesystem directory-entry size is not the contents' total. Preserve current Name/Modified sorting, row identity, selection and navigation. This additive scope has its own coding/native review unit after the earlier refinements.

### [Changed] 2026-10-16: searchable, taller Favourites popover

After reviewing the forty-entry scrolling example, Bilal chose to retain the anchored popover, add search by folder name and full path, and increase its height to show roughly six to eight typical rows. Match saved paths locally without filesystem reads or changing their stored order. Preserve wrapping full paths, per-row actions and existing draft/navigation safeguards. Keep the header/search fixed while the results scroll; longer paths, larger text and available screen space can reduce the visible row count. The larger centred-dialog alternative remains unselected. This refinement belongs to Unit 4 and retains its manual-review/commit gates.

### [Changed] 2026-10-16: Move collision choices

Bilal approved a collision-only dialog with Replace, Keep Both and Cancel, implemented in separately reviewed slices: Keep Both/Cancel first, regular-file Replace second. This record supersedes decision 0001’s unconditional rejection of Move name collisions and carries forward its other product boundaries. Copy retains its existing rejection policy. Same-item, duplicate-input and directory ancestry conflicts remain rejected.

Keep Both proposes the first unused numbered name before a file/package extension and permits an exact custom name. Ordinary directory names are numbered as a whole. Resolve every known batch collision before moving any item, reserving proposed destinations against the batch as well as existing files/links. Cancel aborts the batch before movement. Preserve the captured sources/destination, shared locks, unsaved-document choices and partial reporting. Revalidate before mutation; a late collision must never silently overwrite an item.

Replace is accepted direction for regular-file collisions only and retains a later coding/manual gate. Protect affected source and destination drafts, preserve the old destination recoverably until the incoming transfer succeeds and report recovery/partial failures honestly. Folders/packages offer Keep Both or Cancel; no folder merging. A reject-only policy remains simpler but does not satisfy the requested workflow; silent overwrite is unselected.

### [Changed] 2026-10-17: simple success toasts

Bilal requested filename/action text for a successful operation, such as `report.txt moved.`, without an info button or details popup. Use the completed-item count for batches. Retain five-second expiry and the error/partial-failure details and dismissal policy. This simplifies the reviewed Unit 8 presentation; manual acceptance and commit remain separate.

### [Changed] 2026-10-17: Size ordering

Bilal requested ordering by Size within Unit 9. Make Size a per-pane sort control, initially largest first and reversing on subsequent clicks. Compare recorded byte counts numerically, with directory/package/link and unavailable sizes last in either direction; ties use ascending natural names and stable paths. Reuse existing sorting, selection and refresh/navigation state without additional filesystem reads. Keeping Size display-only is simpler but does not meet this addition. Manual acceptance and commit remain separate gates.

### [Changed] 2026-10-18: Copy collisions and horizontal actions

Copy now uses the same collision choices as Move: editable numbered Keep Both, Cancel and explicit Replace for regular files only. This replaces the Copy rejection policy above. Resolve all known batch conflicts before writing, reserve names across the batch and revalidate captured identities after decisions. Copy retains its sources. Protect affected destination drafts and preserve the prior destination recoverably until replacement succeeds; late conflicts never silently overwrite. Folders/packages/links offer Keep Both or Cancel without merging.

Present the collision choices in one horizontal row, ordered Keep Both, Cancel, Replace, retaining the Mauve default action. Use an app-owned native sheet because system three-button alerts choose their own layout. Keep Return for Keep Both, Escape for Cancel, editable-name focus and native accessibility. Keeping the system alert would preserve its vertical layout; private alert hierarchy changes are excluded.

### [Changed] 2026-10-19: consistent confirmation sheets

Use the same app-owned native sheet presentation for unsaved edits and Copy/Move collisions, with the shared adaptive floating surface, horizontal buttons and Mauve default action. Following [Apple's alert guidance](https://developer.apple.com/design/human-interface-guidelines/alerts), place Cancel first and the default action last: Cancel, Discard, Save for edits; Cancel, Replace, Keep Both for replaceable collisions; Cancel, Keep Both otherwise. This replaces the collision-button order above. Return chooses Save or Keep Both; Escape cancels. Preserve editable-name focus, window ownership and first-answer handling.

Keeping the system edit alert preserves its automatic layout but differs from the transfer sheet. Reusing the existing transfer order would keep the default action on the leading side. Shared sheet presentation with a trailing default keeps the two prompts consistent with the native guidance. File-operation and draft-protection behaviour is unchanged.

### [Changed] 2026-10-19: compact menu-bar Favourites labels

Use folder names in both the direct-opening entries and Remove Favourite submenu. Duplicate names receive only enough parent-path context to distinguish their saved locations; unique names stay compact. Keep filesystem root `/` and full-path help/accessibility. Labels derive from saved paths without availability checks or sorting. Always displaying parent paths adds unnecessary width for unique names. The toolbar popover retains its searchable name/full-path rows. [The follow-up plan](../specs/001-mvp/plan.md#favourites-menu-labels-follow-up) and [evidence](../specs/001-mvp/evidence/favourites-menu-labels.md) own implementation and validation.
