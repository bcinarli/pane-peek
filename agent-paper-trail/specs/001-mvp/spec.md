# PanePeek MVP specification

Status: Product direction and T01 Unit 1 approved on 2026-10-03; T01 Unit 2 approved on 2026-10-04. Accepted UI/logo and expanded web-file highlighting incorporated on 2026-10-04; revised task sequencing awaits review. Each coding unit retains its own approval gate.

PanePeek is a focused macOS file browser for Bilal’s local workflow. It combines two independent directory panes with an inline preview and text editor, allowing files to be inspected and moved without switching applications.

## Requirements and proposed defaults

The product requirements below come from Bilal’s brief and spec review. Bilal accepted the current direction on 2026-10-03; details marked as proposed can still be revised through review.

| Requirement | MVP outcome |
| --- | --- |
| R1 Independent panes | Browse two directories independently, with clickable breadcrumbs and sorting. |
| R2 File transfers | Copy or move selected items between panes, including drag and drop. |
| R3 Inline preview and editing | Inspect text/code and metadata in a details sidebar; toggle the preview into an editor with syntax highlighting. |
| R4 Independent visibility | Toggle hidden files separately in each pane. |
| R5 Favourites | Save directories and open them in either pane. |
| R6 Paths and context actions | Keep the selected absolute path visible and copyable; copy absolute/relative paths from context menus and the focused directory path from shared actions. |
| R7 File management | Delete and rename items; create text files and directories. |
| R8 Windows and restoration | Use multiple independent windows; restore the last pane directories on app relaunch. |

Product defaults:

- Support macOS 26 and later, using SwiftUI with an AppKit text editor and Foundation file services.
- Allow multiple windows, each with two independent directory panes and a Details sidebar at the far right. The selected item’s preview is at the top of the sidebar, with file metadata below. A toggle switches supported text between preview and editor. The most recently activated pane in that window supplies the selection.
- Support multiple selection using Command-click, Shift-click and Select All. Copy to Other Pane / Move to Other Pane operate on the selection. Include drag and drop between panes/windows and interoperability with Finder.
- Relative paths are based on the directory displayed in the item’s pane. A file at `/example/project/src/main.swift` in a pane displaying `/example/project/src` yields `main.swift`.
- Plain text and UTF-8 files up to 1 MiB are editable. The languages listed in A15 highlight in both Preview and Edit; other text stays editable without highlighting.
- Filename collisions are rejected with a useful message. Overwrite, folder merge and automatic renaming are deferred.
- Favourites and the last left/right directory pair persist locally. Relaunch restores that pair in the initial window; the first-ever launch uses home. Every explicitly opened new window starts both panes at home. The restoration policy retains one pair from the most recently active window, rather than restoring all windows. Hidden-file visibility remains per-pane session state.
- Delete sends items to Trash with confirmation; permanent deletion is deferred. Rename targets one item at a time. New Text File and New Folder create items in the active pane’s directory.
- The development MVP is a locally built app outside the App Sandbox. Signing, notarisation and App Store distribution are deferred.

## Accepted UI design

The [Browse & peek reference and original logo](../../design/001-mvp/README.md) were accepted by Bilal on 2026-10-03. [Decision 0003](../../decisions/0003-ui-and-logo-direction.md) records the alternatives. These requirements guide native implementation:

- Keep both directory lists visible beside far-right Details. Preview/editor sits above metadata; the selected absolute path has a visible copy control. Sidebar width is adjustable, with the balanced reference as the default direction.
- Use native Mac surfaces and system appearance. Macchiato Mauve `#C6A0F6` supplies dark accents; the draft uses darker Mauve `#8255B6` for readable light-mode controls. Adapt editor token colours for each appearance and retain native text/caret/selection contrast.
- Give each pane a compact breadcrumb row: Home before filesystem root `/`, then clickable path components, with a trailing favourite star. The draft's 44 px row is a guide; native text sizing and long paths must remain accessible. Align both panes' location rows and list headings when paths wrap.
- Indicate the focused pane with a thin Mauve underline below its location, visible even without a selection. Avoid visible Active/Left/Right labels and repeated per-pane ellipsis menus. Accessible control names must still distinguish the panes and communicate focus.
- Use one shared toolbar for Go to Folder, Favourites and directory actions, targeting the most recently focused directory pane even while the editor/toolbar has keyboard focus. Go to Folder and Command-L expose an editable absolute directory path. Shared actions include parent navigation, Refresh, hidden visibility and Copy Directory Path. Sort controls remain per pane.
- Align clickable Name and Modified headings with their row columns. Show the current direction beside the active heading; no separate sort picker or direction button.
- Show an outline star for an unsaved directory and a filled Mauve star for a saved one. Stars act on their own pane's displayed directory; opening a shared favourite acts on the focused pane. Do not add a permanent favourites column.
- Keep Copy/Move to Other Pane in file context menus and drag/drop. Do not add selection-triggered transfer buttons. Essential shared actions and context actions remain keyboard accessible.
- Keep syntax highlighting when switching supported text into Edit. The original peeking-P concept is the logo direction; production icon preparation and small-size validation remain pending.

