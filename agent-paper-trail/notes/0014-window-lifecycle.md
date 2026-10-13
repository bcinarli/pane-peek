# Window lifecycle and prompts

Status: Active

Pass the application delegate instance into each browser window. Keep a window-owned prompt presenter alongside its browser state, and bind it through the attached native guard. Capture the weak native owner before deferring a sheet; a later window registration must not redirect a prompt or accessibility announcement. Detachment and close remove that window's lifecycle registration and prompt binding while retaining native delegate forwarding.

Associate each registration with the installing native delegate proxy. Old-guard cleanup must not remove a replacement guard's registration or prompt binding. A replacement forwards directly to the platform delegate rather than retaining a chain of obsolete proxies; this preserves native activation/lifecycle callbacks after dismantling the old view.

Use `WindowGroup` for native New Window creation. Each `BrowserWindow` retains its own browser, prompts and Details sizing through SwiftUI State; favourites and the operation coordinator remain app-owned. Fresh windows start with home panes, two-browser mode and compact Details. Disable [system scene restoration](https://developer.apple.com/documentation/swiftui/scenerestorationbehavior) so it cannot restore all previous windows; the accepted one-configuration restoration policy is implemented separately in T17.

Quit snapshots every registered document and resolves dirty choices sequentially. Apply Discard only after every window agrees. A later Cancel, failed Save or changed document/window registration aborts Quit while retaining pending drafts. Successful earlier Saves stay on disk. Reject stale/duplicate answers and revalidate buffers using exact UTF-8 bytes: Swift String equality treats different Unicode encodings as equivalent.

Reuse the existing Save implementation for same-file conflicts. The second window retains its draft when the first changes the disk version; native document identity and undo are preserved by the existing preview state. New Window must follow shared mutation and affected-document safeguards. [T16 evidence](../specs/001-mvp/evidence/independent-windows-shared-operation-coordination.md) owns automated/native checks and pending manual acceptance.
