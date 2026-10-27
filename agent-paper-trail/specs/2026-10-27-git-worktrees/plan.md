# Git and agent worktrees implementation plan

Status: Active

The [spec](spec.md) owns behaviour, [tasks](tasks.md) owns execution and [validation](validation.md) owns acceptance. Apply the [shared checklist](../../validation/checklist.md) to each atomic unit. Scope acceptance does not authorise coding, commit, push or merge. Present meaningful test evidence and the running app for manual acceptance before proceeding to the next unit.

## Integration

Keep Git inspection separate from directory listing and text editing so missing tools cannot block either. Reuse `FolderAccess` / `DirectoryAccess` for permissions and lifetimes, `BrowserState` navigation guards, the existing toolbar/popover patterns and the retained `PreviewState` / native editor. Use a small shared read-only Git service with per-checkout snapshots; views consume repository state rather than invoking commands per row. Do not build a general source-control framework or runtime agent-plugin system.

| Unit | Scope | Dependencies | Criteria |
| --- | --- | --- | --- |
| 1. [Git access feasibility](#git-access-feasibility) | Apple Git capability, sandbox access and bounded read-only repository/status inspection with a minimal native review surface. | Existing folder-access baseline | G1, G2, G8 |
| 2. [Worktree browsing](#worktree-browsing) | Repository, known-location and custom discovery in one toolbar popover, with guarded navigation. | Unit 1 capability boundary; folder browsing remains independent of Git success | G1, G3, G8 |
| 3. [Pane Git information](#pane-git-information) | Per-pane branch area, status snapshots and file/folder decorations. | Accepted Unit 1 Git path; Unit 2 reviewed | G2, G4, G5, G8 |
| 4. [Unified diff](#unified-diff) | Read-only View Diff with labelled comparisons and glance-oriented navigation. | Accepted Unit 3 repository/status integration | G2, G6, G8 |
| 5. [Worktree review facts](#worktree-review-facts) | Local containment, change counts and worktree metadata with explicit uncertainty. | Accepted Units 1–4 | G2, G7, G8 |

## Git access feasibility

Prove Apple-provided Git in an actual signed sandbox build before depending on it for product UI. Detect installed tools without invoking an installation shim when tools are absent. Inspect ordinary repositories and linked worktrees whose common metadata needs a separate grant. Expose a minimal native repository/status result for review. Establish fixed executable/argument handling, bounded output/time, cancellation, access retention and a read-only/no-network execution policy.

Use red/green tests for capability outcomes, machine-readable parsing and stale-result/cancellation behaviour. Exercise a real disposable repository with staged, unstaged and untracked changes, detached/initial state, and inaccessible or missing common metadata. Check process behaviour in the signed app, missing-tool degradation and both package-build paths. A successful shell command outside the app is insufficient evidence.

If existing sandbox capabilities cannot support the approach, record the limit and return for architecture review before dependent Git implementation. Do not silently add libgit2, bundle Git or widen permissions. Worktree-folder browsing can proceed as a separately approved reduced unit using the optional-capability boundary.

## Worktree browsing

Combine registered worktrees from known/permitted repositories, Codex/Cursor/Claude/Windsurf/Hermes location hints and explicit bookmarked roots/checkouts in the toolbar popover. Support Antigravity, OpenCode and other harnesses through repository discovery and custom locations without assuming undocumented default roots. Keep harness attribution separate from Git validity, with Unknown harness retaining normal checkout capabilities. Reuse the Git service and a small location-hint table; no harness SDKs or executable integrations are needed.

Keep discovery bounded and access-aware, deduplicate across all sources, separate remnants from checkouts and retain unavailable saved locations. A registered path needs its own access before inspection/navigation. Reuse active-pane navigation and dirty-document guards. Specify enumeration/output bounds in this unit's implementation review.

Validate repository-local Claude/Hermes conventions, the Windsurf root, registered checkouts outside known roots and Antigravity/custom locations. Include shared `.worktrees` folders with unknown ownership, duplicate discoveries, absent applications, metadata-only folders and missing Git. Check cancelled grants/navigation, reconnection identity, saved-location removal without filesystem deletion, independent pane targeting, keyboard search and VoiceOver. Missing Git must leave known/custom folder browsing usable while repository enumeration and verified status remain unavailable.

## Pane Git information

Add the compact repository/branch area and status decorations to the existing pane views. Share background snapshots by checkout and retain pane identity through layout changes. Aggregate descendant changes from repository status; preserve nested repository/submodule boundaries. Refresh on explicit Refresh, foreground return and relevant file changes, rejecting older results. Use the spec's exact palette values and existing adaptive selection treatment.

Validate mixed staged/unstaged states, renames, conflicts, ignored files, deleted descendants, nested repositories and rapid navigation between checkouts. Review Light/Dark, narrow panes, selection/inactive states, larger text and accessible status descriptions. Choose readable status indicators where palette filename colours do not meet contrast requirements.

## Unified diff

Add View Diff beside Preview/Edit, keeping the native editor retained. Implement the three labelled comparisons, empty baselines and explicit conflict/binary/oversize outcomes. Bound source reads, diff output and within-line comparison work. Start with a unified layout showing change counts, compact expandable context, old/new line numbers and previous/next controls; no source-control mutation actions.

Validate staged-only differences when disk equals HEAD, initial/untracked files, line endings, absent final newlines, encoding/size limits and coherent refresh during external changes. Verify draft/Undo/selection/scroll retention, the saved-file notice, copying without presentation markers, keyboard navigation and VoiceOver. Review representative short edits and larger multiline replacements in the actual Details width.

## Worktree review facts

Extend discovered checkout rows/details with read-only metadata and local-base containment. Let the comparison identify an existing local ref; handle absent refs, detached commits and incomplete metadata honestly. Keep observation freshness visible and activity unknown. No removal or prune action is included.

Validate ordinary ancestry, non-ancestor and squash/rebase histories, clean checkouts with ignored files, unavailable worktrees and locked/prunable records. Confirm that no result claims remote merge status, stalled-agent status or deletion safety. Review keyboard/accessibility presentation and behaviour when Git disappears or access expires.

## Publication and acceptance

Each unit uses a feature branch and a PR targeting `main`; verify required dependency publication before dependent implementation. Apply tighten then probe before handoff. Record concise outcomes in `evidence/<task-slug>.md` when implementation begins; keep unexecuted native/accessibility checks Pending. Commit, push, merge and release remain separate gates. Earlier release waivers do not cover G1–G8.
