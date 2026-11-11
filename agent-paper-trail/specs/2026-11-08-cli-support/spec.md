---
status: Draft
date: 2026-11-08
supersedes: []
superseded_by: ""
---

# CLI and native path opening specification

## Scope

Native behaviour, the CLI command contract and the shell-bootstrap/shared-executable design are accepted. Production integration, distribution acceptance and setup retain their task gates.

Support [#132](https://github.com/bcinarli/pane-peek/issues/132) through one guarded destination-opening flow shared by a bundled `panepeek` launcher and native `open -a PanePeek <path>` requests. Keep local processing, current preview limits, native document ownership and the shared sandbox access model. Add no third-party runtime dependency.

Exclude multiple-target pane assignment, remote URLs, file creation, command execution, app-managed privilege escalation and new linked-file preview support. [#136](https://github.com/bcinarli/pane-peek/issues/136) remains separate.

## Command and destination rules

Native destination and window rules carry forward into the launcher. Unit 2 uses the command and path rules below, subject to the distribution feasibility gate.

| Invocation | Result |
| --- | --- |
| `panepeek` or `panepeek .` | Browse the calling shell's current directory. |
| `panepeek <folder>` | Browse an ordinary folder. Directory links follow the existing canonical navigation policy. |
| `panepeek <file>` | Browse its containing folder, select the supplied item and show its normal preview or unavailable-preview state. Packages and file links remain selected items. |
| `panepeek --reveal <path>` | Browse the containing folder and select the supplied file, folder, package or link without substituting a link target. Revealing filesystem root browses `/`. |
| `panepeek --help` | Print usage without opening the GUI or constructing app state. |
| `panepeek --version` | Print the containing bundle's packaged version/build and candidate suffix, when present, without opening the GUI or constructing app state. Missing metadata fails honestly. |

Native `open -a` acts on the URL delivered by macOS. When macOS resolves a file symlink before delivery, open that target; do not promise selection of a link whose original path was not received. The launcher preserves literal link intent through its path handoff; signed integration remains part of Unit 2.

Accept one path, absolute or relative to the caller's working directory, with spaces and Unicode intact. `--` ends option parsing so leading-hyphen names remain usable. Unknown options, extra paths and a missing `--reveal` target are usage errors. Preserve filesystem path semantics, including symlinks; do not interpret a supplied path as a shell command or remote URL. A dangling file link can be selected in its parent; an absent ordinary item fails visibly.

Use the caller's physical working directory rather than shell-logical `PWD`. Resolve `..` through directory links using filesystem traversal, not lexical component removal. A trailing slash requires a directory or a link to one; reveal still selects the named link. `--reveal .` and `--reveal ..` select the resolved directory in its parent; root browses `/`.

Allow `--reveal` before or after the single target, before `--`. Reject repeated flags. `--help` and `--version` must appear alone. A short-lived CLI process from the app executable may run, but must return before constructing the SwiftUI app, browser lifecycle, favourites, restoration or updater.

Publish a successful explicit destination, cleared folder query, required hidden-file visibility and selected item together. Do not clear the query or toggle visibility before success, or try to recover a dropped hidden selection afterward. This is a narrow exception to A41's query retention through ordinary navigation; ordinary browsing keeps its query. Permission denial, cancellation or failure preserves the prior listing, selection, query, visibility and unresolved draft. A completed explicit Save or Discard is a document decision and is not rolled back if later navigation fails.

## Window and request ownership

`BrowserLifecycle` owns native file-open delivery, target-window choice and the pending request. SwiftUI creates browser scenes through a callback owned by the app; it does not independently handle the same incoming event. Reuse the most recently active browser window that is still registered and capture its active browser when receiving the request. A closed `lastActiveWindow` cannot win over a remaining browser window. About and Updates panels are not destinations.

During cold launch, reserve the system's initial browser scene identity rather than treating an empty registration list as proof that another scene is needed. The app's scene opener must be available before any browser exists. At launch completion, open the reserved identity if the request is still pending, coalescing with any automatic initial presentation. In an already-running app with no browser windows, create exactly one scene; repeated requests share that pending creation. Bind the request and remembered-restoration intent to that scene's identity, not to whichever window starts next. An explicit New Window remains fresh and cannot consume the request's restoration intent. Do not depend on a separate Dock-reopen callback.

For a newly created window, identify the target browser from its scene's restored configuration before loading directories. Restore layout, frame and the untargeted browser, but skip the target browser's remembered-directory read, history entry and restoration error. Retain its previous path/bookmark without loading it. If the first incoming open fails, show its error and the remembered path with existing access/reconnection guidance, without an old listing or preview. Do not silently open Home or read the remembered directory as a fallback.

Apply the incoming destination through the guarded flow after startup configuration, preserving the persisted record until the request succeeds. If a target browser's old startup read has already begun, supersede it rather than waiting indefinitely; late results cannot restore its old directory, error, history or focus. The other browser may finish its own restoration independently. Ordinary launch without a path, Dock reopening and explicit New Window retain A26/A27.

Retain at most the newest pending request for the captured browser. Superseded reads and permission responses cannot publish navigation or selection. An attached sheet means wait, not user cancellation: do not invoke the folder chooser until that captured window is available. Keep inline rename resolution with the existing guard, and do not stack permission or dirty-document sheets. Explicit panel cancellation cancels the captured request without replaying it; a distinct pending request is considered after the existing sheet closes. If its window closes or quit begins, cancel the captured request rather than redirecting it to another window. Reject multiple URLs in a single native open event before navigation, with clear feedback.

## Permissions and handoff

Try a live covering folder grant, a valid saved bookmark, applicable access carried by an incoming directory URL, then an exact covering folder chooser. Preserve incoming native URLs and their access representation through asynchronous work; reconstructing a path is not an access grant. Balance native scope adoption/release according to the actual delivery contract, verified in the signed app. Retain an incoming file URL through classification, listing and preview, but acquire parent-folder access before listing that parent or asking to resolve a dirty draft. Reuse existing rename and Save / Discard / Cancel behaviour. An unrelated chosen folder cannot replace the explicit destination.

The existing `exact` read flag constrains chooser replacement; saved bookmarks can still resolve to moved folders. Require the effective grant and loaded directory to match the explicit requested location after authorised directory-link resolution. A moved bookmark cannot silently redirect an incoming path. Preserve bookmark-following behaviour for ordinary restoration, favourites and history.

Inspect and classify only with authorised access. Keep required access alive through classification, listing and preview reads. Revalidate any previously observed item/link identity after permission decisions; a detected change cancels the captured request. A first authorised read cannot establish pre-grant identity. Errors, denied access and cancellation leave existing windows and unresolved drafts usable. File-link previews retain the current unavailable state; resolving a directory link follows the accepted navigation/access contract.

Carry browse versus parent-and-select intent into the shared flow independently of item type. A reveal request may select a directory or directory link. Resolve the containing directory and requested item under the filesystem's name rules, then select the actual listing entry and use its spelling. Literal basename/URL equality is insufficient on a case-insensitive volume. For a link path actually received, preserve the entry's own identity; do not follow the selected file link or choose an arbitrary hard-link identity match. An ancestor directory link must not cause selection to disappear, and a case-sensitive volume must still distinguish separate names.

Use a strictly decoded local URL event carrying browse/reveal intent for cold launch, a running app and no-open-window delivery. Launch arguments alone are insufficient: Apple's [OpenConfiguration](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration) describes arguments for a new app instance. Target the launcher's containing app by its explicit bundle URL and disable running-app substitution, retaining reuse of that same copy. Treat the URL contents as untrusted destination data, never permission or an executable command. Add no listener, network request, automation entitlement or filesystem exception.

Exit status: `0` means help/version output or successful OS handoff; `2` means invalid arguments; `1` means a confirmed missing target, invalid packaged metadata or launch/handoff failure. A successful handoff does not promise a later folder grant or completed navigation. Report those outcomes inside the app. Preflight failures and requests invalidated after handoff must be distinguishable in documentation.

## Setup and distribution

Bundle the launcher with both GitHub and App Store apps. Provide a Terminal Command item in the PanePeek application menu for user-initiated installation and removal, available independently of update controls. Use a dedicated user command directory linked to this app copy’s bundled resource. Keep current app capabilities and native user-selected access; no privileged installer or helper is included.

Offer launcher-only installation for every account. For standard macOS zsh, offer a separate action that also adds one marked PATH block to `~/.zprofile` with explicit consent. Preserve existing profile contents and command priority. Refuse unsafe profiles and ambiguous managed entries. Report the launcher and profile states separately. Shell startup files and later PATH changes determine command lookup.

Uninstall verifies and removes the owned launcher before removing its unchanged managed profile block. If safe profile cleanup fails, preserve the profile and report `~/.zprofile` as needing attention. A launcher-only installation skips profile changes during installation and removal. Retain expired-access handling and moved-app recovery.

For manual PATH setup, append the installed command directory at `~/Library/Application Support/PanePeek/bin` to the shell’s PATH. The panel shows the Bash or zsh profile entry for the actual directory in a code box with a copy icon beside it. The usage guide provides an example.

Link setup leaves conflicting commands, regular files, directories and broken links untouched; an existing link to the same selected launcher is a no-op. Removal checks that stored target before unlinking only the matching launcher link, even if its target has moved. Moving or selecting a different app copy requires explicit removal using the old app path and setup using the new one. An update at the same app path keeps the link usable. Lead usage with ordinary folder/file paths and explain `--reveal` as optional parent selection.

Use the accepted [CLI entry-point design](../../decisions/2026-11-09-cli-entry-point.md): bundle a shell entry point under `Contents/Resources/panepeek` that captures the physical caller directory before executing early CLI mode in `Contents/MacOS/PanePeek`. Keep normal GUI launch on the existing SwiftUI path. Verify actual packaged execution in both distributions without adding capabilities; local signing alone does not establish Apple-distributed or quarantined-install acceptance.

## Decisions before implementation

Native directory access joins the shared FolderAccess store as a validated, read-only security-scoped bookmark for later navigation and relaunch. Reuse a covering writable grant first without downgrading it; editing and mutations retain explicit upgrade. File-only access does not authorise its parent. This keeps native opening within the existing folder-access model while avoiding repeated grants for later reads.

A normal foreground open brings the captured browser window forward and unminimises it, preserving native full-screen and Space placement. After success, focus its browser list and reveal the selection using native accessibility behaviour. Cancellation and failure retain existing focus. Reject multiple URLs atomically with window-local error feedback, or a native app-level alert when no browser exists; do not create a browser solely to show the error.

Native delivery accepts a target resolved by macOS before handoff. Signed Unit 1 checks must still establish whether separate opens can arrive as a combined batch; retain atomic rejection of a delivered multi-URL event.

A permission error during launcher preflight is not proof that a target is missing. Verify which failures each signed distribution can detect before handoff; confirmed missing targets fail, while unknown access must retain an honest app-side outcome. Any required change to the accepted command or exit contract needs review before implementation. Launcher execution/signing feasibility remains the first Unit 2 gate.

## Acceptance criteria

- **C1:** Native single-path opening acts on the URL delivered by macOS, including a system-resolved link target, browsing folders or selecting delivered files/packages/links in their containing folder with normal previews and authorised directory-link behaviour.
- **C2:** Cold launch, running-app and no-open-window delivery reach the explicit destination once, with deterministic window/browser ownership and no later restoration overwrite.
- **C3:** Saved/new/cancelled/denied access, dirty drafts, rename, stale requests, closed windows and quit retain the safeguards above. No parent permission is inferred from a file path.
- **C4:** Launcher arguments, caller-relative paths, absolute paths, Unicode, spaces, leading hyphens, hidden items, root, packages, symlinks and missing targets follow the documented outcomes; reveal intent works while the app is already running.
- **C5:** Help/version and exit statuses distinguish argument/preflight/handoff failures from subsequent app navigation, without constructing GUI app state for informational commands.
- **C6:** The menu installs and uninstalls the launcher for every account. Optional standard macOS zsh setup adds the launcher folder to PATH in a new login shell, preserving earlier command priority. Verify status, intended app-copy ownership, safe removal, signing and bundle integrity in both distributions with the existing permissions and capabilities.
- **C7:** Signed native review verifies target focus, permission/dirty guards, independent panes/windows and perceivable keyboard/VoiceOver status and errors. Remaining accessibility/platform limits stay explicit.
