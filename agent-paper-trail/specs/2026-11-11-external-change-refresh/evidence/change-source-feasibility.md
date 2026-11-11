---
task: change-source-feasibility
verdict: Pending
closed: ""
---

# Change-source feasibility

FSEvents with file-level events is the selected change source. A file-descriptor `DispatchSource` on the directory misses in-place writes and permission changes to its entries, and one on a file stops reporting after an atomic replacement; path-based FSEvents reports creation, in-place writes, metadata changes, rename, removal, atomic replacement and root rename. FSEvents reports resolved, current on-disk paths and nested-folder events, so targets are canonicalised and filtered to the directory and its immediate entries or to the single file, matching case-insensitively unless the volume is case-sensitive; dropped-event and root-change flags always report.

`ChangeWatch` coalesces raw signals on a monotonic clock, notifying 200 ms after the latest signal with the deadline capped 1 s after the first, releases its registration on cancellation or release and rejects signals queued after cancellation. A location that cannot register keeps manual Refresh. FSEvents delivered external changes to an ad hoc–signed sandboxed probe watching its own container. [PR #191](https://github.com/bcinarli/pane-peek/pull/191).

No UI changes; accessibility checks are unaffected by this unit. Limits: security-scoped user-selected folders, cloud-backed folders, mounted and network volumes, and sleep/wake remain unverified in the signed sandbox review app. A network volume can register but not report remote changes; detecting that honestly belongs to [browser listing refresh](../plan.md#browser-listing-refresh). Recognising PanePeek's own operations is left to consumers: listing reloads compare with the current listing, and Details compares the disk snapshot with the loaded `TextFileSnapshot`.
