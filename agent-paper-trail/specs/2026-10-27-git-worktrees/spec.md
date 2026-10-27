---
status: Active
date: 2026-10-27
supersedes: []
superseded_by: ""
---

# Git and agent worktrees specification

## Scope

Provide quick local inspection of agent worktrees and repository changes within the existing pane browser and Details area. Include a Worktrees toolbar popover, per-pane repository information, Git status decorations and a unified View Diff mode. This package defines the read-only Git extension to the [native baseline](../001-mvp/spec.md#scope-boundaries).

Exclude Git mutations, worktree creation/removal/pruning, automatic cleanup, remote fetches, PR queries, agent orchestration and private agent-database integration. Diff has no editing, accept/reject, stage, revert or commit actions. Existing text editing and ordinary file operations retain their own safeguards; this work does not turn PanePeek into a source-control editor.

## Optional tools and local access

Use Apple-provided Git from installed Command Line Tools or Xcode. Add no bundled Git distribution, libgit2 or other third-party runtime dependency. Apple documents that [invoking Git on fresh macOS can prompt a developer-tools installation](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/); capability detection must avoid triggering that prompt. Do not install tools or alter developer-tool selection automatically.

When Git is missing, unsupported or cannot run, keep ordinary browsing, Preview/Edit and configured worktree-location navigation usable. Show a concise Git-unavailable explanation where Git information is requested; never display unavailable status as Clean or No changes. Retry capability detection on an explicit refresh. Installation guidance may explain the optional prerequisite without initiating installation.

Repository inspection is local and read-only. Preserve the [existing sandbox and network boundary](../../decisions/2026-10-24-github-release-updates.md#privacy-and-sandbox-boundary). Reads require retained grants for the checkout and any shared Git metadata outside it. A worktree folder grant does not imply access to its common repository. Missing access, missing objects and unsupported layouts produce explicit unavailable results. No permission bypass, extra entitlement or unsandboxed fallback is included.

Run bounded, cancellable background operations. Use fixed executable selection and argument arrays with literal path handling, stable machine-readable output and a controlled execution environment. Suppress optional repository writes, configured command execution, external diff/text conversion and implicit network fetching. Do not run agent setup scripts. Reject obsolete results after navigation, selection or repository state changes; incomplete reads must not establish a clean state.

## Worktree discovery and navigation

One Worktrees toolbar button opens a searchable popover grouped by agent and repository. Offer opening an agent's worktree location or a checkout in the active pane, through the existing navigation history, access and Save / Discard / Cancel guards. Search names and paths; retain keyboard operation and meaningful accessible labels.

Discover local worktrees regardless of which harness created them. Combine these sources and deduplicate their results:

- **Repository discovery:** When Git is available, read registered worktrees from repositories already opened or explicitly added, including checkouts outside known harness roots. A registration does not grant access to its checkout; obtain the required folder access before inspecting or opening it.
- **Known-location discovery:** Probe permitted documented roots and repository-local conventions for Codex, Cursor, Claude, Windsurf and Hermes Agent (Nous Research).
- **Custom locations:** Offer **Add worktree location** for roots or individual checkouts, including relocated folders and other harnesses. Antigravity and OpenCode are supported through repository discovery and custom locations; no default root is assumed for either.

Use bounded enumeration within these sources rather than a whole-disk search. Known-location conventions are:

| Harness | Discovery hint |
| --- | --- |
| Codex | The configured worktree root; `$CODEX_HOME/worktrees` convention, normally beneath the account's `.codex` directory. |
| Cursor | The account's `.cursor/worktrees` directory, grouped by repository. |
| Claude | `.claude/worktrees` beneath known repository roots. |
| Windsurf | The account's `.windsurf/worktrees` directory, grouped by repository. |
| Hermes Agent (Nous Research) | `.worktrees` beneath known repository roots; the directory name is shared with other tools and does not establish Hermes ownership. |

These are hints, not proof of installation or ownership. Remember explicit locations using the existing bookmark/access model, allow removal from the saved list without deleting files, and retain unavailable locations for reconnection. A different folder cannot silently replace a saved identity. Additional automatic harness-location hints require verified conventions; generic repository discovery does not require a new harness integration.

Keep harness attribution separate from Git validity. Use **Unknown harness** when ownership cannot be established; a valid checkout retains the same browsing, branch/status and diff capabilities. Installed-application hints are best effort and must not gate access to surviving worktrees. Deduplicate discoveries by canonical location/identity while retaining useful provenance. Separate verified linked worktrees from folders without a checkout, including metadata remnants. When Git is unavailable, known/custom locations remain browsable but their repository/worktree state is unverified. Do not infer activity or deletion eligibility from directory presence or age. No harness SDK or harness execution is required.

Location references: [Codex](https://learn.chatgpt.com/docs/environments/git-worktrees), [Cursor](https://prod.cursor.com/docs/cli/using), [Claude](https://code.claude.com/docs/en/worktrees), [Windsurf](https://docs.devin.ai/desktop/cascade/worktrees), [Hermes](https://hermes-agent.nousresearch.com/docs/user-guide/cli). [Antigravity](https://antigravity.google/docs/projects) documents worktree support; its default filesystem root is not assumed by this contract.

## Per-pane repository information and status

Show a compact information area beneath each pane's breadcrumbs when its current folder belongs to a repository. Include the repository name, current branch and changed-file summary. Subfolders retain the enclosing repository context; an explicitly entered nested repository uses its own context. Show a short commit identifier for detached HEAD and an honest initial-branch state when no commit exists. Hide the area outside repositories; distinguish inaccessible or unavailable Git information from a non-repository folder.

Keep information with browser identity through one/two-pane changes and independently across windows. Use one asynchronous status snapshot per checkout rather than one Git invocation per row. Refresh after relevant PanePeek file changes, explicit Refresh and return to the foreground. Retained results must indicate stale/unavailable state when refresh fails.

Decorate listed files for staged and unstaged modifications, additions/untracked files, renames and conflicts. Preserve both staged and unstaged facts when both apply. Ignored files are not ordinary changes. Folder indicators aggregate changed descendants within the inspected repository; deleted paths contribute to summaries/parent indicators without creating fictitious filesystem rows. Nested repositories and submodules are distinct boundaries, not automatically traversed content.

Use the exact [Catppuccin palette](https://catppuccin.com/palette/) roles below. These status accents do not replace the existing native Light surfaces, Macchiato Dark surfaces or muted selection treatment.

| Status | Role | Latte / Light | Macchiato / Dark |
| --- | --- | --- | --- |
| Added or untracked | Green | `#40A02B` | `#A6DA95` |
| Modified | Yellow | `#DF8E1D` | `#EED49F` |
| Renamed | Blue | `#1E66F5` | `#8AADF4` |
| Removed | Red | `#D20F39` | `#ED8796` |
| Conflict | Peach | `#FE640B` | `#F5A97F` |

Pair colour with status badges and accessible descriptions. Where a palette accent lacks filename contrast, retain readable text and use the accent in the indicator. Selected/inactive rows, enlarged text and Increase Contrast must remain legible. A folder with mixed changes exposes a summary rather than implying all descendants share one status.

## Unified View Diff

For changed supported text files, expose **View Diff** beside Preview / Edit in Details. The presentation is always unified and read-only, with selectable/copyable text. Preserve the retained editor's draft, dirty state, selection, scroll and Undo when switching views.

Default to **Since last commit**, comparing HEAD with the saved file. Offer **Staged** (HEAD to index) and **Unstaged** (index to saved file) in a secondary selector. Keep staged differences accessible even when saved content matches HEAD; label a no-difference result for its selected comparison. New/untracked files can show additions against an explicitly absent baseline. An initial repository without HEAD uses an empty baseline where meaningful, not a command failure presented as an empty diff.

Summarise changed sections and added/removed line counts, with previous/next-change controls. Show a small amount of context around each section and expandable unchanged ranges. Keep removed lines directly above added replacements; emphasise changed words within paired lines without implying semantic equivalence. Use old/new line numbers, plus/minus markers and the palette's addition/removal roles. Prefer a neutral explanation when a change cannot be represented as text. No generated prose interpretation or AI dependency is included.

Diff compares saved content. When the editor has a draft, show **Showing saved file; unsaved edits excluded**. Saving refreshes the comparison. External changes invalidate the result without replacing a dirty draft or bypassing existing Save conflict checks. Concurrent index/HEAD changes must not publish mismatched content as one coherent comparison.

Retain the existing UTF-8 / 1 MiB text-input boundary and bound generated output and computation. Binary, oversized, missing, conflicted or inaccessible content receives an explicit limitation; never silently truncate a diff or report unsupported content as unchanged. Do not follow file links beyond the existing preview/access policy. Diff metadata and line markers are separate from source bytes. [Git documentation](https://git-scm.com/docs/git-diff) owns the comparison semantics.

## Worktree review information

Show verified branch/detached-commit information, changed-file counts, locked/missing/prunable metadata and whether the checked-out commit is contained in a chosen local comparison branch. Identify the comparison ref and observation time; do not assume every repository has `main`. Local containment is not remote PR-merge status, and squash/rebase merges may not preserve ancestry. No automatic fetch is allowed to refresh that evidence.

Keep agent activity **Unknown** unless a separately approved supported integration supplies actual evidence. Modification time does not establish Active or Stalled. Clean status, containment or a prunable record does not certify safe removal; ignored files, detached commits and agent ownership can still matter. Present review facts without a safe-to-delete guarantee. Actual cleanup remains outside this scope. [Git worktree](https://git-scm.com/docs/git-worktree) and [ancestry](https://git-scm.com/docs/git-merge-base) documentation define the underlying facts.

## Acceptance criteria

| ID | Outcome |
| --- | --- |
| G1 | Apple-provided Git is optional, detected without unsolicited installation, and absent/unsupported tools leave ordinary browsing/editing and saved-location navigation usable. No third-party runtime dependency is added. |
| G2 | Read-only local Git works in the signed sandbox with checkout/common-metadata grants; bounded cancellation, unavailable results and stale-result rejection preserve the existing access/network boundary. |
| G3 | Repository registrations, Codex/Cursor/Claude/Windsurf/Hermes location hints and custom locations support bounded, deduplicated, guarded navigation, including Antigravity and unknown harnesses. Attribution is separate from checkout/remnant/unverified state and folder access. |
| G4 | Each pane shows the correct repository and branch/detached/initial state, with independent lifecycle and truthful refresh/change summaries. |
| G5 | File/folder status reflects staged/unstaged and repository-boundary semantics using official Catppuccin colours, non-colour cues and readable selection states. |
| G6 | Unified View Diff presents labelled saved/staged/unstaged comparisons, navigable changes and explicit content limits while preserving the editor and offering no mutation actions. |
| G7 | Worktree review facts identify local comparison/freshness and uncertainty without inventing agent activity, PR status or removal safety. |
| G8 | Affected keyboard, VoiceOver, contrast, text-enlargement and system accessibility behaviour satisfies the native baseline; supported distribution builds retain their packaging/access contract. |

[Validation](validation.md) owns verdicts; accepted scope does not establish implementation or native acceptance.
