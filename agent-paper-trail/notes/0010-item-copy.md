# Item copy

Status: Accepted

Copy captures canonical containing/destination directories while retaining the final source link. Preflight rejects occupied destination names, including dangling links, and resolves directory ancestry without treating a link as its target. Revalidate source and directory device/inode/type identities before the background Foundation copy. Known conflicts cause no mutation; a late destination collision is rejected without overwrite or folder merge. This does not freeze a hierarchy against simultaneous changes by other applications.

A failed copy can leave a destination item. Report its path as potentially incomplete and require inspection before retrying; do not claim rollback or successful completion. Refresh failures after a successful copy retain the successful filesystem outcome. Batch execution stops at the first failure and reports completed destination paths, the failed source and unattempted sources. Completed copies remain in place.

A batch captures the displayed selection and preflights all items before a dirty prompt, then revalidates the whole request before its first write. Each item also revalidates at its execution boundary. Pending destination names follow the volume’s reported case sensitivity; occupied names use the filesystem check. A missing case-sensitivity value does not justify assuming case-insensitivity. External changes during execution can still produce a partial outcome.

Affected source documents use Save/Discard/Cancel before any batch item is copied. The edit lock covers the union of selected sources and selected directory descendants, while unrelated documents remain editable. Explicit Save changes the inode, so accept only the saved TextFileSnapshot baseline for that selected item, then restore the affected edit lock through execution. Copy does not relocate the source. Discard follows the existing document transition behaviour; source-path rebasing and rename-specific deferred Discard do not apply.

Completion refresh preserves a still-selected dirty document rather than prompting solely because its parent listing changed. A changed/pruned primary still uses the existing guard. Refresh only matching captured navigation requests, preserving later navigation/focus and independent sort/visibility settings, including hidden browser state. Layout changes cannot redirect a submitted copy; new single-pane or stale-selection requests remain rejected. Cross-window coordination remains T16.

The existing native row menu supports Shift-F10 while its table is focused. Copy uses the same context targeting and full selected-set recheck as pointer activation; row accessibility actions provide an additional native alternative. [T10 evidence](../specs/001-mvp/evidence/copy-to-other-pane.md) owns executed checks and Bilal’s acceptance of both presented manual/accessibility scopes.
