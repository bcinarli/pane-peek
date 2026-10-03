# PanePeek MVP implementation plan

Status: Draft updated for the current spec and Bilal’s request for a visible, manually testable result after every task. The task sequence awaits approval; implementation has not started.

Target macOS 26+. Treat [spec.md](spec.md) as the behavioural source, with A1–A33 as stable acceptance references. Task identifiers describe implementation slices; they do not require criteria to be implemented in numerical order.

## Task workflow and exit gates

Every task is a vertical slice: implement only enough core behaviour and UI integration to exercise it in the app. There are no service-only tasks that defer all visual review to a later stage.

1. Obtain approval for the task scope.
2. For meaningful automated behaviours, observe an intentional failing test before writing the implementation. Record the command and failure reason, then the passing result. UI-only layout and packaging use manual/build checks rather than artificial tests.
3. Implement the smallest working change; refactor with tests green. Reuse established behaviour and keep comments short.
4. Run tighten, then probe after the code unit. Present a launchable app, run instructions, disposable fixture/setup steps, criteria covered, automated evidence and a short manual checklist.
5. Bilal tests the app and reviews the result. Wait for explicit approval before the next task.

The shared exit gate is: the build succeeds, the listed high-value tests pass, the listed visible result works, and Bilal accepts the manual review. An unchecked manual outcome remains pending. A test failure or skipped required check is not a passing exit.

Acceptance criteria may span tasks. Record them as Pending, Partially validated or Passed with evidence; mark Passed only after the entire criterion has been exercised. A partial UI shell does not claim the corresponding complete behaviour.

Use real temporary filesystem fixtures where possible. Restrict injection to reliably testing meaningful failure paths. Do not use Bilal’s working files for mutation tests. No commits, pushes, tool installation or release publishing are bundled into task approval.

## Milestones

| Milestone | Tasks | Observable result |
| --- | --- | --- |
| M1 Browsing | T01–T04 | Launch, navigate through breadcrumbs, sort/filter independently and select multiple items. |
| M2 Inspection and editing | T05–T07 | Read details and highlighted content; toggle into an editor and save safely. |
| M3 File operations | T08–T14 | Create, rename, copy/move, Trash, drag/drop and use context menus. |
| M4 Windows and persistence | T15–T17 | Persist favourites, use independent windows and restore the last directory pair. |
| M5 MVP acceptance | T18 | Reproduce build/run and complete acceptance evidence. |

At milestone boundaries, consider a bounded code-quality analysis using Bilal’s `code-quality-analysis` skill. Review the findings before planning remediation. If the findings warrant improvement work, use the `cluster-workflow` skill to turn the reviewed findings into coherent, sequenced clusters with scope, dependencies, high-value validation and exit criteria. Obtain approval before implementing any cluster.

Tighten followed by probe remains the default after every code unit and every other work item with meaningful output, including analysis and cluster plans. Apply these passes before presenting the output; milestone analysis does not replace them.

Correctness findings block milestone acceptance. Optional maintenance groups may be deferred with rationale. Existing guidance permits small duplication when an abstraction would be harder to understand; for PanePeek, prefer reusing the existing function whenever the behaviour is actually equivalent.

## Tasks

### T01 Launchable application shell

**Depends on:** Accepted spec and approval for T01.

**Scope:** Create the package, minimal native app, app-bundling script and run instructions. Show two pane areas and a far-right Details sidebar. Use the existing checkout; do not create another repository.

**Acceptance mapping:** Build and window layout.

**Manual checkpoint:** Launch the app and inspect the two panes and sidebar; close and reopen it.

**High-value validation:** Build/package/launch checks. No placeholder passing tests.

**Exit criteria:** A clean build produces a launchable app on macOS 26+; Bilal can inspect the intended layout using documented commands.

### T02 Directory browsing and breadcrumbs

**Depends on:** T01.

**Scope:** Implement listing and two independent navigable panes with chooser, path entry, parent action, directory double-click and clickable root-to-directory breadcrumbs.

**Acceptance mapping:** A1, A3, A29; listing portion of A2.

**Manual checkpoint:** Open different directories in both panes, click root and ancestors, use a long breadcrumb and try an invalid path.

**High-value validation:** Red/green for invalid-directory retention, pane independence and stale listing results. Use real directory fixtures.

**Exit criteria:** Navigation is visible and independent, long breadcrumbs remain usable, and failed navigation retains the last successful directory.

