# Window lifecycle and prompts

Status: Active

Pass the application delegate instance into each browser window. Keep a window-owned prompt presenter alongside its browser state, and bind it through the attached native guard. Capture the weak native owner before deferring a sheet; a later window registration must not redirect a prompt or accessibility announcement. Detachment and close remove that window's lifecycle registration and prompt binding while retaining native delegate forwarding.

Quit snapshots every registered document and resolves dirty choices sequentially. Apply Discard only after every window agrees. A later Cancel, failed Save or changed document/window registration aborts Quit while retaining pending drafts. Successful earlier Saves stay on disk. Reject stale/duplicate answers and revalidate buffers using exact UTF-8 bytes: Swift String equality treats different Unicode encodings as equivalent.

Reuse the existing Save implementation for same-file conflicts. The second window retains its draft when the first changes the disk version; native document identity and undo are preserved by the existing preview state. New Window must follow shared mutation and affected-document safeguards. [T16 evidence](../specs/001-mvp/evidence/independent-windows-shared-operation-coordination.md) owns automated/native checks and pending manual acceptance.
