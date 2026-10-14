# Drag and drop

Status: Active

Receive actual local file URL pasteboard items, preserving their order and listed link paths. Reject the whole payload when an item is unsupported, non-local or duplicated; filtering with a file-URL-only pasteboard reader could silently accept a subset. Empty/localhost hosts are local; credentials, ports, query/fragment suffixes and service URLs are rejected. Promised files are outside the receiving path.

Use [AppKit's source operation mask](https://developer.apple.com/documentation/appkit/nsdragginginfo/draggingsourceoperationmask) alongside current Command state. Default copy needs copy permission; Command requests permitted move, with copy retained for a copy-only source. Unsupported operations return no drop. Drop onto the whole receiving browser, including over a folder row, because the destination is its current directory.

Reserve the transfer and capture source URLs/destination synchronously before returning to the drag event loop. Reuse the same copy/move execution, dirty guards, outcome reporting and refresh as context actions. Native acceptance means the request was queued; confirmation, dirty cancellation or a filesystem error can still prevent mutation. Never turn queue acceptance into a successful filesystem outcome.

An incoming move has no source listing entries. Read completed destination metadata off the UI thread for cached recovery, retaining package and listed-link distinctions if later Refresh fails. Existing context moves retain their captured listing metadata. Shared cross-window coordination remains T16; live Finder negotiation and accessibility acceptance are recorded separately in [T13 evidence](../specs/001-mvp/evidence/drag-and-drop-finder.md).

Outgoing drags capture the accepted displayed selection before providing native file URL writers. Retain a row-to-URL snapshot through subsequent sorting/navigation, and reject partial or stale native row sets. Share the captured file/folder/package scope with preview edit locks; listed symlinks do not lock their targets. Context mutations stay blocked while the source drag is active, but its local receiver can still use the existing transfer flow. Release locks both at native session end and when row-drag preparation never starts a session.

AppKit source callbacks are synchronous. Resolve affected dirty drafts through the existing Save/Discard/Cancel guard before exporting any writer, then require a fresh gesture after successful Save/Discard. Never start a native session using the mouse event that preceded a sheet. Failed Save or Cancel retains the draft and exports nothing; status tells Bilal to retry once edits are resolved.

Advertise copy/move permission for selected file URL sources. Finder controls outgoing filesystem behaviour; the source end callback only releases locks and requests manual Refresh. It must not remove files, infer success from a returned drag operation or automatically reload dirty documents. Same-window receiving requests record their local handoff so the external-Refresh notice does not obscure their transfer outcome. Cross-window source/dirty/refresh coordination still belongs to T16.