### T03 Sorting and hidden visibility

**Depends on:** T02.

**Scope:** Add Name/Last Modified sorting, direction controls, per-pane hidden toggles and Refresh. Classify packages/links and display modified time.

**Acceptance mapping:** A2, A4, A30.

**Manual checkpoint:** Sort a mixed fixture by each field/direction; reveal hidden items in one pane only and refresh.

**High-value validation:** Red/green for hidden metadata, independent sort state and deterministic ordering/ties.

**Exit criteria:** Selected items survive reordering; both sort fields work without changing the other pane; dot-hidden and metadata-hidden items obey the pane toggle.

### T04 Multiple selection and primary item

**Depends on:** T03.

**Scope:** Add Command-click, Shift-click and Select All. Track a primary selected item and show its name in the sidebar while full preview is pending.

**Acceptance mapping:** A19; selection input to A31.

**Manual checkpoint:** Select a range, toggle individual rows, select all and clear selection in each pane.

**High-value validation:** Red/green for selection identity and primary-item transitions. Avoid tests for native framework mechanics.

**Exit criteria:** The selection is independently usable in each pane and the sidebar visibly follows the primary selected item.

### T05 Details metadata sidebar

**Depends on:** T04.

**Scope:** Show metadata below the preview area, including dates, path, permissions, owner/group, type and available size. Handle unsupported previews and symlinks.

**Acceptance mapping:** A31, A33.

**Manual checkpoint:** Select a file, folder, package and symlink; compare metadata to Finder/file information and switch selections rapidly.

**High-value validation:** Red/green for meaningful metadata formatting, unavailable values and stale completions.

**Exit criteria:** Metadata describes the latest primary selection, remains visible without a preview and distinguishes a link from its target.

### T06 Read-only preview and highlighting

**Depends on:** T05.

**Scope:** Load bounded UTF-8 text and add read-only lexical highlighting for Swift, JavaScript/TypeScript, JSON, Python and Markdown, with plain-text fallback.

**Acceptance mapping:** A10, A15; preview part of A31.

**Manual checkpoint:** Preview each supported language, plain text, UTF-8 BOM, binary data and oversized content; rapidly change selection.

**High-value validation:** Red/green for size/encoding boundaries, stale loads and representative token ranges. Do not assert every colouring detail.

**Exit criteria:** Readable highlighted text appears at the top of Details; unsupported files show a useful state without losing metadata.

### T07 Preview editor toggle and safe saving

**Depends on:** T06.

**Scope:** Add Preview/Edit mode, dirty state, native undo and explicit Save. Guard selection/navigation/close/quit, preserve encoding/permissions and detect disk changes before saving.

**Acceptance mapping:** A11–A14, A32; single-window portion of A28.

**Manual checkpoint:** Edit, toggle back without losing changes, save, undo and try every dirty-prompt branch. Modify the file externally and attempt Save.

**High-value validation:** Red/green for save conflicts, byte/permission preservation, failed-save retention and guarded transitions.

**Exit criteria:** Preview/Edit retains buffer and undo state; cancellation works; external-change and permission errors retain edits. Save refreshes relevant metadata.

### T08 New text file and folder

**Depends on:** T07.

**Scope:** Add New Text File/New Folder to the active pane. Implement reusable name/collision validation, creation and selection of the result.

**Acceptance mapping:** A24; mutation refresh portion of A25.

**Manual checkpoint:** Create both item types, edit the new text file and try invalid names or an existing filename.

**High-value validation:** Red/green for name validation and no-overwrite creation using temporary directories.

**Exit criteria:** New items appear and are selected in the correct pane; invalid requests preserve existing data.

### T09 Rename and affected document handling

**Depends on:** T08.

**Scope:** Add single-item Rename, including its context action. Reuse name validation and guard affected open documents in the current window.

**Acceptance mapping:** A23; current-window portions of A9, A18, A25.

**Manual checkpoint:** Rename a file and folder, try case-only/colliding names and rename an edited file or its containing directory.

**High-value validation:** Red/green for collision handling, filesystem identity and dirty-transition cancellation.

**Exit criteria:** A renamed item has correct selection/details; open documents follow or close safely; rejected renames preserve the source and edits.

### T10 Copy selected items to the other pane

**Depends on:** T09.

**Scope:** Add selection copy with destination snapshots, whole-request preflight, asynchronous execution, collision/ancestry checks and accurate partial outcomes.

