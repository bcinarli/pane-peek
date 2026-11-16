# PanePeek agent paper trail

Maintain current, durable project context here. This guide is sufficient without an installed skill, personal preferences or private journals. Use the [continuation index](INDEX.md) to find relevant requirements, binding choices and unresolved acceptance. Apply the [engineering and review rules](engineering-and-review.md) across workstreams.

This guide adopts agent-paper-trail conventions `0.7.0`. The configured project workflow records the same version. If its version or rules differ, follow this guide and report the drift; daily work does not authorise a guidance upgrade.

## Getting started

Describe the outcome in plain words, or name an operation: `explore`, `spec`, `plan`, `implement`, `review`, `handoff`, `reconcile`. A request may cover several operations. Reuse its authorisation and observe the project gates below.

Use the [panepeek-paper-trail workflow](skills/panepeek-paper-trail/SKILL.md) for focused techniques, reading it directly if discovery is unavailable. The README owns binding maintenance rules. An empty spec home needs no backfill; create a capability spec when a feature needs one.

## Project settings

| Setting | PanePeek configuration |
| --- | --- |
| Project workflow | `agent-paper-trail/skills/panepeek-paper-trail/SKILL.md`; existing Codex and Claude discovery pointers are retained. |
| Spec-first | `on`; use the exceptions under Workflow. |
| Spec home | `agent-paper-trail/specs/`; preserve existing package README specifications and stable record paths. |
| Acceptance home | Each package's `validation.md`, linked from its governing specification. Preserve existing criteria, IDs, verdicts and scoped waivers. |
| Working-plan home | The GitHub issue for the work; its PR links to it. It owns new delivery plans, units, investigation, progress and handoffs. |
| Review home | The pull request, including detailed verification and findings. |
| Review gates | [Shared task review](engineering-and-review.md#task-review), [validation checklist](validation/checklist.md) and [source-control decision](decisions/0002-feature-branches-and-prs.md). Agree implementation scope and intermediate checkpoints; contributors may proceed within that scope between checkpoints. Manual validation and maintainer acceptance remain required for the delivered result. Maintainer/code-owner review gates merge; release and distribution require explicit maintainer authority. |

Keep working and review material outside the paper trail. A configured destination does not authorise an external write. If it is unavailable or writing is not authorised, return a conversation draft naming its intended issue or PR home; do not claim a shared update.

Existing `plan.md` and `tasks.md` records retain their valid scope, dependencies and state until a reviewed migration assigns that content an explicit owner. Keep existing acceptance homes and record identities. For future work, use the configured issue rather than adding implementation units or execution history here. Existing record layouts do not override the content boundary below. The [portable contributor workflow decision](decisions/2026-11-16-portable-contributor-workflow.md) replaces inherited personal-skill and per-unit approval obligations; technical requirements, explicit dependency checks and acceptance facts remain binding.

Change these settings through review. A deliberate workflow opt-out sets Project workflow to `none`, removes its skill and discovery pointers, and removes entrypoint links to it; this standalone guide remains. Spec-first is independent of that choice.

<a id="repository-record-content"></a>

## Content boundary

Keep current requirements and reviewed intent, accepted decisions and relevant rationale, durable constraints, verified outcomes, and known or explicitly accepted limitations. Distinguish proposed intent, implementation, release state and acceptance when it affects future work.

Never record security-related findings, issues, assessments, improvements or remediation work here. Apply this exclusion before every recording obligation, including task rows, evidence, decisions, notes, indexes, filenames and linked summaries. Do not create sanitised or renamed records, convert excluded work into a constraint, add an omission note or request backfill. For mixed work, update only independently eligible facts without mentioning or linking the excluded portion.

Exclude implementation units and their identifiers, file-by-file recipes, investigation and debugging steps, discussion history, approval sequences and agent activity. Also exclude test narration, red/green sequences, test totals or inventories, fixture recipes, raw logs, CI run/job URLs and session-specific environment details. Keep build/run instructions in [CONTRIBUTING.md](../CONTRIBUTING.md).

Private journals, transcripts, private-journal links, secrets, credentials, private data, personal paths and runtime caches stay outside these records. Do not create a record for every task, review or check. Put delivery plans and handoffs in the issue, and change explanations and detailed verification in the PR, under their own content rules. Relocating a durable record to another spec or acceptance home cannot bypass this boundary.

## Read first

1. Read these settings and the content boundary, then [INDEX.md](INDEX.md).
2. Read only the relevant requirements, accepted decisions, constraints and acceptance rows. Consult legacy plan/task scope where it still governs the work.
3. Open an outcome summary only when its provenance or limitations matter. Do not load every file in a package by default.

Follow accepted requirements and decisions until reviewed changes replace them. If code differs, check for marked undelivered intent first; report unexplained discrepancies. Implementation does not establish acceptance.

## Workflow

Identify the outcome, authorised scope and current sources. Perform requested operations in dependency order. Name missing prerequisites and stop dependent work while continuing independent authorised work. Do not silently switch an explicit operation.

Reuse authority already given. Exploration, planning or review alone does not authorise implementation. Stop at a requested boundary, required gate, material conflict or blocking decision. Spec acceptance establishes intent; agree implementation scope before coding. It does not establish acceptance of the delivered result or authority to merge or release. Personal agent permissions and external-write instructions remain applicable.

1. **Explore** uncertainty in the conversation or issue. Report evidence, options and consequential unknowns. Use a recommendation as a spec basis only when accepted or within delegated authority.
2. **Spec:** find the governing spec before new behaviour. If none exists, propose one and draft it when authorised. Use [spec guidance](specs/README.md) and its starter. An issue supplies source material, not a second behavioural contract. Continue only within existing authority and project gates.
3. **Plan:** prepare or reuse a proportionate issue plan from ready requirements, or established intent when no spec is required. Include dependencies, reviewable units and meaningful validation. Existing legacy plans retain their scope. Identify any intermediate checkpoints when agreeing implementation scope; no further approval is required for each unit between them.
4. **Implement** within agreed scope under the [shared review rules](engineering-and-review.md#task-review). Collect required performance baselines before coding, use meaningful red/green TDD and exercise the affected surface. Perform the [self-review checks](engineering-and-review.md#self-review) and present evidence at agreed checkpoints and for final acceptance. These checks require no personal skills.
5. **Review** against requirements and the requested quality lens. Put source-backed findings in the review home; distinguish defects from missing evidence. Review alone authorises neither fixes nor posting.
6. **Handoff** through the issue, with the governing sources and revision, current and remaining scope, evidence links, unresolved decisions and next action. Follow Team continuation.
7. **Reconcile** changed eligible facts in their owning records. Reassess affected acceptance and keep incomplete scope explicit. If no eligible fact changed, make no paper-trail update.

Review spec changes with the change unless they receive separate review. Resolve a conflict with accepted intent before implementing a different direction.

### Skipping the spec step

A new spec is unnecessary when work restores expected behaviour with an identified basis, or preserves observable behaviour, such as a refactor, dependency, build or tooling change. State which case applies before implementation. If expected behaviour is unclear or disputed, resolve it or treat the work as a behaviour change.

The requester may skip a new spec with a reason recorded in the review surface; ask for the reason if absent. An existing governing contract still changes when its behaviour changes. Security-related work receives neither a spec nor a skip note here and follows the repository's own process.

## Maintain

Before writing:

1. Apply the content boundary to the text, filename and links.
2. Identify the changed eligible fact. Leave records untouched if none changed.
3. Update its existing home, replacing obsolete scope and limitations while preserving relevant rationale and supported outcomes.
4. Align affected references, acceptance rows and mapped reviewer bindings in the same change. Link facts rather than duplicating them.
5. Verify claims, links and navigation; apply Writing below. Keep detailed verification in the PR.

If explicit instructions exclude record edits, report only eligible unresolved gaps in the handoff. Never request excluded work as a missing record.

<a id="authority-and-maintenance"></a>

## Ownership

| Information | Maintained home |
| --- | --- |
| Behavioural requirements and reviewed scope | Owning `spec.md`, or existing package README specification. |
| Criteria, verdicts, remaining scope and waivers | Owning `validation.md`. |
| Durable approach, responsibilities, interfaces and compatibility | Optional `design-approach.md`; existing `plan.md` keeps its name. |
| Accepted choices and rationale | [Decision log](decisions/README.md). |
| Current constraints and reusable gotchas | [Notes](notes/README.md). |
| Engineering and review requirements | [Shared rules](engineering-and-review.md) and [checklist](validation/checklist.md). |
| Reusable workflow prompts | [Prompts](prompts/README.md). |
| Accepted UI/logo references and production limits | [Design sources](design/001-mvp/README.md). |
| Outcome or provenance too large for its criterion row | Optional short `evidence/<topic>.md`; link acceptance without copying verdicts. |

New packages need no `tasks.md`. Existing task contracts retain valid requirements, state and acceptance until reviewed migration assigns each an owner. Keep new delivery plans and progress in the issue.

## Status values

Preserve equivalent labels in adopted records; do not renumber or reformat legacy records merely to match new defaults.

| Record | Values |
| --- | --- |
| Specs, approach documents, prompts and notes | `Draft`, `Active`, `Paused`, `Completed`, `Abandoned`, `Superseded`, `Archived` |
| Decisions and rules | `Proposed`, `Accepted`, `Superseded`, `Rejected` |
| Existing capability/workstream task rows | `Ready`, `Active`, `Blocked`, `Completed`, `Abandoned` |
| Acceptance criteria | `Pending`, `Passed`, `Failed`, `Waived` |

## Specs and changes

Edit the authoritative spec on the change branch and explain changed intent in the review surface. The diff is the change record. Write one observable behaviour per requirement. Put durable technical constraints in Constraints and lasting approach in an optional `design-approach.md` or existing approach file. Other implementation choices stay in code.

Preserve existing IDs. For new requirements and criteria, use stable descriptive IDs, check for duplicates and cover consequential boundaries and error cases. Move a spec from Draft to Active only when goals, non-goals and boundaries are explicit, each assumption has a check, decision-changing questions are resolved, and every requirement has linked criteria and verdicts in its acceptance home. Defer a question only if its answer cannot change requirements, approach or acceptance.

Active means accepted intent. If reviewed intent merges before code, mark undelivered requirements and link their delivery issue. Reference the delivered contract where it differs. Remove the marker only after verified delivery; reassess acceptance separately.

A capability spec stays Active while its requirements bind. Before completing a bounded workstream, give still-binding requirements and criteria a lasting owner and leave a link. Then remove the package from active navigation. PanePeek's existing `001-mvp` completion describes delivery; its maintained native and accessibility contracts remain binding at their stable paths.

## Acceptance and limitations

Keep each criterion and verdict in its configured acceptance home. Passed requires evidence covering the full criterion and required acceptance conditions; Failed requires a demonstrated failure. Incomplete coverage stays Pending with remaining scope stated. Automated checks do not establish manual or release acceptance.

A Waived verdict requires maintainer approval, exact criterion and release/environment scope, reason and durable approval source. Never turn a waiver into a pass or extend it to another candidate. Keep dates and environment details only when needed to interpret current outcomes or limits.

When a criterion or requirement changes, reassess affected acceptance. Retain Passed only when evidence covers the changed text; otherwise set Pending and state remaining scope. A waiver retains its original scope and does not cover changed text. Replace limitations when they cease to apply.

## Decisions and navigation

Preserve record names, URLs and existing decision conventions. New decisions follow the [decision log](decisions/README.md); keep accepted rationale and supersede changed choices explicitly. New specs use dated capability folders and the starter's `status`, `date`, `supersedes` and `superseded_by` fields. Replacement paths are relative to the paper-trail root. Update replacement backlinks together; a newer date never establishes precedence.

Active navigation covers current work, binding choices and unresolved acceptance. Link the owning section rather than repeating counts, ID ranges or completed-unit inventories. Retain a completed outcome link only for a current contract or dependency. Split long records by durable topic when section links no longer bound reading cost. Git retains previous text; do not add archives by default.

If several supported release lines are introduced, record their mapping in `AGENTS.md` and scope version-sensitive records with quoted `applies_to.from` and optional inclusive `to`, or equivalent existing metadata. Check carried records against the target line. Make cross-line corrections on the oldest line carrying a record and merge forward. A newer-line replacement leaves the older record unchanged on every line, with its own explicit scoped supersession.

## Team continuation

Before changing a shared contract, identify its baseline and relevant open PRs or linked issues. Recheck the baseline before handoff or merge. Resolve conflicting intent through review; timestamps do not establish precedence. Report unavailable sources and block only dependent work. Keep continuation context in the issue so another contributor can resume without private chat history.

## Writing

State each fact once and link its owner. Lead with the current requirement, fact or decision. Use the shortest wording that preserves rationale, evidence limits and exact scope. Put instructions in execution order with conditions and stop points beside their actions. Remove empty headings, narration and generic advice.