The mockup is illustrative. Its sample files, carousel and appearance/layout controls are not shipped features or native acceptance evidence.

## Scope boundaries

The MVP includes directory navigation with clickable breadcrumbs, per-pane name/modified-time sorting, refreshing, multiple selection, copying/moving and drag and drop, a details sidebar with text preview/editor and file metadata, Markdown highlighting, favourites, path copying, deletion to Trash, rename, text-file/folder creation, multiple windows and restoration of the last pane directory pair. Regular directories and files are supported. Symlinks are listed and transferred as links; navigating through a directory link uses the canonical target location, following Finder. macOS packages are treated as files rather than browsable directories.

Excluded: cloud accounts, FTP/SFTP, remote connection management, synchronisation, search indexing, tabs, batch rename, permanent deletion, automated bulk workflows, source control integration, rich previews for images/PDF/media, rendered Markdown preview, restoration of every prior window or unsaved buffers, and distribution infrastructure. Operations on a multiple-item selection are included.

Local-only means PanePeek implements filesystem operations without network clients or service connections. Paths exposed by macOS may be backed by OS-managed cloud storage or mounted volumes. The MVP does not promise offline availability or block those paths; OS failures must be surfaced. Strict volume restrictions would require a separate decision.

## User behaviour and acceptance criteria

### Directory panes

Each window owns its panes, active-pane identity and editor state. Each pane owns its directory, selected items, primary selected item, hidden-file setting, sort field/direction and loading/error state. Shared favourites and restoration preferences belong to the application.

- **A1:** Navigate using a folder chooser, an editable absolute directory path through Go to Folder/Command-L, parent navigation, Home, clickable breadcrumbs and double-clicking a directory. Shared navigation actions target the focused pane; Home targets its own pane. Changing one pane leaves the other pane’s directory, selection and visibility unchanged. Focus remains visible with an empty selection.
- **A2:** List names with file/folder distinction and a last-modified value. Default to folders first and natural name order ascending. Allow sorting by name or last-modified time in either direction under A30. Empty directories show an empty state.

  Modified labels use completed elapsed units: under one minute Just now; under one hour minutes; under thirteen hours one through twelve hours. Thereafter use Today/Yesterday for local calendar days, otherwise `dd.MM.yyyy HH:mm` in the local timezone. Exact timestamps remain available through help/accessibility. Update relative labels each minute and after wake without rereading or reordering the listing. Unavailable metadata retains an honest fallback; future values display their exact date without special workflows.
- **A3:** An inaccessible, deleted or invalid directory produces a visible error and leaves the last successful directory usable. Slow reads do not block UI interaction; an older listing result cannot replace a newer navigation result.
- **A4:** Each pane has its own hidden-file toggle. Respect dot-prefixed names and filesystem hidden metadata. Manual Refresh reloads a pane; transfers refresh both affected panes. Automatic filesystem watching is deferred.

### Copy and move

Copy/Move to Other Pane context actions target the other pane’s current directory in the same window. Drag and drop targets the receiving pane’s current directory, including another PanePeek window. Show the source items and destination in move confirmation; copy can execute directly.

