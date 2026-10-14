# Window lifecycle and prompts

Status: Active

Pass the application delegate instance into each browser window. Keep a window-owned prompt presenter alongside its browser state, and bind it through the attached native guard. Capture the weak native owner before deferring a sheet; a later window registration must not redirect a prompt or accessibility announcement. Detachment and close remove that window's lifecycle registration and prompt binding while retaining native delegate forwarding.

Associate each registration with the installing native delegate proxy. Old-guard cleanup must not remove a replacement guard's registration or prompt binding. A replacement forwards directly to the platform delegate rather than retaining a chain of obsolete proxies; this preserves native activation/lifecycle callbacks after dismantling the old view.

Use `WindowGroup` for native New Window creation. Each `BrowserWindow` retains its own browser, prompts and Details sizing through SwiftUI State; favourites and the operation coordinator remain app-owned. Fresh windows start with home panes, two-browser mode and compact Details. Disable [system scene restoration](https://developer.apple.com/documentation/swiftui/scenerestorationbehavior) so it cannot restore all previous windows. [T17](../specs/001-mvp/evidence/remembered-directory-pair.md) implements the accepted one-configuration policy; its single unit was accepted overall on 2026-10-14, with individual native/accessibility outcomes unreported.

Quit snapshots every registered document and resolves dirty choices sequentially. Apply Discard only after every window agrees. A later Cancel, failed Save or changed document/window registration aborts Quit while retaining pending drafts. Successful earlier Saves stay on disk. Reject stale/duplicate answers and revalidate buffers using exact UTF-8 bytes: Swift String equality treats different Unicode encodings as equivalent.

Reuse the existing Save implementation for same-file conflicts. The second window retains its draft when the first changes the disk version; native document identity and undo are preserved by the existing preview state. New Window must follow shared mutation and affected-document safeguards. [T16 evidence](../specs/001-mvp/evidence/independent-windows-shared-operation-coordination.md) owns automated/native checks and pending manual acceptance.

## Remembered configuration

The app-owned restoration store writes one `rememberedWindow` dictionary. `directories` follows `presentationOrder`; the latter retains `left`/`right` identities across side changes. `mode`, `activeBrowser` and `detailsWidth` complete the snapshot. A directory-only dictionary defaults the absent layout fields. Invalid fields default independently; unavailable paths are checked through existing asynchronous navigation, with home fallback and a shared status message that remains visible for hidden browsers.

Claim restoration once from the retained browser's startup task, not a SwiftUI view initializer. Do not publish until both initial reads finish; a newer window activation or navigation must win. Track only the last-active registered window, snapshot synchronously before its final close, and retain the stored value after unregistering. Observation callbacks carry registration tokens so an obsolete guard cannot publish or rearm after replacement. Quit prompt activation does not change the remembered owner.

Restore the validated preferred width directly, then let existing native constraints clamp it. User-drag clamping must not replace it during restore. Persist neither expansion nor browser-divider proportions, and do not restore selection, sorting, hidden visibility, scroll or editor buffers.
