# Item Trash

Status: Active

Capture the source and canonical parent identities while retaining the final listed link. Revalidate before the background system Trash call; reject a listed item whose file/directory/link type changed before capture. Files, directories, packages and broken links are supported. Trash failures never enter a permanent-deletion fallback. External namespace changes are not locked out by these checks.

Confirm before resolving affected dirty documents. Reuse Save/Discard/Cancel; defer Discard until the source actually leaves its old location. Save replaces an inode, so accept only the saved document's verified baseline. Lock affected editing/Save through confirmation and execution; preserve unrelated drafts. An error after the source disappeared remains a failure, reports the changed path and still reconciles obsolete previews/listings.

Prune cached source rows and close affected previews before fallible Refresh. Invalidate affected pending parent/descendant reads. A browser inside the trashed directory tries its parent and then higher ancestors until accessible, explaining recovery. Preserve newer unrelated navigation, independent sort/visibility and hidden-browser state. If that newer request is still pending while the displayed directory is trashed, load a usable cached fallback without changing the request identity; its failure must not leave an inaccessible fallback location. Trashing a directory link does not relocate a browser at its canonical target.

Capture the whole selection in displayed order and reject missing, changed or stale-type items before confirmation. Revalidate every captured source again before the first Trash call, then each source at its execution boundary. Stop on the first failure; report successful source paths, the failed source and unattempted paths. Completed items are not rolled back. Track disappeared sources separately from confirmed successes so a failed item can trigger recovery without being reported as completed.

Lock the union of selected files and directory descendants. Resolve the affected dirty document before any item is trashed; Save recaptures only that selected file against its saved baseline. Saving a descendant retains its containing folder's identity. After partial execution, close/discard only a document whose source actually disappeared; failed and unattempted dirty documents keep their drafts. Apply all removed items to cached panes before asynchronous sorting/Refresh, retaining structured outcomes when Refresh fails.

[T12 evidence](../specs/001-mvp/evidence/delete-to-trash.md) owns the checks, acceptance and publication state. Both units are accepted; individual native/accessibility outcomes remain unreported. Shared cross-window coordination remains T16.
