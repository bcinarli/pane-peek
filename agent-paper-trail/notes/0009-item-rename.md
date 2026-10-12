# Item rename

Status: Active

Reuse ItemName's literal filename rules. Capture the listed entry and containing directory identity without resolving the final link component. Preflight occupied names, including dangling links and distinct hard links; commit with same-directory `renameatx_np` and `RENAME_EXCL`. The exclusive operation prevents destination overwrite, including a collision arriving after preflight. Case-only aliases follow the filesystem's rules. An unsupported exclusive operation reports an error; there is no overwrite fallback.

Resolve affected dirty documents only after name/collision preflight. Rename-specific Discard is deferred until mutation succeeds, retaining the draft and document identity on failure. Block edits and Save on affected paths while the decision/mutation is pending. Successful Save replaces the inode: recapture against the saved TextFileSnapshot rather than accepting whatever now occupies the path. The checks do not lock other applications out of simultaneous namespace changes.

Close affected writable previews before applying successful rename results, even when the subsequent listing read fails. Reload selected results with a fresh baseline. Rebase cached directory/entry/selection paths first so failed Refresh retains a usable new location; preserve newer unrelated navigation and its request ID. Pending directory navigation records its canonical intended location before the read, so an ancestor rename can invalidate an alias read and follow the new path. Renaming a directory link does not relocate a browser already at its canonical target.

Keep creation's dot-name visibility rule specific to creation. Rename retains existing pane visibility; A19 prunes a renamed item that becomes hidden. Preserve native context-target completion before menu tracking, and disable Rename for multiple items or unavailable/hidden targets.

Recompute the renamed entry's hidden state at its destination, preserving independent filesystem metadata rather than retaining the old dot-name flag. Re-sort rebased cached rows through the existing background sorter before a fallible Refresh. Include a changed fallback even when a newer unrelated navigation means no rename-triggered refresh should run.

Keep the filename draft on BrowserState so selection/navigation can finish rename before changing targets. Share an in-flight submission when Return and a selection transition converge. Resume only after success; rebase a requested renamed-folder path. Unrelated native blur cancels filename entry while retaining the document draft. Native retry must reuse an active field editor: makeFirstResponder on that editor can end editing and look like cancellation. Keep Return/Escape local to the field and restore list focus after it closes. File double-click uses the same editor; verify its captured row is still the sole accepted selection before preparing rename, especially after a dirty selection was rejected.

[T09 evidence](../specs/001-mvp/evidence/rename-affected-document-handling.md) owns executed checks and pending manual review. Cross-window coordination remains T16.
