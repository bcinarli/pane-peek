# Shared operation coordination

Status: Active

The app delegate owns one `FileOperationCoordinator`, passed into each browser. Mutations and Saves share a single reservation, held across preflight, confirmation, dirty decisions, execution and current-window recovery. This also serialises unrelated mutations. Per-path reservations would allow parallel work but add alias/ancestry/identity coordination; the MVP uses the smaller conservative rule. Navigation and unrelated buffer editing remain available; Save availability is checked separately from editing. Incoming drops reserve synchronously before scheduling execution, and Quit is rejected while work holds the reservation.

Register app browsers when their native guards attach, not during SwiftUI state construction. Standalone core callers register when an operation begins; shared core clients explicitly register their live browsers. Keep weak registry bookkeeping outside Observation. An unused browser constructed during a view update must not invalidate another window's pending operation.

Reuse each captured operation's `affects` predicate so folders include descendants and listed links retain their own identity. Resolve all affected drafts before the first mutation; compare document identity and exact UTF-8 bytes through delayed answers. Authorised Saves retain the shared reservation and update only verified captured source baselines. Copy defers Discard until all windows agree; destructive operations retain drafts until their sources are actually removed. Close only previews for completed/removed sources, including partial outcomes. Matching-pane/path recovery and drag handoff have separate review units.

[T16 evidence](../specs/001-mvp/evidence/independent-windows-shared-operation-coordination.md#unit-2-2026-10-13) records checks, remaining scope and pending manual acceptance.
