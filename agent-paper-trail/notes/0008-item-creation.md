# Item creation

Status: Active

Creation validates one literal filename without trimming, appending an extension or normalising spelling. On macOS, reject empty names, `/`, NUL, `.` and `..`; spaces, Unicode and backslashes remain valid. Collision checks belong to the filesystem: use exclusive `open` for text files and `mkdir` for folders. An existence preflight alone races and can miss dangling symlinks. Both operations reject occupied destinations and respect filesystem case rules and the process umask.

Bilal approved the [A24](../specs/001-mvp/spec.md#file-management) dot-name policy on 2026-10-11: successful creation enables Show Hidden Files only in the creating pane. Failed creation leaves visibility unchanged. This avoids a separate visibility exception for the new item.

Capture the pane identity and directory before the name prompt; resolve dirty drafts before prompting. Recheck visibility, location and draft state at submission. Completion refreshes only panes still displaying the captured directory, selects the result only in the creating pane and leaves later navigation/focus intact. A draft started while creation runs still uses the existing guard before refreshed selection replaces it. Cancel retains that draft; the already-created item remains on disk.

Distinguish creation failure from successful creation followed by a listing failure. The latter reports the created path and retains the previous usable listing. A delayed SwiftUI sheet-dismissal binding must not clear a result error after submission has already removed the request.

Attach the background menu to the pane's full content shape. The selection-aware List menu did not open on blank space during native checking. Keep the existing row path menu and List primary action intact. [T08 evidence](../specs/001-mvp/evidence/new-text-file-folder.md) owns the checks and acceptance state.
