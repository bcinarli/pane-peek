# Shared operation coordination

Status: Active

The app delegate owns one `FileOperationCoordinator`, passed into each browser. Mutations and Saves share a single reservation, held across preflight, confirmation, dirty decisions, execution and current-window recovery. This also serialises unrelated mutations. Per-path reservations would allow parallel work but add alias/ancestry/identity coordination; the MVP uses the smaller conservative rule. Navigation and unrelated buffer editing remain available; Save availability is checked separately from editing. Incoming drops reserve synchronously before scheduling execution, and Quit is rejected while work holds the reservation.

Register app browsers when their native guards attach, not during SwiftUI state construction. Standalone core callers register when an operation begins; shared core clients explicitly register their live browsers. Keep weak registry bookkeeping outside Observation. An unused browser constructed during a view update must not invalidate another window's pending operation.

Reuse each captured operation's `affects` predicate so folders include descendants and listed links retain their own identity. Resolve all affected drafts before the first mutation; compare document identity and exact UTF-8 bytes through delayed answers. Authorised Saves retain the shared reservation and update only verified captured source baselines. Copy defers Discard until all windows agree; destructive operations retain drafts until their sources are actually removed. Close only previews for completed/removed sources, including partial outcomes.

Use the same pane recovery functions across all registered browsers, including hidden panes. Apply known path changes and invalidate obsolete reads before fallible refresh; retain newer unrelated navigation. Copy/creation/Save share guarded matching-directory refresh, preserving unrelated drafts. Only the original creating pane selects/reveals its new item. Publish Save completion after shared refresh so guarded transitions resume after the full Save action. Trash recovery explains the fallback in the affected pane and announces it to that window.

One captured outgoing drag holds source edit/Save locks and mutation exclusion. Resolve all affected dirty documents before exporting, then require another native gesture. A matching incoming source set hands off to the shared mutation reservation; compare standardised listed paths without resolving link targets. Mark the source drag as received by PanePeek, preserving Finder Refresh guidance for external gestures. Release the drag on native completion or registry detachment.

[T16 evidence](../specs/001-mvp/evidence/independent-windows-shared-operation-coordination.md#unit-3-2026-10-13) records checks, remaining scope and pending manual acceptance.