- **A5:** Copying a regular file or directory produces equivalent contents at the destination and leaves the source intact. Moving removes the source only after successful transfer. Directory copying preserves its nested contents; symlinks are copied/moved as links without traversing their targets.
- **A6:** Reject an existing destination name, a transfer onto the same item and a directory transfer into itself or a descendant. Resolve symlinks in source/destination directory paths when checking ancestry. Rejected operations leave existing source and destination data unchanged.
- **A7:** Failed operations report the item, destination and actionable error. Do not report completion until filesystem work succeeds. Cross-volume moves must preserve the source if copying fails; any incomplete destination is identified and cleanup failures are reported. Do not claim multi-step transfers are transactional.
- **A8:** Transfers run away from the UI thread. Prevent duplicate submission and conflicting mutations of the same items across PanePeek windows while an operation is active; keep navigation responsive. Snapshot all sources and the destination at submission; later navigation must not redirect an in-flight transfer.
- **A9:** Resolve unsaved editor changes in every affected PanePeek window before transferring, renaming or deleting an edited file or a directory containing it. Any Cancel or failed Save aborts the requested operation before mutation. Successful moves/renames update or close affected previews; deletion closes affected previews. An editor must never silently save to an obsolete path.

### Details sidebar and preview editor

Reserve the far-right sidebar for Details. Place the selected item’s preview at the top and its filesystem metadata below. Supported text opens in read-only preview; a toggle switches this same area into an editor. Metadata remains visible in either mode.

The primary selected item in the active pane supplies that window’s preview. Multiple selection keeps a single preview, following the most recently focused selected item; clearing selection clears the preview. Directories, packages, oversized files, binary data and undecodable text show a clear unavailable-preview state without editing controls.

- **A10:** Preview loading is asynchronous and bounded. Rapid selection changes show only the latest requested file. UTF-8 with or without a BOM is supported; a NUL-containing file is treated as binary for this MVP.
- **A11:** Toggle supported text from preview to editor, retain syntax highlighting, edit it, see a dirty indicator and save explicitly. Highlighting changes presentation only; it must not alter file content or reset caret/selection during normal typing. Support native text selection, clipboard actions and undo.
- **A12:** Choosing another file, navigating away from the preview’s source directory or closing the window/quitting the app with edits prompts Save / Discard / Cancel. Cancel retains the current document and cancels the requested transition.
- **A13:** Saving checks that the file has not changed on disk since it was loaded or last saved. Detected modification, replacement or deletion prevents an automatic overwrite and preserves the buffer. Permission/write failures also retain edits and report the failure.
- **A14:** Successful saving uses atomic replacement supported by the filesystem, preserves UTF-8 BOM presence and existing newline sequences, and does not normalise line endings. Preserve existing file permissions. Previewing a symlink may read its target, but editing it is disabled in this MVP.
- **A15:** Highlight Swift, JavaScript/TypeScript, JSX/TSX, JSON, Python, Markdown, HTML, XML, CSS and SCSS in both Preview and Edit. Code languages highlight keywords, strings and comments; JSON highlights strings, literals and numbers. HTML/XML highlight tags, attributes, quoted values and comments; JSX/TSX also distinguish markup and embedded code expressions. CSS/SCSS highlight selectors, property names, values and comments; SCSS also distinguishes variables and directives. Markdown highlights headings, emphasis, links and inline/fenced code; highlighting code inside fences is optional. Markdown remains source text. Unsupported extensions remain plain text. This is lexical highlighting, without language servers, code intelligence or rendering/executing HTML. Embedded script/style language highlighting inside HTML is optional.

The pre-save external-change check reduces overwrite risk but does not lock out other applications. Simultaneous external writes during saving remain a documented MVP limitation. Files are not executable content within PanePeek.

### Favourites and context menus

- **A16:** Each pane's star adds/removes its displayed directory and reflects shared favourite state across panes/windows. Toggling a star leaves navigation, selection and edit buffers unchanged. Open a favourite in the focused pane from the shared Favourites menu, using existing navigation and dirty guards. Duplicate equivalent paths are not added. Persist favourite directory paths across app launches; a missing or inaccessible favourite shows an error without being silently removed.
- **A17:** File and directory context menus offer Copy Absolute Path and Copy Relative Path. Right-clicking an unselected item selects and targets that item; right-clicking within the existing selection preserves it for selection actions and follows A12 if it replaces a dirty preview. Path-copy actions on multiple items emit one plain path per line in displayed order, without shell quoting or a `file://` prefix; preserve spaces and Unicode. Shared Copy Directory Path copies the focused pane's displayed absolute directory path using the same plain format. Rename is enabled only for one item.
- **A18:** Relative paths use the originating pane directory and preserve the displayed path rather than resolving a symlink target. Context menus also expose Copy to Other Pane, Move to Other Pane, Rename and Move to Trash when applicable. The core actions are part of the spec; final ordering, separators and extra convenience actions are UI decisions. Pane background menus expose New Text File and New Folder.

