# Drag and drop

Status: Active

Receive actual local file URL pasteboard items, preserving their order and listed link paths. Reject the whole payload when an item is unsupported, non-local or duplicated; filtering with a file-URL-only pasteboard reader could silently accept a subset. Empty/localhost hosts are local; credentials, ports, query/fragment suffixes and service URLs are rejected. Promised files are outside the receiving path.

Use [AppKit's source operation mask](https://developer.apple.com/documentation/appkit/nsdragginginfo/draggingsourceoperationmask) alongside current Command state. Default copy needs copy permission; Command requests permitted move, with copy retained for a copy-only source. Unsupported operations return no drop. Drop onto the whole receiving browser, including over a folder row, because the destination is its current directory.

Reserve the transfer and capture source URLs/destination synchronously before returning to the drag event loop. Reuse the same copy/move execution, dirty guards, outcome reporting and refresh as context actions. Native acceptance means the request was queued; confirmation, dirty cancellation or a filesystem error can still prevent mutation. Never turn queue acceptance into a successful filesystem outcome.

An incoming move has no source listing entries. Read completed destination metadata off the UI thread for cached recovery, retaining package and listed-link distinctions if later Refresh fails. Existing context moves retain their captured listing metadata. Shared cross-window coordination remains T16; live Finder negotiation and accessibility acceptance are recorded separately in [T13 evidence](../specs/001-mvp/evidence/drag-and-drop-finder.md).