**Acceptance mapping:** A5–A8, A20 for copy; relevant A9.

**Manual checkpoint:** Copy files/folders/links in both directions, reject collisions/descendants and navigate while copying.

**High-value validation:** Red/green for source preservation, preflight with no mutation, symlink handling, stale destinations and partial-failure reporting.

**Exit criteria:** Copy uses the submitted destination, reports actual outcomes and refreshes affected panes without blocking navigation.

### T11 Move selected items to the other pane

**Depends on:** T10.

**Scope:** Add move confirmation and reuse the transfer flow. Cover cross-volume copy/remove failures and dirty editor coordination.

**Acceptance mapping:** A5–A9, A20 for move; relevant A25.

**Manual checkpoint:** Move a selection in both directions, cancel confirmation and try moving a dirty file or its containing folder.

**High-value validation:** Red/green for source preservation on failed copy, source-removal/cleanup failures, duplicate submission and preview identity after move.

**Exit criteria:** Successful moves update the listing and editor target; failed/partial moves report actual filesystem state. Distinguish injected cross-volume coverage from a real-volume check.

### T12 Delete to Trash

**Depends on:** T11.

**Scope:** Add confirmed Move to Trash for selections, including the context action. Reuse mutation guards, result reporting and refresh.

**Acceptance mapping:** A22; current-window portions of A9, A18, A25.

**Manual checkpoint:** Trash disposable files/folders/links, cancel confirmation, inspect Trash and exercise a dirty-document prompt.

**High-value validation:** Red/green for cancellation, unavailable Trash, symlink identity and partial results. Use an isolated test seam for failures; manual checks use only disposable fixtures.

**Exit criteria:** The action never falls back to permanent deletion; affected previews and directory panes reconcile safely.

### T13 Drag and drop with Finder

**Depends on:** T12.

**Scope:** Connect drag/drop to the existing transfer flow. Support selections, copy-first/Command-move semantics and local file URLs entering/leaving Finder.

**Acceptance mapping:** A21 within one window/Finder; A20.

**Manual checkpoint:** Drag between panes; repeat with Command; drag from/to Finder and attempt an unsupported payload.

**High-value validation:** Red/green for payload validation and operation choice/source-destination snapshots where controlled by PanePeek.

**Exit criteria:** Dragging uses the same transfer safeguards as buttons. Dirty buffers are resolved before outgoing drags; Finder-controlled behaviour is documented. Cross-window drops are checked in T16.

### T14 Context actions and copied paths

**Depends on:** T13.

**Scope:** Complete the core context menus with path copying and Copy/Move to Other Pane. Reuse existing Rename/Trash actions and background creation actions.

**Acceptance mapping:** A17, A18.

**Manual checkpoint:** Right-click outside/inside a selection, invoke each core action and paste single/multiple paths into another application.

**High-value validation:** Red/green for path bases, Unicode/spaces and selection ordering. Do not duplicate transfer tests for each menu entry.

**Exit criteria:** Clicked-item targeting and selection actions are correct; paths are plain strings from the originating pane. Menu ordering remains a UI choice.

### T15 Persistent favourites

**Depends on:** T14.

**Scope:** Add/remove/open shared favourites; persist them in an isolated local preference store with deduplication and stale-path handling.

**Acceptance mapping:** A16.

**Manual checkpoint:** Add/remove a favourite, navigate through it, relaunch and try a missing directory.

**High-value validation:** Red/green for persistence, equivalent-path duplicates and stale-entry retention.

**Exit criteria:** Favourites survive relaunch and navigation uses existing dirty guards; tests do not touch Bilal’s real preference domain.

### T16 Independent windows and shared operation coordination

**Depends on:** T15.

**Scope:** Enable New Window with both panes at home. Keep pane/details/editor state per window; share favourites and coordinate conflicting file mutations and dirty documents.

**Acceptance mapping:** A26, A28; cross-window A8, A9, A21, A25, A31.

**Manual checkpoint:** Open two windows, vary their settings, drag between them and edit the same file in both. Move/rename/trash a directory visible in the other window and attempt Quit with edits.

**High-value validation:** Red/green for window independence, conflicting operations, cross-window dirty cancellation and same-file save conflicts.

**Exit criteria:** New windows start at home; all existing workflows work across windows; quit cancellation retains edits and saves cannot target obsolete paths.

