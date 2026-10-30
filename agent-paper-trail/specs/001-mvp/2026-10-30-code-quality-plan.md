# Code-quality cluster plan

Status: Proposed

## Source and authority

Source: [F1–F9 and preview considerations](../../notes/2026-10-30-code-quality-analysis.md), at baseline `27693a90f303bf65ea381319adec4ba7f6216db5`. Findings and design directions remain provisional until reviewed. This plan changes no accepted product requirement.

The [core engineering requirements](spec.md#core-engineering-requirements), [task review rules](spec.md#task-review), [shared checklist](../../validation/checklist.md) and [source-control decision](../../decisions/0002-feature-branches-and-prs.md) govern implementation. The [task rows](tasks.md#2026-10-30-code-quality-remediation) own status, done/planned counts, acceptance and publication. Acceptance of this plan does not approve its coding units.

## Cluster overview

| Cluster | Issue | Goal | Findings | Units | Dependency | Main risk |
| --- | --- | --- | --- | --- | --- | --- |
| C1 Browser workload | [#147](https://github.com/bcinarli/pane-peek/issues/147) | Avoid repeated visible-list work; bound and cancel directory search reads | F1, F2 | C1.1–C1.2 | None | Stale selections, ordering, retained access |
| C2 Editor workload | [#148](https://github.com/bcinarli/pane-peek/issues/148) | Reduce per-edit document work | F3 | C2.1–C2.2 | C2.2 follows C2.1 | Unicode, dirty state, Undo and composition |
| C3 Operation ownership | [#149](https://github.com/bcinarli/pane-peek/issues/149) | Give shared transfer, availability and metadata rules clear owners | F4, F5, F6 | C3.1–C3.3 | C3.3 follows C1.2 | Mutation targeting and recovery |
| C4 Preview ownership | [#150](https://github.com/bcinarli/pane-peek/issues/150) | Central routing, focused host, concrete state owners and a static built-in catalogue | F7 | C4.1–C4.4 | Sequential within C4 | Draft/view identity, resource lifetime and registration drift |
| C5 Native test coordination | [#151](https://github.com/bcinarli/pane-peek/issues/151) | Make asynchronous regressions fail locally and prove callback completion | F8 | C5.1 | None | Losing late-result coverage or hanging teardown |
| C6 Bundle metadata | [#152](https://github.com/bcinarli/pane-peek/issues/152) | Keep common metadata consistent across distribution paths | F9 | C6.1 | None | Changing channel/signing metadata |

The declared list has thirteen coding units. Cluster-wide exclusions and validation apply to every unit within that cluster. All units address existing behaviour and built-in formats.

## C1: Browser workload

**Scope:** DirectoryPane, DirectoryListing, DirectorySearch and their consumers/tests. Exclude new search features, persistent indexing, sort redesign and changes to hidden/package/link traversal policy.

**Design:** Prefer a retained visible snapshot over a generic cache. For reads, compare a small cancellable iterator/consumer boundary with a bounded listing operation; choose the smallest shape that enforces the search budget before metadata materialisation. Normal browsing must still return its complete listing. Check cancellation between filesystem operations: an in-flight synchronous call may finish, but once cancellation is observed no further metadata work begins and stale work cannot publish.

| Unit | Scope and exclusions | Pass/fail exit |
| --- | --- | --- |
| C1.1 Visible collection ownership | Update the visible collection only when listing, search, sort or visibility inputs change; use it for selection queries. Excludes directory I/O changes. | Unchanged reads no longer refilter/rematch the full collection. Behaviour checks preserve sort/hidden/query transitions, selected/primary identity and independent panes. Matched large-list measurements show the repeated getter cost removed without a reproducible opening/switching regression; any retained-memory increase is bounded, explained and accepted. |
| C1.2 Cancellable bounded reads | Own cancellation through enumeration and metadata reads; pass the remaining search budget to the read boundary. Retain normal-listing completeness and scoped access. Excludes mutation recovery. | Real directory checks and bounded interruption injection establish that cancellation stops further metadata work, the budget is enforced before reading beyond it, stale results cannot publish and access outlives active reads. Search limits, partial traversal and normal listing remain correct. Resource comparison covers a single wide directory as well as nested traversal. |

**Dependencies and risk:** Neither unit needs C5's updater-specific changes. Preserve current latest-result guards, [prefetched metadata](evidence/directory-listing-metadata.md) and folder grants. C3.3 consumes the resulting classification/read boundary rather than introducing a competing helper.

**Native/accessibility validation:** Both pane layouts; search typing/clearing, navigation, selection, sort, hidden files and Quick Look targeting. Check keyboard selection/focus and VoiceOver loading/result announcements. Compare opening and switching against the unchanged baseline.

**Done when:** Unchanged reads reuse visible results, obsolete searches stop additional directory work, budgets hold at the read boundary and affected native behaviour is accepted.

## C2: Editor workload

**Scope:** EditorLineNumbers, the native edit delegate and PreviewState's edit validation. Exclude lexer rewrites, a new text engine, a larger file-size limit or replacing the native editor.

**Design:** Apply edit-range updates to the line index, retaining a full rebuild for whole-document replacement. For byte/dirty checks, compare incremental accounting with sharing one validated edit result; retain exact comparisons wherever needed for correctness. Choose measurable reductions rather than adding a parallel document model.

| Unit | Scope and exclusions | Pass/fail exit |
| --- | --- | --- |
| C2.1 Line-index updates | Update logical line offsets from native edits and retain viewport-local drawing. Excludes byte-limit and dirty-state policy. | Insert/delete/replace, Undo/Redo and newline/Unicode cases retain correct logical numbers and alignment. Ordinary small edits avoid a full NSString line scan. Near-limit typing measurements improve the identified line-index cost without breaking wrapping, caret or scroll retention. |
| C2.2 Edit validation work | Reduce repeated candidate-buffer construction, byte counting and redundant comparisons. Excludes changes to Save conflict detection or source encoding. | At/below/above-limit changes, multi-byte text, paste, composition, Undo back to the saved baseline and guarded Save preserve exact bytes and dirty state. Profiling confirms removal of identified redundant work, with no reproducible regression in editing, opening or mode switching. |

**Dependencies and risk:** C2.2 follows acceptance/publication of C2.1 so its measurements use the current line-index baseline. Preserve [viewport stability](evidence/editor-viewport-stability.md), native document identity and the existing safe-save contract.

**Native/accessibility validation:** Long/short lines, wrapping, source-based rich formats, actual Save, caret/selection and Undo. Check text enlargement, gutter announcements, focus and both appearances. No whole-app accessibility verdict follows from this unit.

**Done when:** Both identified edit costs are reduced with unchanged source, Undo/composition and Save behaviour, supported by measured and native acceptance.

## C3: Operation ownership

**Scope:** Shared transfer concepts, BrowserState availability and mutation metadata recovery. Exclude new operations, parallel mutations, permission-model changes and a general filesystem service.

**Design:** Keep execution-specific copy/move outcomes. Extract only common captured identity/collision/replacement concepts that remove the current round-trip conversions. Use the [existing coordinator](../../notes/0015-shared-operation-coordination.md) as authority; do not create a second state machine. Reconcile availability differences against existing behaviour before treating them as defects.

| Unit | Scope and exclusions | Pass/fail exit |
| --- | --- | --- |
| C3.1 Shared transfer concepts | Remove the copy-to-move-to-copy collision conversion and opposing ownership of shared types. Excludes changing execution algorithms and availability. | Copy/move share neutral captured transfer concepts without depending on each other's operation containers. Existing real-filesystem collision, replacement, partial-failure, source-preservation and affected-draft behaviour passes unchanged. |
| C3.2 Shared availability policy | Give common exclusion rules one owner; keep per-action pane, selection and drag conditions explicit. Excludes reservation granularity and transfer internals. | A focused behaviour matrix covers operation/prompt/Save/drag exclusions across affected windows. Every prior predicate difference is retained with a reason or changed under separately reviewed behaviour; native commands and menus agree with execution guards. |
| C3.3 Shared entry classification | Reuse classification in ordinary listings and post-mutation recovery, passing link policy explicitly. Excludes new metadata fields or filesystem-access permissions. | Listing and recovery agree on packages, links, hidden state and available metadata under both link policies. Real moved/renamed/unlisted inputs preserve current-navigation ownership and scoped access. No fallback independently resolves a link when the chosen policy forbids it. |

**Dependencies and risk:** C3.3 follows C1.2 because the directory-read boundary may change. C3.1 and C3.2 have no technical dependency on each other; run sequentially for review. Any newly established correctness issue in F6 requires an explicit scope decision before extending the unit.

**Native/accessibility validation:** Relevant copy/move/rename/create/Trash and drag routes, dirty documents and multiple windows. Review menu availability, keyboard actions, prompt focus and announced results/errors for each affected unit.

**Done when:** Each shared rule has one discoverable owner and real filesystem/native outcomes retain their accepted behaviour.

## C4: Preview ownership

**Scope:** Existing plain/highlighted text, Markdown, HTML, SVG, image, video and PDF presentations. Exclude settings UI/persistence, new formats, runtime discovery, third-party plugins and a universal renderer payload/protocol.

The [preview considerations](../../notes/2026-10-30-code-quality-analysis.md#preview-design-considerations) map to four explicit units:

- Central routing is C4.1; the focused preview host is C4.2.
- Concrete renderer-state ownership is C4.3. Earlier units must preserve existing lifetimes; this unit gives presentation work and resources explicit concrete owners at the host boundary.
- The static built-in catalogue is C4.4. Keep it limited to current registrations and metadata used by routing/hosting, with lazy construction and typed presentation dispatch.

| Unit | Scope and exclusions | Pass/fail exit |
| --- | --- | --- |
| C4.1 One preview route | Establish one route for existing format precedence and use it for loading, status, controls and presentation. Keep leaf-reader validation. Excludes host extraction and new enable/disable policy. | SVG remains editable source with a rich presentation; TypeScript keeps priority over video; unsupported/empty/loading/error states and Find/Copy availability remain consistent. Instrumented boundary checks show unselected readers do not start expensive work; late results cannot change the current route. |
| C4.2 Focused built-in host | Move preview assembly out of Details metadata/layout and consume C4.1's route. Preserve the existing document and renderer owners during extraction. Excludes renderer-state migration and catalogue registration. | Details no longer repeats format policy. Existing presentations and controls remain available; switching retains source bytes, dirty state, native editor identity, selection, Undo and contextual Find. Existing cleanup and access retention remain valid. Matched opening/switching, memory and app-size comparisons show no unexplained regression. |
| C4.3 Concrete renderer-state ownership | Bind host activation/deactivation to concrete renderer owners. Separate Markdown presentation scheduling/state from source/draft/Save ownership where currently coupled; retain image/video/PDF/HTML/SVG resources in their concrete owners. Excludes parser changes, a shared payload type or a universal lifecycle protocol. | The host selects/activates presentations; concrete owners retain their tasks/resources, reject stale results and finish cleanup before releasing access. Markdown load/mode/dirty transitions preserve source and native editor identity. Rapid switching, cancellation, reader failure, window close and return to a previous format preserve existing results without leaked work, playback or grants. No duplicate host/document/renderer state is introduced. |
| C4.4 Static built-in catalogue | Register current built-ins once with stable identifiers, matching/precedence metadata and lazy construction. Have C4.1's resolver and the host consume that source; keep concrete resource types and typed display dispatch. Excludes runtime discovery, unused settings metadata and new format registration. | Each current built-in has one registration and format policy has one owner. Existing precedence/fallback and controls remain correct; catalogue enumeration/classification constructs no renderer or starts I/O. Only the selected presentation's required state is created. Existing lifecycle checks pass after integration; opening/switching, memory and app-size comparisons show no unexplained regression. |

**Dependencies and risk:** Execute C4.1 → C4.2 → C4.3 → C4.4. Prefer C2 before C4 to avoid overlapping editor/PreviewState changes, but this is sequencing rather than a technical prerequisite. Initial Markdown rendering currently belongs to document loading; C4.3 separates presentation ownership without replacing the document or weakening stale-result guards. C4.4 supplies registrations to the existing resolver, not a second routing policy. Retain the explicit system Quick Look action. No rendering-speed improvement is assumed from these ownership changes.

**Native/accessibility validation:** Switch among every existing preview family, Preview/Edit and independent windows; include dirty source documents and rapid selection changes. Check native Find/Copy/Save availability, keyboard/VoiceOver status, text enlargement and both appearances. Retain offline HTML/SVG resource policies and format-specific limits.

**Done when:** One route and static catalogue govern a focused host, concrete renderer owners retain their distinct lifecycles, editor/resource identity is preserved and the native comparisons are accepted.

## C5: Native test coordination

**Scope:** Updater presentation/automatic-check waits and the late native drag-receipt assertion. Exclude production updater behaviour, CI redesign and wholesale test-framework migration.

| Unit | Scope and exclusions | Pass/fail exit |
| --- | --- | --- |
| C5.1 Bounded event coordination | Replace unbounded yields with bounded observable events and guaranteed continuation cleanup; prove the old receipt callback completed before its negative assertion. A minimal internal completion seam is allowed only if no existing observable boundary suffices. | Missing events fail locally with useful diagnostics; cancellation and early failure release owned continuations/tasks. Late-result and old-receipt tests exercise their decisive callback and retain their original behavioural assertions. No arbitrary sleep/yield count remains in the selected coordination paths. |

**Design/risk:** Reuse the principles of existing scoped gates without importing test-target internals or creating a generic cross-target framework. Keep the process watchdog as an outer safeguard. One failure-injection pass and one normal focused run are sufficient unless changed code or a new failure justifies another run.

**Native validation:** Present the unchanged app with updater-window and drag-completion smoke checks under the shared gate. This test unit does not establish new accessibility coverage.

**Done when:** The selected tests prove event order, fail within their own bounds and clean up work independently of the phase watchdog.

## C6: Bundle metadata

**Scope:** Common metadata shared by the scripted bundle and Xcode archive plus validation of produced values. Exclude release numbering, signing, entitlements, update-channel behaviour and hosted publication.

| Unit | Scope and exclusions | Pass/fail exit |
| --- | --- | --- |
| C6.1 Common metadata source | Choose a small shared metadata input or derive the script's common values from the maintained plist; keep channel differences explicit. Excludes a new build-generation framework. | Actual development/review bundle and local Store archive contain the same required common text, with their intended identifiers, channel keys, icons and signing inputs preserved. A drift check covers both produced paths. Packaging verification and launch pass; unavailable archive prerequisites leave the unit pending. |

**Design/risk:** Compare using the existing plist with a small common-values file at unit approval. Prefer the option with fewer generated artefacts and build dependencies. Current values match; the goal is preventing future divergence.

**Native validation:** Inspect packaged metadata and launch the review app. Fresh consent-prompt appearance remains pending unless actually exercised; do not reset user permissions as part of this unit.

**Done when:** Common values have one maintained owner and actual bundle/archive validation proves channel differences remain intentional.

## Sequence, validation and review

Recommended order: **C1 → C2 → C5 → C3 → C4 → C6**. C1 leads because measured main-actor cost and uncancelled directory work directly affect responsiveness. C2 addresses the next measured path. C5 is a bounded test improvement, not a prerequisite imposed on unrelated work. C3 and C4 then clarify ownership; C6 remains a lower-priority independent maintenance unit.

Use existing behaviour tests and real temporary filesystem inputs. Add tests only for uncovered contracts or meaningful failure paths. Run targeted checks per unit, with the repository's required full checks at the applicable handoff. Each coding unit retains explicit approval, tighten/probe, a running app and manual review before the next unit; dependency publication follows the source-control decision.

For C1/C2 and C4 performance comparisons, capture a fresh unchanged baseline on the same configuration as the candidate. Compare relevant opening/editing/switching, resource use and bundle size. The analysis timings are diagnostic references, not universal latency thresholds. Allow at most two measurement/rework rounds per unit; inconclusive results or failure to remove the identified cost require a scope/approach decision, not an added investigation unit.

After C1, C2 and C5, perform a bounded quality checkpoint on the changed browser/editor/coordination boundaries before C3. Compare remaining findings with this plan; do not silently grow the unit list. The checkpoint is part of the fifth unit's handoff. Review further checkpoint needs if publication grows to ten or more PRs.

All unit exits include their cluster's native checks and the shared review gate. Unexecuted checks remain Pending. Create concise unit evidence when work begins and update only criterion verdicts fully established by that evidence; this proposed plan changes no current criterion verdict.

## Issue tracking

All nine findings are mapped above. Compiler-warning cleanup is outside this finding set. All four preview-architecture items are included in C4.

One tracking issue per cluster is linked in the overview, following the [contribution guide](../../../CONTRIBUTING.md#pull-requests). Detailed scope and acceptance remain in the paper trail; issues hold concise outcomes, unit references and PR links. Issue creation does not approve coding or establish implementation/publication of the planned changes. Update issue record references when these documents are published; avoid a parallel acceptance checklist.
