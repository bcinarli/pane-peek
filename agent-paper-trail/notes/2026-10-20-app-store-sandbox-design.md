# App Store sandbox and file access

Status: Active

## Access model

Distributed GitHub and App Store builds will share explicit folder grants and security-scoped bookmarks under the [production sandbox decision](../decisions/2026-10-20-production-sandbox-distribution.md). GitHub retains Developer ID signing and notarisation; Store signing and submission remain separate. Production packaging uses the shared sandbox access model; acceptance, final-candidate validation and publication remain separate gates.

Apple [requires App Sandbox for Mac App Store distribution](https://developer.apple.com/documentation/security/app-sandbox). [Review guideline 2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility) also requires Xcode-provided packaging and submission technologies. Notarised DMG/ZIP downloads do not establish Store compatibility.

File-access constraints:

| Area | Constraint |
| --- | --- |
| [Navigation and startup](../../sources/panepeek-core/BrowserState.swift) | Navigation requires a grant before filesystem reads. Account Home comes from the account record because Foundation redirects current-account Home into the app container. |
| [Favourites](../../sources/panepeek-core/Favourites.swift) and [restoration](../../sources/panepeek/WindowRestoration.swift) | Stored paths carry corresponding bookmarks. Legacy paths supply reconnection hints only. |
| [Safe saving](../../sources/panepeek-core/TextFileSnapshot.swift) and file operations | Parent-directory access is needed for sibling staging, rename and recovery. Access must outlive the initiating pane or window when work continues. |
| [Finder imports](../../sources/panepeek/FileDrop.swift) | Reconstructed path URLs lose the native access representation. File permission does not imply permission to modify its parent. |

## Folder permission

Use **Allow Home Folder** through a native folder chooser, with **Open Folder** for narrower access. New grants cover browsing, text editing and file operations. Existing read-only bookmarks retain their capability until an explicit containing-folder upgrade. A Home grant preserves fresh windows' two-pane Home default. Choosing another folder opens that selection in the focused pane without redefining Home. Making an arbitrary folder the new-window default would change A26.

Every navigation route checks access before reading. A delayed chooser response belongs to its captured pane and request; it cannot redirect newer navigation. Cancel retains the last successful listing and any draft. Without an authorised starting directory, the window shows permission guidance. Home fallback requires an existing Home grant.

Desktop, Documents and Downloads prompts are separate [macOS privacy controls](https://support.apple.com/guide/security/controlling-app-access-to-files-secddd1d86a6/web). A selected folder extends sandbox access to descendants, subject to [other filesystem and privacy restrictions](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox). Home selection does not grant Full Disk Access or guarantee that those prompts disappear.

## Access lifetime and saved locations

One app-owned access store shares granted URLs and bookmarks across windows. Permission UI belongs in the app layer; filesystem services use acquired access through their existing boundaries. Access ownership is separate from mutation exclusion.

Retain native chooser URLs. Balance successful [security-scope acquisition and release](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource()), including cancellation and errors. Keep the grant URL alive when workers use derived paths. Match roots by path components and available identity without probing unauthorised locations; the OS remains the access authority.

Home, favourites and remembered directories reference bookmarks stored in the app container. Resolve the bookmark to its current location and verify its saved file/volume identity before reading. A replacement at the old path must require reconnection. Refresh stale data while access is active. Unresolved or offline records remain available for reconnection; inaccessible favourites remain removable. Never replace their saved locations with a fallback or log bookmark bytes.

Each consumer retains access for its own lifetime. This includes hidden panes, captured operations through recovery/refresh, and video or Quick Look until teardown. Copy retains source access until clipboard replacement; pending Cut retains it through completion or replacement; outgoing drag retains it through native completion. Closing a window, changing directory or removing a favourite cannot revoke another consumer's access. Release active scopes when the last consumer finishes. Retain bookmark data for saved locations.

## File operations and links

| Action | Required access |
| --- | --- |
| Listing and preview | Read the selected directory/item. External link targets need their own access. |
| Create or Save | Read/write containing directory, covering temporary siblings and cleanup. A file-only grant does not cover the current atomic Save algorithm. |
| Copy | Read source and source-parent metadata; write destination and replacement staging. |
| Rename, Move or Trash | Read/write source parent and affected contents as required. Move also needs destination access through source removal and cleanup. |
| Finder transfer | Native file objects plus the same operation requirements. Reject mixed unsupported payloads in full. |

Directory navigation retains [canonical target behaviour](../decisions/0005-finder-directory-symlink-navigation.md). Read a link under its parent grant before requesting target access. [Listing classification](../../sources/panepeek-core/DirectoryListing.swift) must tolerate unavailable target metadata without prompting or treating an unknown directory link as a file-rename gesture. Preview recovery must keep link editing disabled. Transfers, rename and Trash affect the listed link itself.

[Native pasteboard file objects](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DragandDrop/Tasks/DraggingFiles.html) preserve access information that path strings cannot carry. Existing captured destinations, dirty-draft protection and partial-result handling remain binding. Trash failure must never fall back to permanent deletion.

## Capabilities and limitations

Production and review capabilities are App Sandbox, [user-selected read/write](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write) and [app-scoped bookmarks](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access), with the [WebKit network-client capability](../decisions/2026-10-20-webkit-sandbox-capability.md). The executable-saving entitlement remains excluded. [Apple documents its effect on newly written executables](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html); [Apple DTS leaves its applicability to folder-granted transfers uncertain](https://developer.apple.com/forums/thread/811450?answerId=871171022). Preserve executable permissions without adding code execution or stripping quarantine.

Ordinary atomic Save carries existing quarantine to its private staging file using opened descriptors. Sandbox Save leaves quarantine to macOS because direct metadata writes can be denied. Sandbox Copy, Move and Save may regenerate quarantine provenance; exact metadata equality and compatibility of every executable type are not established.

The [WebKit capability decision](../decisions/2026-10-20-webkit-sandbox-capability.md) permits outgoing connections at the OS level so local SVG/HTML rendering can start; renderer policies block remote preview resources and scripts. HTML reads local CSS/images/fonts through the bounded [asset policy](../decisions/2026-10-20-html-local-assets.md), retaining the containing-folder grant. Apple Events and broad filesystem exceptions remain excluded. [Privileged file operations](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.security.privileged-file-operations) require separate entitlement approval and are not assumed necessary for ordinary granted operations.

- Sandbox builds support capability-aware folder grants and bookmark-backed window restoration. Each remembered directory has its own bookmark so renames do not rely on stale path strings. Favourites support saved access and explicit reconnection without replacing a different saved folder. Read-only text, highlighting, Markdown, image thumbnails, video playback and item metadata retain access through pending reads and playback teardown. Video streams from one opened file so path replacement cannot redirect later reads. Quick Look retains access through native preview items and uses file references to preserve the opened item across path replacement. Text editing uses read/write containing-folder access through atomic Save and retains drafts and unchanged editor state across refresh. File operations retain captured source/destination grants through naming, collision/draft decisions, mutation and recovery/refresh. Clipboard and drag transfers preserve native file references and capture the receiving grant before suspension. Incoming source parents require read access for Copy and write access for Move, with identity checks across permission choices. Finder handoffs retain captured access and reveal listed links without following their targets. File-link content remains unavailable.
- Sandbox builds require stable file and volume identifiers; locations without them are unsupported. Whole-app sandbox compatibility remains unverified, including [protected-folder prompts](0004-protected-folder-permissions.md), external links, delayed Finder transfers, physical removable media and network volumes. Cross-volume operations and recoverable Trash have been exercised on a separately mounted APFS image; this does not establish physical-media or other-filesystem compatibility.
- Automatic preference migration is outside scope. Manual setup of favourites, layout and remembered folders is acceptable; legacy locations need explicit folder grants. Production uses its existing identity, while isolated trials use a separate review identity/container. Browsed files stay in their original locations. New sandbox settings and grants must persist after relaunch.
- Store signing and provisioning, packaging/upload and listing requirements remain separate from file-access compatibility.
- The [1.0.0 acceptance waiver](../decisions/2026-10-19-mvp-release-acceptance-waivers.md) does not establish Store acceptance. App Review approval remains external to sandbox validation.