### Multiple selection and drag and drop

- **A19:** Command-click toggles individual items, Shift-click selects a range and Select All selects the visible listing. Each pane/window keeps its own selection and primary item. Selection changes that replace a dirty preview follow A12.
- **A20:** Transfer a selection using Copy/Move to Other Pane context actions or a drag. Preflight every item for known conflicts before starting; any known conflict rejects the whole request without mutation. During execution, stop on the first failure and report completed, failed and unattempted items. Completed transfers are not automatically rolled back.
- **A21:** Drag default: copy, with Command requesting move where PanePeek controls the destination and the source permits it. Accept local file URLs from Finder and export selected file URLs to Finder. Show the intended copy/move operation and reject unsupported payloads; do not accept service URLs. Transfers entering PanePeek obey A5–A9 and A20. Finder controls outgoing drop behaviour; resolve affected dirty buffers before starting an outgoing drag and use Refresh to reconcile later external changes.

### File management

- **A22:** Move one or more selected items to Trash after showing a confirmation with item names/count. Cancellation changes nothing. Trash symlinks themselves, not their targets; include directories and packages. On failure, report completed, failed and unattempted items. If Trash is unavailable, report an error without falling back to permanent deletion.
- **A23:** Rename one selected item using a filename, without changing its containing directory. Reject empty names, path separators, NUL, `.`, `..` and destination collisions. Handle case-only renames according to the filesystem’s case rules. On failure keep the original item usable and preserve affected edit buffers.
- **A24:** New Text File and New Folder prompt for a name in the active pane’s current directory. Use the same name/collision validation as rename and never overwrite an existing item. Create an empty UTF-8 text file or an empty directory, refresh affected panes and select the created item. A created text file can immediately be edited in the preview.
- **A25:** Run file mutations off the UI thread and apply A9 across windows. Refresh every open pane displaying an affected directory. If a window is browsing a directory that is moved/renamed, follow its new location when known; if it is trashed, fall back to the nearest accessible parent and explain the change. Errors and partial outcomes must remain visible.

### Multiple windows and remembered directories

- **A26:** New Window opens an independent pair of panes at home even when another window is browsing elsewhere. Navigation, selection, hidden visibility and editing in one window do not change another window’s state. Favourites remain shared.
- **A27:** Persist the last left/right directory pair after successful navigation in the active window and when focus changes between windows. On app relaunch, the initial window restores that pair. For an unavailable remembered path, fall back to home for that pane only and show a useful message. Preserve the last active pair when the final window closes. A new window is always the home-directory default, not a copy of the restored window.
- **A28:** Resolve dirty buffers in all windows before quitting. Cancellation or a failed Save keeps the app open and retains pending edits. If the same file is edited in two windows, saving one causes the other to detect the changed disk version under A13; no automatic overwrite or dirty-buffer reload occurs.

The copy-first drag behaviour and single-pair restoration policy are accepted defaults. Multiple windows do not imply restoration of all prior windows.

### Breadcrumbs and sorting

- **A29:** Display a compact breadcrumb from filesystem root to the current directory at the top of each pane, preceded by Home and followed by the favourite star. Home opens the home directory; `/` remains a distinct root action. Clicking an ancestor navigates that pane to it and follows the existing unsaved-change guard. Keep all long-path components accessible, through wrapping or horizontal scrolling, and align both pane headings. Navigating through a directory symlink displays its canonical target location; parent navigation and breadcrumbs use that location, following [the Finder-style navigation decision](../../decisions/0005-finder-directory-symlink-navigation.md).
- **A30:** Each pane has independent sort controls for Name and Last Modified, with ascending/descending direction. Name keeps folders first and follows the selected direction within each group. Modified sorts folders and files together by actual timestamps in either direction; timestamp ties use ascending natural name order and a stable path tie-breaker. Unknown timestamps appear last across the entire listing in either timestamp direction. Sorting preserves selected item identity and does not change the other pane or window.

  Activating the current column heading reverses direction. Switching to Name starts ascending; switching to Modified starts descending (newest first). Sorting uses actual values rather than formatted date labels.

