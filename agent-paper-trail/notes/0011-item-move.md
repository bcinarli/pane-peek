# Item move

Status: Active

Move reuses copy's captured source/directory identities, collision checks, final-link preservation and ancestry preflight. A same-volume move commits with exclusive rename. Only a cross-device result enters copy/remove; other rename errors retain the source and surface the failure.

Cross-volume copy uses a private, exclusively created staging directory on the destination volume. Publish the copied item with exclusive rename, then verify its identity and the original source before source removal. A late destination winner or a replaced published copy is never removed as cleanup. Cleanup checks the staging directory's captured identity and reports its path on failure.

Source-removal failure retains the complete destination. Removing a folder can fail after deleting some source children, so report that possible partial state and keep the destination copy. A cleanup error after source removal still carries the relocation result for preview/listing recovery. Multi-step transfers do not lock out other applications or guarantee a transaction.

Capture before move confirmation. Resolve affected dirty documents only after confirmation; Discard is deferred until the source is removed. Save accepts only the saved document's verified baseline. Failed or cancelled moves retain unresolved drafts, and unrelated documents remain editable. Existing Save conflict checks reject missing/replaced paths after partial source removal.

Close affected previews before applying relocation, including when cleanup or subsequent Refresh fails. Prune obsolete source rows, add the destination fallback and rebase browsers already inside the moved directory. Invalidate pending reads for affected parents/descendants before sorting or refreshing. Preserve unrelated newer navigation, focus and independent sort/visibility settings.

Batch capture retains displayed selection order and rejects every known name/type/ancestry conflict before confirmation. Reuse copy's whole-request validator again before the first move, then revalidate each item at its execution boundary. Stop on the first failure; report completed destinations, the failed source and unattempted sources without rollback. A source removed before cleanup failed still appears among completed moves and in the failure detail.

Lock the union of selected sources and directory descendants. Save recaptures the matching selected file against its saved baseline; saving a child keeps its containing folder's captured identity. After partial execution, apply Discard/preview closure only for the document whose source was actually moved. A failed or unattempted dirty item retains its draft even when an earlier item moved successfully. Apply every completed relocation to cached panes before asynchronous sorting/Refresh, retaining structured outcomes through Refresh failures.

The native row menu and Shift-F10 use the same captured-set guard for one or many items; single-pane mode still disables Move. Confirmation shows the item count, a selectable scrollable source-path list and the captured destination. The shared transfer status retains errors and announces results through native accessibility. [T11 evidence](../specs/001-mvp/evidence/move-to-other-pane.md) owns executed checks, Unit 1 acceptance and pending Unit 2/native review. Shared cross-window coordination remains T16.
