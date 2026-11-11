# External change refresh implementation plan

Status: Proposed

The [spec](spec.md) owns behaviour, [tasks](tasks.md) owns execution and [validation](validation.md) owns acceptance. Apply the [shared checklist](../../validation/checklist.md) to each atomic unit. Scope acceptance does not authorise coding, commit, push or merge. Present meaningful test evidence and the running app for manual acceptance before proceeding to the next unit.

## Integration

Keep change detection separate from listing and preview. A small change-source service reports coalesced "changed" signals for a directory or file; consumers decide what to reread. Browsers reuse `BrowserState.refresh()` and its reload intent. Details reuses `PreviewState.load(_:)`, which already refuses to replace a dirty or saving buffer, and `TextFileSnapshot` version checks to decide whether the disk copy differs. Reuse `FolderAccess` / `DirectoryAccess` for access lifetimes and the `FileOperationCoordinator` to recognise PanePeek's own operations. Do not build a general filesystem event framework.

| Unit | Scope | Dependencies | Criteria |
| --- | --- | --- | --- |
| 1. [Change-source feasibility](#change-source-feasibility) | Select and prove the change source in the signed sandbox build, with a minimal coalesced signal for one directory and one file. | Existing folder-access baseline | E5, E6, E7 |
| 2. [Browser listing refresh](#browser-listing-refresh) | Watch displayed directories and refresh listings with retained view state. | Accepted Unit 1 | E1, E2, E5, E6, E8 |
| 3. [Details refresh](#details-refresh) | Reload clean documents and add the changed-on-disk notice for drafts. | Accepted Unit 1; Unit 2 reviewed | E3, E4, E5, E8 |

## Change-source feasibility

Compare FSEvents for the displayed directory with a `DispatchSource` file-system object source on the directory and file. Choose by evidence from the signed sandbox build, not by assumption. Cover security-scoped access and its lifetime, atomic-replace saves that change file identity, rename and removal of the watched item, network and cloud-backed folders, and sleep and wake. Establish debounce bounds, cancellation and release on owner teardown, and how PanePeek's own operations are recognised.

Use red/green tests against a controllable change source for coalescing, cancellation and stale-signal rejection. Real filesystem checks confirm the selected source; timing-dependent tests are not the primary evidence. If the existing sandbox capabilities cannot support reliable detection, record the limit and return for review before dependent units. Do not add entitlements or polling as a silent fallback.

## Browser listing refresh

Attach a watcher to each visible browser's displayed directory, following browser identity through layout changes, navigation, history and window lifecycle. Trigger the existing reload with coalescing. Leave active search results untouched. Defer updates during inline rename until it ends.

Validate creation, removal, rename and metadata changes from another process, bursts of many files, hidden-file and sort retention, selection pruning, removal of the displayed directory, two panes on the same directory, multiple windows and foreground reconciliation. Check focus, VoiceOver silence for routine changes and idle and burst resource use.

## Details refresh

Watch the file shown in Details. Reload clean documents in their current mode with scroll retention where the content allows; stop a playing video. For dirty or saving documents, show the changed-on-disk notice and keep the draft. Discard while the notice is shown loads the disk version; the notice clears after Discard or when the saved file returns to the baseline.

Validate rapid repeated external writes, atomic replacement, removal and type change, each supported preview type, Markdown and HTML previews of the current draft, PanePeek's own Save and rename, and Save conflict handling after the notice. Check keyboard access and a single VoiceOver announcement for the notice.

## Publication and acceptance

Each unit uses a feature branch and a PR targeting `main`; verify required dependency publication before dependent implementation. Apply tighten then probe before handoff. Record concise outcomes in `evidence/<task-slug>.md` when implementation begins; keep unexecuted native and accessibility checks Pending. Update [usage documentation](../../../docs/usage.md) and the changelog with the unit that changes behaviour. Commit, push, merge and release remain separate gates. Earlier release waivers do not cover E1–E8.