### Sidebar details and preview mode

- **A31:** Show a far-right Details sidebar per window, preview above metadata. Use the primary selection from the active pane; empty and unsupported previews must not suppress available metadata. Directory/package selections can show metadata without a content preview.
- **A32:** The Preview / Edit toggle is enabled only for editable text. Entering Edit retains the loaded content; returning to Preview retains unsaved changes and shows the current buffer read-only. The dirty indicator and Save remain available until changes are saved or explicitly discarded. Switching modes does not bypass A12 or reset the document’s undo history.
- **A33:** Show creation date, last-modified date, full Unix path, permissions in octal and symbolic form, owner and group, item type and file size when available. Keep the full selected absolute path accessible and copyable with a small adjacent control, including when content preview is unavailable. Copy the displayed item's path using A17's plain format; do not substitute a symlink target. Details are read-only. If a field is unavailable, say so rather than fabricating a value. For a symlink, show the link’s own metadata and its target path distinctly. Asynchronous details follow the latest selection; refresh after relevant saves/mutations and on manual Refresh.

## Proposed architecture

Keep two production targets: `PanePeek` for the native application and `PanePeekCore` for testable filesystem and document behaviour. A core test target uses temporary directories; it must never mutate Bilal’s real files.

The shell starts with the application target. Introduce the core and its tests with meaningful behaviour, following the [accepted foundation](../../decisions/0004-swift-package-application.md).

| Surface | Responsibility |
| --- | --- |
| Application and views | Multiple-window lifecycle, pane breadcrumbs/sort controls, Details sidebar, prompts, commands, drag and drop and clipboard integration. |
| Pane state | Directory, selected items/primary item, hidden visibility, sorting and current listing request within one window. |
| Filesystem services | Listing, metadata, path validation, selection transfers, Trash, rename and creation, with coordination of conflicting operations across windows. |
| Details and editor state | Current item metadata, preview/edit mode, loaded document identity, original bytes, editable buffer, highlighting and save lifecycle through an AppKit bridge. |
| Local preferences | Persist shared favourites and the remembered pane directory pair. |

Filesystem work runs off the UI thread; UI state changes return to the main actor. Avoid a generic provider layer, plugin system or remote abstraction. Exact type names and concurrency boundaries belong to the implementation unit that needs them.

A Swift package with a small app-bundling script is the accepted project foundation. An Xcode app project remains the fallback for a concrete native integration limitation: conventional bundle/signing support, at the cost of additional project configuration and a full Xcode requirement.

## Engineering and task review rules

The rules below capture the project-relevant coding, evidence and review requirements. Bilal’s core preferences remain the source for his personal collaboration rules; project continuation must not require access to his private files. PanePeek adds these task-specific constraints:

- For meaningful automated behaviour tests, use red/green TDD: write a high-value failing test, observe the intended failure, implement the smallest passing change, then refactor with the tests green. Compilation/import/setup failures do not count as the intended red result. UI layout and packaging are validated through actual app runs; do not manufacture low-value tests to imitate TDD.
- Add tests only when they protect a requirement, meaningful failure path or regression. Prefer real temporary filesystem fixtures; use bounded failure injection where the real condition cannot be reproduced reliably. No boilerplate tests, coverage targets or assertions that merely mirror implementation.
- Reuse existing functions and UI components for equivalent behaviour, especially path/name validation, file operations and prompts. Keep reuse concrete and avoid a generic abstraction that makes straightforward code harder to follow.
- Keep cognitive complexity low with clear names, local control flow and small focused functions. Do not set an arbitrary numeric threshold; review nesting, state transitions and duplication against the task’s actual risk.
- Keep comments short and limited to intent, non-obvious behaviour or a public contract. Do not narrate mechanics or add explanatory paragraphs around readable code.
- Every task produces a launchable app with visible behaviour for Bilal to test. Present the run instructions, fixture/setup steps, acceptance criteria covered and a short manual checklist. Stop for Bilal’s test and review before proceeding. A green automated suite does not substitute for that checkpoint.
- After every code unit and every other piece of work with meaningful output, run tighten followed by probe before presenting the result. These are the default review passes throughout the work.
- At milestone boundaries, consider a code-quality analysis using Bilal’s `code-quality-analysis` skill. Review its findings first; if improvement work is warranted, use the `cluster-workflow` skill to plan coherent remediation clusters with dependencies, validation and exit criteria. Obtain approval before implementing any cluster. Correctness issues block milestone acceptance; optional maintenance work can be deferred explicitly.

