---
status: Accepted
date: 2026-11-08
supersedes: []
superseded_by: ""
---

# CLI and native path opening specification

## Scope

[#132](https://github.com/bcinarli/pane-peek/issues/132) opens one local path through the same guarded browser flow from the bundled `panepeek` launcher or a native `open -a PanePeek <path>` request. Keep the [native baseline](../001-mvp/spec.md), local processing, existing previews, runtime dependencies and sandbox permissions. Multiple-target assignment, remote URLs, file creation, command execution and privilege escalation are outside scope. [Read-only text previews for symbolic links (#136)](https://github.com/bcinarli/pane-peek/issues/136) are tracked separately.

## Command and destination rules

| Invocation | Result |
| --- | --- |
| `panepeek` or `panepeek .` | Browse the caller's physical working directory. |
| `panepeek <folder>` | Browse the folder, following authorised directory links. |
| `panepeek <file>` | Browse its parent and select the item with its normal preview state. Packages, file links and dangling links remain selected entries. |
| `panepeek --reveal <path>` | Browse the parent and select the file, directory, package or link. Revealing root browses `/`. |
| `panepeek --help` | Print usage without initialising the GUI. |
| `panepeek --version` | Print the containing bundle's version, build and any candidate suffix without initialising the GUI. |

Accept one absolute or relative path, preserving spaces and Unicode. Allow `--reveal` once before or after the path and use `--` to end option parsing. Help and version must appear alone. Unknown options, extra paths and a missing reveal target are usage errors.

Resolve relative paths from the physical working directory and traverse `..` according to the filesystem, including through ancestor directory links. A trailing slash requires a directory or a link to one. Reveal selects the named link or, for `.` and `..`, the resolved directory in its parent. Native opens use the URL delivered by macOS, including any file-link target it resolves before delivery.

Return `0` for help, version or accepted OS handoff, `2` for invalid usage and `1` for preflight or handoff failure. Confirm absence before reporting a missing target. Unknown access proceeds to the app's permission flow. The app reports subsequent navigation and permission outcomes. Path resolution and OS handoff share one 15-second confirmation budget.

## Window and request ownership

`BrowserLifecycle` owns delivery and routes each request to the most recently active registered browser window, capturing its active pane. During cold launch, reserve the system's initial scene and open that identity at launch completion if a request is pending. With no browser in a running app, coalesce requests into one pending scene. Bind the request to that scene so a fresh window cannot consume it.

Cold launch and Dock reopening with no browser restore the saved configuration through the scene value. Explicit New Window and native tabs use fresh [A26 defaults](../001-mvp/spec.md#multiple-windows-and-remembered-directories). For an incoming open in a restoring scene, load layout, frame and the untargeted pane. Skip or supersede the target pane's startup read and preserve its saved path and bookmark until the open succeeds. Until an incoming listing publishes, keep the saved path through supersession, failure and cancellation. Show reconnection guidance when needed and leave the target listing and preview empty. Obsolete reads cannot publish listings, history, errors or focus.

Keep the newest pending request per window. Wait for sheets, saves and their listing refreshes, then revalidate the captured pane and destination. Use the existing inline rename and Save / Discard / Cancel guards. A failed save or unavailable pane produces a window-local error. Explicit cancellation ends that request. A distinct newer request can proceed after the sheet closes. Window close and quit invalidate captured requests. Reject a multi-URL event atomically with a window-local error or an app-level alert when no browser exists.

Resolve inline Rename before publishing, including an edit that starts during a read. Refresh the listing after Rename. Record successful Save replacements while the incoming request is pending. Accept only a verified replacement of the requested file and refresh stale listing data.

Revalidate the item and directory identities after sorting and confirm the request still owns the pane. Publish the destination, cleared query, needed hidden visibility and selection together. A successful foreground open brings the window forward, unminimises it and focuses its list while preserving native Space and full-screen placement. On cancellation or failure, preserve the prior listing, selection, query, visibility, focus and unresolved draft. Completed Save and Discard decisions take effect independently of navigation.

## Permissions and handoff

Use covering live access, saved access, applicable native directory access or an exact folder chooser. Persist validated native directory grants read-only in the shared store and retain any existing writable grant. File access alone gives no parent-folder access. Acquire access to the listing directory before document decisions, and use the existing write upgrade for edits and mutations.

Keep the native URL and authorised scopes alive through listing and preview. Verify the effective directory after link resolution and recheck observed file, link and directory identities before publication. Ordinary restoration, favourites and history can follow moved bookmarks. An incoming open requires the explicit destination. Match the named entry in the actual listing using filesystem spelling and identity, preserving the supplied file-link or hard-link name.

Follow the [CLI entry-point decision](../../decisions/2026-11-09-cli-entry-point.md). The bundled shell passes the physical caller directory and unchanged arguments to early Swift CLI mode. Use a strictly decoded local URL event carrying browse or reveal intent, target the exact containing bundle, disable running-app substitution and reject self-handoff. The event carries destination data only. Keep the app's existing capabilities and avoid constructing GUI, favourites, restoration or update state in CLI mode.

## Setup and distribution

Bundle the launcher in GitHub and App Store builds. **PanePeek → Terminal Command** manages the symlink in `~/Library/Application Support/PanePeek/bin` to this app copy's bundled launcher using native user-selected write access. Request access again when a grant expires. Report link and profile state separately. An existing matching link is a no-op. Preserve unrelated files, directories and links, including broken links.

Offer launcher-only installation for every account. Standard macOS zsh accounts can separately opt in to one marked PATH block in `~/.zprofile`. Preserve existing profile contents and command priority, and refuse unsafe profiles or ambiguous entries. Custom shells, relocated profiles and PATH overrides may require manual setup. Show the Bash or zsh entry in a code box with the file-preview copy icon beside it. See the [usage guide](../../../docs/usage.md#open-paths-from-terminal).

Align panel actions to the trailing edge, label dismissal **Close**, and show a short `panepeek` and `panepeek --help` hint. Panel actions preserve the browser and draft state.

The installation receipt records the app copy, launcher target, link identity and whether PanePeek manages the profile. Uninstall the verified launcher before attempting profile cleanup. Remove only the unchanged managed block. Preserve unsafe or edited profiles, report the path needing attention and allow cleanup to be retried. Uninstall skips profile cleanup when the receipt records a launcher-only setup with no managed profile.

From a different app copy, **Remove Stale Link** requires the exact recorded link and confirmed absence of its target. Recheck both before removal and preserve the profile. A launcher-only reinstall keeps any recorded profile ownership for later cleanup. Receipts with a missing or mismatched link identity require manual recovery. An update at the same path keeps the link usable.

## Acceptance criteria

- **C1:** Native single-path opens browse delivered folders or select delivered files, packages or links with the expected preview and authorised link behaviour.
- **C2:** Cold, running and no-window delivery open the destination once in the captured window and pane. Saved and fresh scenes follow their own restoration policy.
- **C3:** Access, dirty drafts, rename, supersession, close and quit retain the safeguards above.
- **C4:** Launcher arguments and path handling follow the command contract, including reveal in a running app.
- **C5:** Help, version and exit statuses distinguish CLI outcomes from later navigation. CLI mode leaves GUI state uninitialised.
- **C6:** Terminal Command installs and removes the intended launcher, optionally manages the standard zsh PATH entry, and preserves ownership, profiles and existing app capabilities in both distributions.
- **C7:** Signed review verifies pane and window independence, focus, permission and document safeguards, and keyboard and VoiceOver access to status and errors.