### T17 Restore the remembered directory pair

**Depends on:** T16.

**Scope:** Persist the last active window’s left/right directory pair. Restore it only in the initial window on relaunch and handle unavailable paths independently.

**Acceptance mapping:** A27.

**Manual checkpoint:** Navigate both panes, change active windows, quit/relaunch, remove a remembered test directory and open New Window.

**High-value validation:** Red/green for persisted pair selection, per-pane fallback and distinguishing initial restore from New Window.

**Exit criteria:** Relaunch restores the correct pair; unavailable paths fall back only in the affected pane; every new window still starts at home.

### T18 MVP acceptance and build documentation

**Depends on:** T17 and completed milestone reviews.

**Scope:** Run the full acceptance matrix from a clean build/checkout; finish setup/build/run, architecture, supported limits and validation evidence.

**Acceptance mapping:** A1–A33 and build/documentation.

**Manual checkpoint:** Follow the README from a clean build and exercise the complete workflow on disposable files, including multi-window quit/relaunch.

**High-value validation:** Run the meaningful suite once; add red/green regression tests only for newly identified behaviour defects. Do not broaden tests without a new risk.

**Exit criteria:** Each criterion has passing evidence or an explicitly accepted deviation; Bilal has manually reviewed all task outputs; clean build/package/launch succeeds.

## Acceptance traceability

| Criteria | Primary task evidence |
| --- | --- |
| A1, A3, A29 Navigation/breadcrumbs | T02 |
| A2, A4, A30 Sorting/visibility | T02–T03 |
| A5–A8 Transfers | T10–T11, with cross-window checks in T16 |
| A9 Affected editors | T07, T09–T13, T16 |
| A10, A15 Preview/highlighting | T06 |
| A11–A14, A32 Editor/save/mode | T07, T16 |
| A16 Favourites | T15 |
| A17–A18 Context menus/paths | T08–T14 |
| A19 Multiple selection | T04, then guard integration in T07 |
| A20 Batch preflight/partial outcomes | T10–T13 |
| A21 Drag and drop | T13, T16 |
| A22 Trash | T12, T16 |
| A23 Rename | T09, T16 |
| A24 Creation | T08 |
| A25 Mutation refresh/open directories | T08–T12, T16 |
| A26 Independent windows | T16 |
| A27 Directory restoration | T17 |
| A28 Multi-window quit/edit conflicts | T07, T16 |
| A31, A33 Sidebar/details | T05–T07, refresh integration in T08–T12, T16 |
| Complete A1–A33 and clean build | T18 |

Each manual checkpoint must be exercised in the running application. Automated red/green evidence and manual observations are recorded separately; neither substitutes for the other.

## Project structure and practical constraints

Use an application target, a small testable core and meaningful tests. UI-specific behaviour belongs with the app unless separating a state transition materially improves clarity/testing. Grow the structure around real uses rather than generating an empty layer for every responsibility.

The expected surfaces are `Package.swift`, `Sources/PanePeek/`, `Sources/PanePeekCore/`, `Tests/`, build/run support and repository documentation. Final names follow the implementation rather than binding the design prematurely.

Swift package plus a small bundling script remains the proposed foundation. A conventional Xcode app project is the fallback if the launch/lifecycle checks expose a concrete limitation. Verify the actual toolchain and package-based launch/lifecycle when T01 begins. Do not install tooling without direction.

Execution state lives in [tasks.md](tasks.md). Record acceptance evidence in [the validation checklist](../../validation/checklist.md). Use the registered milestone skills listed in [workflow guidance](../../prompts/README.md).

## Stop conditions

Task implementation follows the [feature-branch and PR decision](../../decisions/0002-feature-branches-and-prs.md). Start from `main` with dependency changes verified; use a separate task feature branch and a PR targeting `main`. Manual task acceptance and PR merge are distinct states.

Stop the active task and present evidence if native lifecycle, file access, drag/drop or concurrency behaviour requires changing the spec. Do not bypass a documented safeguard to satisfy a happy-path demo.

Cross-volume tests must distinguish injected failures from real-volume validation. Finder controls outgoing drops. Atomic saves do not guarantee exclusion of simultaneous external writers. Preserve these limits in acceptance evidence rather than overstating safety.

Approval of this plan authorises its direction. Each task still has a coding review gate; optional milestone maintenance work, commit and push have separate approvals.