## Validation and completion

The MVP is complete when A1–A33 pass, meaningful automated tests pass, and a macOS manual check confirms the native workflows. A clean checkout must build, test, package and launch using the documented toolchain.

Automated tests cover pane/window independence, breadcrumbs, sorting, selection and primary-item behaviour, hidden metadata, metadata formatting/unavailable fields/stale results, preview/edit transitions, path semantics, transfer preflight/partial failures/ancestry/symlinks, rename/creation/Trash failures, document decoding/save conflicts, Markdown and code highlighting, favourite persistence and directory restoration/fallback. Cross-window mutation tests cover open and dirty documents affected by move/rename/delete. Test interfaces should follow behaviour rather than mirror view implementation.

Manual validation covers the accepted layout and focus cue, Home/root and long breadcrumbs, shared-action targeting and favourite stars, pane interaction and multiple selection, drag and drop within/between windows and to/from Finder, menus/clipboard and visible absolute paths, rename/create/Trash, highlighting in Preview/Edit, editor caret and undo, dirty prompts, app quit, new windows and relaunch restoration, responsiveness, system light/dark appearance and keyboard access to essential controls. Validate on macOS 26 or later and record the actual OS/toolchain used. Keep unexecuted checks explicit.

Document setup/build/run, architecture, feature limits and validation evidence in the repository. Maintain task-level red/green evidence and manual-review status; map every acceptance criterion to an observable stage. No commits, pushes or distribution steps are implied by spec approval.

## Review status

Bilal approved T01 Unit 1 on 2026-10-03 and static shell alignment/development icon bundling in Unit 2 on 2026-10-04, then accepted the current result and confirmed the full manual checklist on 2026-10-04. The validation record retains OS/toolchain limits. The draft UI and original logo were accepted on 2026-10-03; document alignment and web-file highlighting, including HTML and SCSS, were authorised on 2026-10-04. Revised task sequencing remains presented for review. Details marked as proposed remain adjustable. Coding, manual acceptance, commit, push and merge gates remain separate.

Bilal accepted folders-first ordering for both fields with T03 Unit 1 approval on 2026-10-05. Unit 1 running-app acceptance was given on 2026-10-06; hidden visibility/Refresh and cross-window validation were pending at that checkpoint.

Bilal approved the T03 presentation revision on 2026-10-06: aligned clickable headers, first-click directions and relative/exact date labels above. Bilal accepted Unit 1 including the stationary Modified heading and authorised its local commit on 2026-10-06. The evidence retains unreported manual checks. Future/unavailable values are display fallbacks, not creation or editing requirements.

Bilal authorised T03 Unit 2 hidden visibility/Refresh on 2026-10-06. Its implementation then entered manual review; A4 remains partial until transfer refresh is exercised in later tasks. Unit 2 commit and push/merge remain separate approvals.

[Changed, 2026-10-06] Bilal approved global Modified ordering in A30 after finding the separate folder/file date groups confusing. Name retains folders first. Kind grouping is deferred and is not a priority; keep the app simple and performant. This bounded sorting revision requires red/green and a running-app review before Unit 2 acceptance.

[Accepted, 2026-10-06] Bilal confirmed the now label correction and all other tested features within Unit 2 scope. This accepts hidden visibility/Refresh, global Modified ordering and the native date-clock correction, completing T03 implementation/manual review. [The evidence](../../validation/t03-sorting-hidden-visibility.md#unit-2-acceptance-2026-10-06) retains individually unreported checks and cross-task limits. Commit, push/merge and later tasks require separate approval.
