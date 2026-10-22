# PanePeek MVP implementation plan

Status: Active

This plan owns task scope and dependencies. The [spec](spec.md) owns behaviour, [tasks](tasks.md) owns current state and [validation](validation.md) owns acceptance. Scope is macOS 26+; production sandbox packaging follows the current distribution decision.

## Task workflow and exit gates

Each atomic coding unit requires approval, meaningful behavioural validation, a launchable app and manual acceptance before the next unit. Use red/green TDD for new automated behaviour and real build/native review for layout and packaging. Apply tighten followed by probe. Commit, push, merge and distribution retain separate gates.

The [shared checklist](../../validation/checklist.md) owns review requirements. Keep current outcomes, provenance and acceptance limits in task evidence; retain raw execution details outside the paper trail. A partly exercised criterion remains Pending unless explicitly waived. Use disposable fixtures rather than personal files.

## Single-pane Details width

**Scope:** Apply [#95](https://github.com/bcinarli/pane-peek/issues/95) under [A35](spec.md#browser-layout-modes-and-details-sizing) and the [Details width decision](../../decisions/2026-10-22-single-pane-details-width.md): 66% in One Pane and 50% in Two Panes, bounded by visible browser minimums/dividers. Dragging, keyboard adjustment and Expand share these limits; Restore, preferred-width recovery, saved expansion and retained browser/editor state remain intact. Fresh windows use expanded One Pane with a compact preferred Restore width. Acceptance includes native sizing, mode/resize recovery, restoration and affected accessibility.

## Title-bar interaction

**Scope:** Address [#101](https://github.com/bcinarli/pane-peek/issues/101) through public native window styling. Keep empty title-bar areas draggable and retain the configured double-click action, accepted colours, toolbar controls and independent windows. Validate both pane layouts, window sizes and appearances; keep dragging and double-click outcomes separate.

## Fresh single-pane windows

**Scope:** Implement [#91](https://github.com/bcinarli/pane-peek/issues/91) under A26/A27/A35 and the [fresh-window decision](../../decisions/2026-10-22-single-pane-details-width.md). Use One Pane with expanded Details for clean launch and explicit New Window while preserving saved modes, legacy-record fallback, directory access and window/draft independence. Validate both modes across final-window close/Dock reopening and quit/relaunch, plus expanded fresh layout, Restore to the compact preferred width and affected native/accessibility checks.

## Stable review signing

**Scope:** Add explicit certificate signing to the isolated sandbox review build under the [review-signing decision](../../decisions/2026-10-22-stable-review-signing.md). Accept exact Apple Development or Developer ID Application fingerprints, validate before building and verify the selected certificate, bundle seal and existing sandbox capabilities. Retain ad hoc review mode without a selected certificate and preserve production release signing/notarisation. Validate identity reuse across different executables and saved access after the first container approval. Folder-loading changes use a separate unit.

## Directory listing metadata

**Scope:** Reduce repeated per-entry directory checks and unnecessary URL resolution while preserving A1–A4/A30 and sandbox link boundaries. Reuse enumerated URLs and available type metadata, retaining independent unavailable-field handling and target resolution only where links may be followed. Compare the same disposable directory before/after, preserve package/hidden/date/size semantics and review a signed native build. Progressive listing, shared caches and deferred hidden-pane loading are separate work.

## Local release packaging

**Scope:** Extend the existing Node bundler with an explicit release mode. Build optimised arm64 code, use a fresh package directory under `.build/`, and produce a version/build-labelled ZIP and SHA-256 checksum. Keep the default development build unchanged and reuse the current metadata, assets and offline notices.

**Scope:** Implement release argument handling, consistent Swift configuration/architecture selection, isolated bundle output and archive/checksum generation. Add contributor instructions and inspect the real build/archive rather than tests that mirror the script. Reject unsupported arguments before build tools run.

## Release preparation

Allocate release metadata before Developer ID signing, hardened runtime, notarisation and final archive/checksum generation. Certificate-backed signing, notarisation and installation checks require active Apple Developer membership and the required credentials.

### Release numbering

**Depends on:** [Release packaging PR #45](https://github.com/bcinarli/pane-peek/pull/45) merged into `main`.

**Scope:** Add an explicit release-preparation action that automatically increments the build number in `version.json` when preparing a new distributable build. Select the release version deliberately; change it only when explicitly requested. Ordinary development builds and local `--release` rebuilds retain both values.

### GitHub release preparation

**Depends on:** Release packaging and numbering merged into `main`.

**Scope:** Add a manually triggered workflow for an explicit full commit SHA on `main`. Require successful exact-commit main build/test and privacy runs, reuse the assigned metadata and existing release bundler, and upload only the DMG, ZIP, checksums and app release notes as review artifacts. Reuse the selected version's app changelog entry, or label Unreleased content as draft. Keep procedural status and release checklists in contributor instructions. Keep repository permissions read-only, actions pinned and checkout credentials unpersisted. Preserve both existing required checks.

### Developer ID signing and Hardened Runtime

**Depends on:** Release packaging, numbering and GitHub preparation merged into `main`; a valid local Developer ID Application signing identity.

**Scope:** Add explicit release-only signing with an exact identity fingerprint. Validate the identity before building, sign the completed bundle with Hardened Runtime and a secure timestamp, and verify the seal, selected certificate, runtime, timestamp and exact approved sandbox entitlements before ZIP/checksum generation. Preserve the development build mode, local review packages and existing metadata. Keep credentials outside the repository.

### Notarisation and stapling

**Depends on:** Developer ID signing merged into `main`, current reviewed app fixes and a configured local notary Keychain profile.

**Scope:** Extend signed release packaging with explicit notarisation, save resumable submission state, check Apple's status/log and matching arm64 ticket, staple/validate the app and reverify its unchanged signature before final archive/checksum/output generation. Reuse the existing metadata preparation and packaging contracts. Select the release version deliberately and reserve a fresh build before creating the candidate.

### Hosted signing and notarisation

**Depends on:** Local signing and notarisation/stapling merged into `main`, a `github-release` environment allowing only the main branch, and configured release credentials.

**Scope:** Connect the existing manually dispatched exact-source/CI gate and release tests to temporary hosted credential setup, the signed/notarised bundler and cleanup. Keep signing secrets out of PR CI and raw diagnostics. Validate the identity within the temporary Keychain, explicitly select it for notarisation, and expose final outputs only after credential removal. Add retryable always-run cleanup and verify the extracted signed/ticketed package before artifact upload. Preserve existing metadata and local build modes; do not create tags or releases.

### DMG packaging

**Depends on:** Hosted signing/notarisation and downloaded-app verification merged into `main`.

**Scope:** Add a themed read-only DMG to release packaging while retaining ZIP and its checksum. Reuse the accepted Macchiato roles and existing logo/icon. Generate a portable Finder layout with the app, arrow and Applications shortcut; preserve native Finder chrome and keyboard operation. Integrate Developer ID container signing, resumable notarisation/stapling, mounted-package verification and the protected hosted artifact allowlist. Reuse assigned app metadata.

### Final release candidate

**Scope:** Reserve the selected version/build through the existing preparation tool and prepare an app-only initial-release changelog. Keep changes under Unreleased until the actual publication date is known. Reuse the existing DMG/ZIP packaging and notes generator without changing app behaviour or release automation.

### App Store sandbox and file-access design

**Scope:** The [access design](../../notes/2026-10-20-app-store-sandbox-design.md) defines folder permission, saved access and operation lifetimes for the shared sandboxed distribution model. Accepted MVP behaviour remains binding.

### App Store sandbox navigation

**Scope:** An isolated sandbox review build with explicit folder permission and navigation in both panes. Acquired scopes follow active listings and in-flight readers; stale choices cannot replace newer navigation. Home uses the account location independently of the app container.

### App Store saved folder access

**Scope:** Persist capability-aware folder grants and bookmarks for remembered directories in the review app's container. Restore each directory through its bookmark, reject a changed file/volume identity, refresh stale data while access is held and preserve unavailable records for reconnection. Reuse the existing window layout and last-active-window policy; explicit New Window retains the Home/Home default.

### Root navigation bookmark follow-up

**Scope:** Correct [#79](https://github.com/bcinarli/pane-peek/issues/79) while preserving directory-specific, identity-checked bookmarks, access capabilities, scope lifetime and cancellation. Validate the root breadcrumb and Go to Folder under remembered access and after relaunch.

### App Store sandbox favourites

**Scope:** Enable the existing favourites controls in the sandbox review channel. Save a bookmark with each favourite and reconcile its displayed location after successful identity-checked navigation. Legacy paths and unavailable bookmarks remain reconnectable and removable. Reconnection to a different folder opens that selection without replacing the saved favourite.

### App Store sandbox text previews

**Scope:** Enable existing read-only UTF-8 text, syntax highlighting, Markdown and item metadata in the sandbox review channel. Each selection retains its listing's access until its readers finish, independently of navigation or window closure. Keep existing byte limits and stale-result guards; reject file-link content before target reads.

### App Store sandbox image previews

**Scope:** Enable existing read-only image thumbnails in the sandbox review channel. Retain the selected folder's access through decoding, including cancellation and superseded selections. Reject listed and replaced file links before reading their targets; preserve the existing byte, pixel and thumbnail limits and default GitHub behaviour.

### App Store sandbox video previews

**Scope:** Enable the existing paused native video player in the sandbox review channel. Retain granted access through preparation, playback and pending reads; stream bounded ranges from an opened read-only file so later path replacement cannot redirect playback. Reject file links and external media references, stop obsolete players before releasing their access, and preserve default GitHub behaviour.

### App Store sandbox Quick Look

**Scope:** Enable the existing native Quick Look panel in the sandbox review channel. Preview items retain their granted access and opened-file identity through native teardown. Follow displayed selection and window ownership; reject file links and unavailable or special items before handing them to the system.

### App Store sandbox editing and safe Save

**Scope:** Enable the existing text editor and atomic Save with a read/write containing-folder grant. Preserve legacy read-only bookmarks and require an explicit upgrade before editing; remember new write grants without widening unrelated locations. Drafts and Save retain access through refresh and cleanup. Preserve the editor and native Undo when its saved file is unchanged, while retaining external-change and dirty-draft safeguards.

### App Store sandbox file operations

**Scope:** Enable New Text File/Folder, Rename, Copy/Move to Other Pane and system Trash through the existing operation workflows. Copy requires source read and destination write access; mutations require writable source parents. Capture and retain folder grants through permission and naming prompts, dirty/collision decisions, filesystem work and recovery/refresh. Delayed permission responses must not retarget requests or publish stale errors.

### App Store sandbox clipboard, drag and Finder integration

**Scope:** Enable native file clipboard and drag/drop transfers through the existing operation pipeline. Retain exported source grants until clipboard replacement or native drag completion, and capture incoming native references and the receiving folder before suspension. Acquire containing-folder read/write access where a file-only grant cannot cover preflight or mutation; reject sources replaced during permission decisions. Finder handoffs retain their captured grant and reveal listed links without following their targets.

### App Store executable-file and quarantine compatibility

**Scope:** Preserve executable permissions through Copy, Move and atomic Save. Carry existing quarantine metadata to the private Save staging file in the ordinary channel. The sandbox channel delegates quarantine to macOS through an explicit Save policy; it must not rewrite flags, remove attributes or retry denied metadata writes with weaker protection. Preserve source identity checks, cancellation and failed-save drafts.

### App Store sandbox volume compatibility

**Scope:** Exercise existing Copy, Move and system Trash with separately granted folders on different mounted filesystems. Preserve source identity, no-overwrite publication, executable permissions, link-as-link handling and recoverable failure reporting. Trash failure must retain the source without permanent deletion.

### Shared sandbox distribution readiness

**Scope:** Follow the [production sandbox decision](../../decisions/2026-10-20-production-sandbox-distribution.md) for GitHub and App Store releases. Manual setup replaces automatic migration. Preserve production identity, existing preferences, user files and published downloads; legacy paths do not grant access.

**Sequence and gates:** Accept production sandbox packaging and first-launch/relaunch behaviour, then revalidate hosted Developer ID signing, notarisation and downloaded DMG/ZIP installation. Prepare Store signing, provisioning and submission separately. Refresh the final candidate from current main after all intended app features merge, reserve candidate metadata and repeat validation, including the added features under the production sandbox, before submission. Each unit, manual acceptance and publication retains its own approval gate.

### Production sandbox packaging

**Scope:** Enable the accepted folder-access model in release packages under the production identity. Share the exact entitlements from the [WebKit capability decision](../../decisions/2026-10-20-webkit-sandbox-capability.md) with the isolated review build; sign local review packages ad hoc and Developer ID packages with Hardened Runtime and a secure timestamp. Fail closed on missing, disabled or additional entitlements. Retain ordinary development behaviour, Home default, assigned metadata, resources and both DMG/ZIP formats. Validate fresh setup and saved access after relaunch without importing or deleting unsandboxed preferences.

**Limits:** This unit prepares packaging from its reviewed source. Final feature-integrated candidate validation, hosted downloads, Store signing/provisioning and upload remain separately gated.

### App Store archive and signing preparation

**Scope:** Build a native arm64 Xcode app archive from the maintained app/core sources and shared assets, without duplicating source files. Derive release metadata and minimum macOS version from their existing owners. Preserve the production identity and sandbox capabilities; keep the core library out of the archive's installable products. Reuse offline notices and privacy documents.

**Signing and export:** Local unsigned archives provide an ad hoc signed sandbox app under the separate review identity. Store signing uses an explicit current Mac App Store profile and exact local application/installer identities. Require the profile's application/team identity in addition to the approved sandbox capabilities. Export locally with manual signing and fixed metadata; reject upload actions and automatic provisioning changes. Verify the archive, exported app/profile and installer signatures before reporting success.

**Gates:** Signed export requires installed signing assets. Manual acceptance, the feature-integrated final candidate, App Store validation/upload and submission remain separate. Existing native macOS 26, clean-profile and broader accessibility limits remain explicit.

### App Store 1.1.0 candidate and app record

**Scope:** Reserve version 1.1.0 and build 8 through the existing metadata tool. Build the native archive and local Store export from current main with its merged app features, unchanged production identity and approved sandbox capabilities. Keep the app-only changelog under Unreleased until publication.

**App record and acceptance:** Prepare the macOS App Store Connect record for the production identifier and selected version. Verify candidate metadata, signatures, profile and resources, and provide the isolated review app. Manual candidate acceptance, binary upload/server validation and review submission retain separate gates. The 1.0.0 acceptance waiver does not extend to this candidate.

## CI and merge checks

**Scope:** Implement the [accepted CI and merge policy](../../decisions/2026-10-17-ci-and-merge-checks.md), using the existing build/test commands. Release automation is excluded.

### CI workload isolation

**Scope:** Keep CPU-heavy highlighting stress tests from starving browser-test controllers. Run highlighting suites and their complete complement in separate phases, retaining parallel execution within each and the existing listing/sort guards. Explicit test selections and queries remain single-pass.

### Editor test gate lifecycle

**Scope:** Coordinate controlled editor work through captured requests and explicit results, with scoped cleanup of pending waiters and owned tasks. Preserve late completion after worker cancellation and stale-result assertions. Use a test-wide hang guard independently of operation ordering. Other gate migrations and CI execution changes retain separate units.

### Restoration timeout coordination

**Scope:** Correct the restoration timeout self-test's observation order without changing the application, read gate, CI triggers or credential handling.

**Scope:** Await the gate operation's exact error before checking terminal state. Exercise immediate and delayed timeouts for both an unreleased read and missing reads. Replace the one-second result poll with direct completion, retaining every error/state assertion and a separate test-wide hang limit.

## Privacy and secrets checks

**Scope:** Enforce the existing repository privacy boundary with one shared offline checker and narrowly scoped dummy-data exceptions. Preserve intentional system paths, public attribution and the confirmed design examples. Runtime privacy documentation is a separate workstream.

## Milestones

| Milestone | Tasks | Observable result |
| --- | --- | --- |
| M1 Browsing | T01–T04, T14, T15 | Inspect the accepted layout, navigate, sort/filter, select, copy paths and use shared favourites. |
| M2 Inspection, editing and layout | T05–T07, T19 | Inspect/edit safely, switch one/two browsers and expand Details. T19 follows T07 as a separate task. |
| M3 File operations | T08–T13 | Add create, rename, copy/move, Trash and drag/drop to established context actions. |
| M4 Windows and persistence | T16–T17 | Use independent windows and restore the last active window’s directories and working layout across Dock reopening and relaunch. |
| M5 MVP acceptance | T18 | Reproduce build/run and complete acceptance evidence. |

At milestone boundaries, consider a bounded code-quality analysis using Bilal’s `code-quality-analysis` skill. Review the findings before planning remediation. If the findings warrant improvement work, use the `cluster-work` skill to turn the reviewed findings into coherent, sequenced clusters with scope, dependencies, high-value validation and exit criteria. Obtain approval before implementing any cluster.

Tighten followed by probe remains the default after every code unit and every other work item with meaningful output, including analysis and cluster plans. Apply these passes before presenting the output; milestone analysis does not replace them.

Correctness findings block milestone acceptance. Optional maintenance groups may be deferred with rationale. Existing guidance permits small duplication when an abstraction would be harder to understand; for PanePeek, prefer reusing the existing function whenever the behaviour is actually equivalent.

## Design checkpoint

Use the [accepted draft references](../../design/001-mvp/README.md) and the [spec's UI requirements](spec.md#accepted-ui-design) before coding further UI. The implementation order is T01 → T02 → T03 → T04 → T14 → T15 → T05–T07 → T19 → T08–T13 → T16–T18. Existing task IDs remain stable.

Review the T01 shell against the accepted balanced layout before T02. If it was implemented against an earlier draft, any styling/structure alignment is a separately approved T01 unit. Design approval does not complete the shell's native manual checks. Verify the fresh single-pane layout beside Details, native appearance and restrained shared controls; add functional breadcrumbs/stars only with their mapped tasks.

Path copying and persistent favourites move into M1 so directory navigation and absolute paths can be reviewed before file mutations. T14 establishes context targeting and paths; later operation tasks add their own handlers rather than waiting for a second menu implementation. A18 remains partial until all its operations exist. T07 integrates dirty-document guards with the already available favourites and navigation.

T01 covers static header/Details alignment and development icon preparation using the accepted SVG artwork. Preserve the original peeking-P concept. T18 refines the icon for production and checks small-size/native appearance. The reference raster is not itself a completed app icon.

## Tasks



### T01 Launchable application shell

**Depends on:** Accepted spec and approval for T01.

**Scope:** Create the package, minimal native app, app-bundling script and run instructions. Show two pane areas and a far-right Details sidebar. Review the shell against the accepted draft under the design checkpoint; approve any alignment as a separate unit. Use the existing checkout; do not create another repository.

### T02 Directory browsing and breadcrumbs

**Depends on:** T01.

**Scope:** Implement listing and two independent navigable panes with chooser, Go to Folder/Command-L path entry, parent action, Home, directory double-click and compact root-to-directory breadcrumbs. Add the thin focused-pane underline and shared-action targeting without pane labels or duplicated menus. Favourite stars become functional in T15.

### T03 Sorting and hidden visibility

**Depends on:** T02.

**Scope:** Add per-pane clickable Name/Modified headings and relative/exact dates under A2/A30. Put hidden visibility and Refresh in shared actions targeting the focused pane while preserving independent settings. Classify packages/links and retain selected URL identities.

### T04 Multiple selection and primary item

**Depends on:** T03.

**Scope:** Add Command-click, Shift-click and Select All. Track a primary selected item and show its name in the sidebar while full preview is pending.

### T14 Context actions and copied paths

**Depends on:** T04. Execute before T15/T05.

**Scope:** Establish context targeting and Copy Absolute/Relative Path for one/multiple items. Add shared Copy Directory Path and the selected absolute path with a small copy action in Details, even before full metadata. Later T08–T12 add creation, Rename, Copy/Move and Trash handlers to these same menus; omit unavailable operations in this stage.

### T15 Persistent favourites

**Depends on:** T14.

**Scope:** Add per-pane favourite stars and the shared Favourites menu. Persist shared paths in an isolated local preference store with deduplication and stale-path handling. Stars target their own pane; menu navigation targets the focused pane.

### Favourites menu labels follow-up

One unit simplifies both menu-bar opening and removal labels to folder names, adding the shortest distinguishing parent-path suffix only for duplicate names. Keep filesystem root `/`, full-path help/accessibility, saved order, unavailable favourites and existing guarded actions. Cover duplicate/deep-parent/root labels and removal-driven relabelling with red/green tests; run existing favourites/navigation regressions, build and review the native menu's labels, keyboard access and accessible paths. [Evidence](evidence/favourites-menu-labels.md) owns validation and the separate manual-review gate.

### Browser Edit menu follow-up

One unit adds native browser Copy/Paste, Edit > Move Item Here / Option-Command-V and File > Move to Trash / Command-Delete. Reuse local-file pasteboard parsing and guarded transfer/Trash execution; capture the receiving directory at submission. Support single-pane operation, Finder and independent windows without intercepting text/rename-field commands. File Cut and file-operation Undo/Redo are excluded.

### Browser Cut/Paste follow-up

One additional unit implements the [accepted file Cut/Paste decision](../../decisions/2026-10-19-browser-file-cut-paste.md). Add native Command-X without immediate filesystem mutation; let Command-V move only the app's matching pending Cut selection. Preserve Option-Command-V, ordinary Copy/Paste, Finder file URLs and text editing. Bind intent to clipboard revision/content across PanePeek windows; consume relocated sources accurately without replacing a newer clipboard. File-operation Undo/Redo stays excluded.

### T05 Details metadata sidebar

**Depends on:** T15 (completes the proposed M1 sequence).

**Scope:** Show metadata below the preview area, including dates, path, permissions, owner/group, type and available size. Retain T14's visible selected absolute path and copy action; reuse its path format/clipboard behaviour. Handle unsupported previews and symlinks.

### T06 Read-only preview and highlighting

**Depends on:** T05.

**Scope:** Load bounded UTF-8 text and add read-only lexical highlighting for all [A15 languages](spec.md#details-sidebar-and-preview-editor), with plain-text fallback. The [2026-10-10 scope extension](../../decisions/0006-extended-syntax-highlighting.md) adds configuration and code formats. Split loader and language support into small approved units; do not batch them past review gates. The [further scope extension](../../decisions/0007-script-query-and-build-highlighting.md) adds scripts, queries and build files.

### TypeScript preview classification follow-up

One unit under A10/A15: give `.ts`/`.mts` text priority over system video types, retaining the existing loader and highlighter. Check both letter cases, editable highlighted text, existing `.mjs` support and unchanged MP4/MOV/M2TS routing. Build and review Preview/Edit in the running app before acceptance; commit and publication remain separate gates.

### Additional file previews

Implement the [accepted scope](../../decisions/2026-10-20-additional-file-previews.md) in this order. Reuse the existing Details presentation and guarded text editor. Each task needs explicit coding approval, targeted behavioural checks, a packaged running-app review, affected accessibility checks, tighten then probe, and separate commit/publication gates. These units may continue on the same isolated feature branch after the preceding unit is reviewed and committed; publication remains separate.

| Task | Scope | Dependencies and exit |
| --- | --- | --- |
| Markdown front matter | A36: recognise leading delimited metadata and render it literally with existing YAML colours before the Markdown body. | Existing Markdown renderer and safe editor. Check malformed/unclosed blocks, delimiter boundaries, BOM/line endings, literal metadata, draft rendering and source preservation. Review light/dark presentation, selection/copy, keyboard, enlarged text and VoiceOver. |
| SVG preview and source editing | A37: static image preview plus XML-highlighted source Edit. | Reviewed/committed Markdown unit. Confirm native decoder fidelity on supported macOS versions, bounded resource use, blocked external references, source fallback and retained draft/save behaviour. |
| PDF preview | A38: read-only native document viewer. | Reviewed/committed SVG task. Check multipage navigation, resizing/zoom, unavailable/locked/corrupt/large documents and stale-load cleanup. |
| Static HTML preview | A39: offline rendering with bounded local CSS/images/fonts plus existing source Edit. | Reviewed/committed PDF task. Verify blocked scripts, remote subresources and unintended navigation/local reads, alongside current-draft rendering and existing editor safeguards. |

The [task tracker](tasks.md) owns implementation/manual-review state. The [validation table](validation.md#additional-file-previews) owns A36–A39 acceptance. SVG, PDF and HTML may need smaller approved units if their implementation crosses a review boundary.

### Markdown link policy

**Scope:** Apply A36’s HTTP/HTTPS-only activation policy to Markdown links and image descriptions. Keep native text selection/copy and source editing intact. Validate rendering and native link activation alongside Preview/Edit state, then review the packaged app.

### T07 Preview editor toggle and safe saving

**Depends on:** T06.

**Scope:** Add Preview/Edit mode with the same language highlighting, dirty state, native undo and explicit Save. Guard selection/navigation/close/quit, including shared actions, Home, breadcrumbs and favourite navigation. Preserve encoding/permissions and detect disk changes before saving.

### Syntax-highlighting flashes

**Scope:** Correct [#90](https://github.com/bcinarli/pane-peek/issues/90) under A11/A15. Retain native colours while asynchronous highlighting runs, publish results only for their current document/draft and refresh completed results even when token ranges are unchanged. Preserve editing, composition, Undo, selection and scroll. Use delayed-result regressions and running-app review; lexical/parser changes and broader optimisation are separate.

### Save permission preservation follow-up

**Scope:** Preserve file permissions during ordinary and sandbox Save. Retain existing conflict handling and failed-save drafts.

### Save ownership preservation

**Scope:** Preserve file owner and group during ordinary and sandbox Save. Retain existing permissions, conflict checks and failed-save drafts.

### T19 Browser layout modes and expandable Details

**Depends on:** T07 accepted and its dependency changes merged to `main`. This separate feature branch/task follows T07; it does not add work or acceptance checks to the parallel T07 implementation.

**Scope:** Implement A34/A35 using the existing native split container, browser states and editor. Mode, presentation order and sizing belong to the window. Preserve both browsers and the existing document rather than recreating them during layout changes. Keep macOS window minimums; preview-host stacking is not a native layout requirement. Relaunch persistence belongs to T17.

### Details preview height follow-up

**Scope:** One separately approved UI unit under A31: let Preview/Edit fill the height remaining after other Details content, retaining metadata below it and a usable minimum with outer scrolling. Reuse the native text view and existing controls.

### T08 New text file and folder

**Depends on:** T19.

**Scope:** Add New Text File/New Folder to the focused pane through shared directory actions and pane background context menus. Implement reusable name/collision validation, creation and selection of the result.

### T09 Rename and affected document handling

**Depends on:** T08.

**Scope:** Add single-item Rename, including its context action. Reuse name validation and guard affected open documents in the current window.

### T10 Copy selected items to the other pane

**Depends on:** T09.

**Scope:** Add Copy to Other Pane to the established file context menu only when both browsers are visible; disable and reject single-pane requests. Use destination snapshots, whole-request preflight, asynchronous execution, collision/ancestry checks and accurate partial outcomes. Do not add selection-triggered transfer buttons.

### Same-folder copies

**Scope:** Same-folder copy receiving routes allocate unused numbered names under [#94](https://github.com/bcinarli/pane-peek/issues/94) and the [copy contract](../../decisions/2026-10-22-same-folder-copies.md), with batch reservations, captured identities, sandbox access, affected-document handling and honest partial outcomes. Ordinary collision handling and Move/Cut semantics apply. Native acceptance covers repeated/multiple copies, both layouts, same-folder panes/windows, text-field routing and accessible outcomes.

### Duplicate menu

**Scope:** Duplicate is available in the item context menu and selected-row accessibility actions under [#94](https://github.com/bcinarli/pane-peek/issues/94). It uses A17 context targeting and the guarded same-folder copy path in either layout, with captured selection/destination, sandbox access and affected-document handling. Clipboard contents and Cut intent are preserved. Native acceptance covers pointer and keyboard menu use, multiple selections, folders, both layouts and accessible names/state.

### Context-menu grouping

**Scope:** The item menu follows A18’s ordering, separators and Rename label, with guarded selection targeting, contextual enabled states and keyboard/accessibility access.

### T11 Move selected items to the other pane

**Depends on:** T10.

**Scope:** Add Move to Other Pane when both browsers are visible, with move confirmation and the existing transfer flow. Reuse single-pane rejection and captured destinations. Cover cross-volume copy/remove failures and dirty editor coordination.

### T12 Delete to Trash

**Depends on:** T11.

**Scope:** Add confirmed Move to Trash for selections, including the context action. Reuse mutation guards, result reporting and refresh.

### T13 Drag and drop with Finder

**Depends on:** T12.

**Scope:** Connect drag/drop to the existing transfer flow. Target visible browsers only. Support selections, copy-first/Command-move semantics and local file URLs entering/leaving Finder, including a single visible browser.

### Native drag initiation follow-up

**Scope:** Correct T13's native source preparation and lifetime for AppKit's callback ordering. Allow an unselected clicked row through the existing guarded selection path, retain exported URLs until native session end and release preparations that export no writer. Preserve copy-first/Command-move, captured row order, dirty-draft guards and transfer coordination.

### Dark appearance follow-up

**Scope:** Apply the [accepted dark surface roles](../../decisions/2026-10-18-dark-macchiato-surfaces-and-controls.md) to app-owned panels, frame and floating content. Use dark Base labels on active Mauve-filled controls while retaining native Light, inactive and disabled presentation. Preserve the editor, muted browser selection and native control semantics.

### Transfer duplicate choices follow-up

**Scope:** Extend Copy to the [accepted collision choices](../../decisions/2026-10-16-browser-ui-and-preview-improvements.md#copy-and-move-collisions). Reuse Move's numbered/custom-name planning and regular-file replacement validation. Present Copy/Move choices horizontally in an owned native sheet, preserving accents and native name submission, Escape, focus and accessibility. Resolve the entire batch before writes, protect affected drafts and retain recoverable previous destinations. Copy never removes its sources.

### Attached collision-sheet backdrop follow-up

**Scope:** Apply the accepted Mantle role to the visible collision-sheet content when attached to its owner. Preserve native Light, horizontal actions, name focus, Return/Escape, dynamic appearance and accessibility. Keep transfer behaviour unchanged.

### Consistent confirmation sheets follow-up

**Scope:** Apply the [consistent confirmation-sheet decision](../../decisions/2026-10-16-browser-ui-and-preview-improvements.md#confirmation-sheets) to unsaved edits and Copy/Move collisions. Share the adaptive surface and horizontal action styling, with Cancel leading and Save/Keep Both trailing. Preserve all existing document and transfer decisions.

### Command-drag and Preview contrast follow-up

**Scope:** Reproduce the reported native Command-move failure while retaining working default copy. Correct operation negotiation without weakening source masks, dirty guards or transfer coordination. Keep Preview/Edit labels readable whenever the Dark Mauve selection remains visible during modifier/drag states; retain disabled semantics and native inactive presentation.

### T16 Independent windows and shared operation coordination

**Depends on:** T13 and T15.

**Scope:** Enable New Window with two retained browsers at home, one visible pane and expanded Details. Keep browser mode/order, Details width and pane/editor state per window; share favourites and coordinate conflicting file mutations and dirty documents.

### T17 Restore the remembered directory pair

**Depends on:** T16.

**Scope:** Persist A27's one remembered configuration for initial launch, Command-Q relaunch and Dock reopening after the final browser window closes. Handle unavailable paths independently and accept older preferences. Explicit New Window keeps single/home/expanded defaults even with no windows open. The [fresh-window decision](../../decisions/2026-10-22-single-pane-details-width.md) carries forward restoration and legacy-record compatibility.

### T18 MVP acceptance and build documentation

**Depends on:** T17 and completed milestone reviews.

**Scope:** Complete the accepted T20 refinements before final acceptance. Review and refine the T01 development icon for production as a separately approved unit. Run the full acceptance matrix from a clean build/checkout, including the app-wide accessibility baseline; finish setup/build/run, architecture, supported limits and validation evidence.

### T20 Browser UI and preview refinements

**Depends on:** Existing native browsing, Details, layout, favourites and operation flows on `main`.

**Scope:** Implement the [accepted refinements](../../decisions/2026-10-16-browser-ui-and-preview-improvements.md) as separately approved vertical slices. The spec owns the current behaviour; each remaining coding unit requires its own approval.

### Source-warning compatibility follow-up

**Scope:** Remove the ten source diagnostics from temporary save-path decoding, Quick Look controller callbacks and window-delegate forwarding without suppressing warnings. Preserve synchronous callbacks, forwarding, controller teardown and save behaviour. Build-script/toolchain search-path changes are separate.

### Linker-search-path compatibility follow-up

**Scope:** Use one Xcode environment for all app-bundler stages, honour explicit `DEVELOPER_DIR`, retain the default-Xcode fallback when Command Line Tools are selected and leave global selection unchanged. Resolve Swift and asset tools through `xcrun`; remove the invalid search paths by selecting the proper toolchain, without suppressing diagnostics.

### T21 App information and open-source documentation

**Scope:** Deliver the [accepted app-information requirements](spec.md#app-information-and-open-source-documentation) through five separately reviewed units. Preserve existing runtime boundaries and the independent CI workstream.

### About Macchiato appearance follow-up

**Scope:** Replace the system-owned standard panel with a small native app-owned panel because its content options do not expose the shared surface palette. Reuse the existing About content and adaptive colour roles. Keep one non-restorable panel, copyable version/build, functional links, native Light presentation and independent browser/draft ownership.

### Design and documentation refresh

**Scope:** Align the editable draft and its reference images with the current native UI. Refresh the native screenshots in README and the usage guide. Review those documents and CONTRIBUTING for consistent everyday wording, with reproducible issues as the preferred contribution and AI help for issue drafts.

## Acceptance traceability

| Criteria | Primary task evidence |
| --- | --- |
| A1, A3, A29 Navigation/breadcrumbs | T02; favourite stars T15 and dirty navigation T07 |
| A2, A4, A30 Sorting/visibility | T02–T03 |
| A5–A8 Transfers | T10–T11, with cross-window checks in T16 |
| A9 Affected editors | T07, T09–T13, T16 |
| A10, A15 Preview/highlighting | T06; Edit highlighting in T07 |
| A11–A14, A32 Editor/save/mode | T07, T16 |
| A16 Favourites | T15, dirty navigation T07 and shared windows T16 |
| A17–A18 Context menus/paths | T14 initially, operation handlers T08–T12; dirty targeting T07 and cross-window checks T16 |
| A19 Multiple selection | T04, then guard integration in T07 |
| A20 Batch preflight/partial outcomes | T10–T13 |
| A21 Drag and drop | T13, T16 |
| A22 Trash | T12, T16 |
| A23 Rename | T09, T16 |
| A24 Creation | T08 |
| A25 Mutation refresh/open directories | T08–T12, T16 |
| A26 Independent windows | T16 |
| A27 Directory/layout restoration | T17 |
| A28 Multi-window quit/edit conflicts | T07, T16 |
| A31, A33 Sidebar/details | T14 path/copy, T05–T07 metadata/content, refresh integration in T08–T12, T16 |
| A34 Browser modes/state/targets | T19; real transfers T10/T11/T13 and independent windows T16 |
| A35 Details sizing/state | T19; independent windows T16 and persistence T17 |
| UI refinements under A2/A7–A10/A16/A18/A22/A25/A31–A34 | T20 |
| Complete A1–A35 and clean build | T18, including accepted T20 refinements |
| App-wide accessibility baseline | Each affected UI unit; T18 consolidates applicability and evidence |

Each manual checkpoint must be exercised in the running application. Automated red/green evidence and manual observations are recorded separately; neither substitutes for the other.

## Project structure and practical constraints

Use an application target, a small testable core and meaningful tests. UI-specific behaviour belongs with the app unless separating a state transition materially improves clarity/testing. Grow the structure around real uses rather than generating an empty layer for every responsibility.

The expected surfaces are `Package.swift`, `sources/panepeek/`, `sources/panepeek-core/`, `tests/`, build/run support and repository documentation. Final names follow the implementation rather than binding the design prematurely.

Swift package plus a small bundling script is the [accepted foundation](../../decisions/0004-swift-package-application.md). A conventional Xcode app project is the fallback if native integration checks expose a concrete limitation. Record actual toolchain and launch/lifecycle evidence for the affected task. Do not install tooling without direction.

Execution state lives in [tasks.md](tasks.md). Record criterion verdicts in [MVP validation](validation.md) and checks in the relevant task evidence file. Apply [shared review gates](../../validation/checklist.md). Use the registered milestone skills listed in [workflow guidance](../../prompts/README.md).

## Stop conditions

Task implementation follows the [feature-branch and PR decision](../../decisions/0002-feature-branches-and-prs.md). Start from `main` with dependency changes verified; use a separate task feature branch and a PR targeting `main`. Manual task acceptance and PR merge are distinct states.

Stop the active task and present evidence if native lifecycle, file access, drag/drop or concurrency behaviour requires changing the spec. Do not bypass a documented safeguard to satisfy a happy-path demo.

Cross-volume tests must distinguish injected failures from real-volume validation. Finder controls outgoing drops. Atomic saves do not guarantee exclusion of simultaneous external writers. Preserve these limits in acceptance evidence rather than overstating safety.

Approval of this plan authorises its direction. Each task still has a coding review gate; optional milestone maintenance work, commit and push have separate approvals.
