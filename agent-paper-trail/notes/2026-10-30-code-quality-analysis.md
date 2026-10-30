# Code-quality analysis

Status: Findings proposed for review

Baseline: `27693a90f303bf65ea381319adec4ba7f6216db5` on `main`, 2026-10-30. Source line references describe that baseline.

The analysis identifies nine maintenance and responsiveness findings. The [cluster plan](../specs/001-mvp/2026-10-30-code-quality-plan.md) maps them to proposed units; the [task tracker](../specs/001-mvp/tasks.md#2026-10-30-code-quality-remediation) owns execution and review state. None is recorded as resolved.

## Basis and limits

The [MVP core engineering requirements](../specs/001-mvp/spec.md#core-engineering-requirements) require bounded work and memory, responsive opening/editing/switching, simple control flow, focused responsibilities and one owner for shared rules. [Task review](../specs/001-mvp/spec.md#task-review) also requires meaningful tests and native acceptance.

This is a sampled analysis of browser state, directory loading/search, file operations, previews/editor, highlighting, updates, packaging and nearest tests. Lenses: complexity, ownership, reuse, consistency and test relevance/coordination. It is not a whole-codebase correctness or security audit.

The baseline Swift and tooling suites passed without unexpected failures; deliberately expected diagnostic failures and compiler warnings remain distinct from product acceptance. Isolated optimised measurements of unchanged source on macOS 27.0.1 / Xcode 27.1 support F1 and F3. They do not establish end-to-end app latency, memory peaks, native macOS 26 behaviour or manual accessibility acceptance.

## Findings

### F1: Repeated visible-list filtering

**Priority: high. Confidence: high.**

[DirectoryPane.entries](../../sources/panepeek-core/BrowserState.swift#L17) filters the full collection on each read, repeating case-insensitive matching over already matched search results. [primaryItem](../../sources/panepeek-core/BrowserState.swift#L129) repeats that work before looking up the selected entry. Both run on the main actor.

At 100,000 synthetic search results, median visible-list access took 43.84 ms and looking up the first selected result took 43.78 ms. Repeated view and command queries multiply this cost. Background sorting and native table virtualisation do not remove it.

**Direction:** maintain the visible collection when its inputs change and reuse it for selection lookup, preserving ordering and selection semantics.

### F2: Eager directory reads bypass cancellation and work budgets

**Priority: high. Confidence: high.**

[DirectoryListing.read](../../sources/panepeek-core/DirectoryListing.swift#L81) creates a detached task, collects all immediate URLs and reads every entry's metadata without cancellation forwarding or checks. [DirectorySearch](../../sources/panepeek-core/DirectorySearch.swift#L17) applies its entry budget only after receiving the complete listing.

A single wide directory can exceed the intended work/memory budget before the limit is considered. Superseded search results are rejected, but their in-flight listing work continues. [Search tests](../../tests/panepeek-core/DirectorySearchTests.swift#L41) verify returned limits and cancellation before reading, without establishing interruption during metadata collection.

**Direction:** make enumeration cancellation-aware and allow search to supply its remaining entry budget. Retain access until underlying reads finish; do not promise interruption inside an individual synchronous filesystem call.

### F3: Whole-document work on every edit

**Priority: high. Confidence: high.**

[The editor delegate](../../sources/panepeek/ReadOnlyPreview.swift#L193) builds a complete candidate string for byte-limit validation and rebuilds line offsets after each change. [EditorLines](../../sources/panepeek/EditorLineNumbers.swift#L6) scans all logical lines, while [PreviewState.updateText](../../sources/panepeek-core/PreviewState.swift#L229) repeats whole-buffer comparisons and size checks.

Line-offset construction alone took a median 15.31 ms for a supported 1 MiB document containing short lines. That excludes replacement, dirty comparison, layout and colouring. [Existing gutter tests](../../tests/panepeek/PreviewTextViewTests.swift#L224) establish local drawing rather than editing cost.

**Direction:** update line information from the edited range and reduce repeated buffer validation. Preserve byte-exact dirty state, native Undo, composition and [viewport stability](../specs/001-mvp/evidence/editor-viewport-stability.md).

### F4: Copy and move have circular ownership

**Priority: medium. Confidence: high.**

[ItemMove](../../sources/panepeek-core/ItemMove.swift#L5) wraps an ItemCopy; ItemCopy stores an ItemMove.Replacement. [Copy collision resolution](../../sources/panepeek-core/ItemCopy.swift#L75) converts copies to moves and back, translating errors. [Replacement metadata](../../sources/panepeek-core/ItemMoveReplacement.swift#L6) then depends on copy-owned identity and errors.

The reuse is valuable and real-filesystem collision tests protect it. The cost is tracing common transfer concepts through competing operation owners and conversion layers.

**Direction:** give captured transfer identity, collision decisions and replacement metadata a small neutral owner. Keep operation execution and meaningful outcome differences concrete.

### F5: Repeated operation-availability predicates

**Priority: medium. Confidence: high.**

[Transfer](../../sources/panepeek-core/BrowserState.swift#L842), [Trash](../../sources/panepeek-core/BrowserState.swift#L922), [Rename](../../sources/panepeek-core/BrowserState.swift#L1280) and [Create](../../sources/panepeek-core/BrowserState.swift#L1425) repeat long exclusions for operations, prompts and saving. Rename omits pendingChangeID; Create omits renameSubmission. Their intent must be reconstructed across workflows, making additions and review costly.

The [shared coordinator](0015-shared-operation-coordination.md) and existing tests protect mutation ordering. These predicate differences do not by themselves prove conflicting mutations can execute.

**Direction:** centralise the common exclusion policy while retaining action-specific selection, pane and drag conditions. Review each existing difference before changing behaviour.

### F6: Mutation recovery duplicates metadata classification

**Priority: medium. Confidence: high.**

[refreshMoves](../../sources/panepeek-core/BrowserState.swift#L1125) reconstructs directory/package, link, hidden, size and modification metadata independently of [DirectoryListing](../../sources/panepeek-core/DirectoryListing.swift#L98). Normal [scoped listing](../../sources/panepeek/FolderAccess.swift#L295) explicitly disables link-target inspection; recovery's fallback resolves links without receiving that policy.

This is confirmed duplication with policy drift. Its exact user-visible consequences require targeted validation, rather than assuming a defect from the differing branches.

**Direction:** share entry classification with an explicit link policy, retaining prefetched metadata and access lifetimes. Reuse the listing behaviour in mutation recovery.

### F7: Preview routing and presentation ownership are scattered

**Priority: medium. Confidence: medium.**

[DetailsSidebar](../../sources/panepeek/BrowserWindow.swift#L815) repeats the format set across read-only classification, messages, rendering and loader tasks. [PreviewDocument](../../sources/panepeek/ReadOnlyPreview.swift#L5) separately selects Markdown, SVG and HTML presentations. Adding a renderer requires coordinated edits to routing, controls and status presentation in the surrounding UI.

The repeated ownership is confirmed; the benefit of a particular extraction remains a design judgement. Existing image/video/PDF loaders reject unsupported selections before expensive work, so consolidating routing does not establish a new rendering-speed benefit.

**Direction:** centralise the route and extract a focused built-in preview host. Retain the shared source document/editor and concrete renderer state. Apply the constraints below; do not introduce a general plugin system.

### F8: Asynchronous tests depend on scheduler behaviour

**Priority: medium. Confidence: high.**

[UpdatePresentationTests](../../tests/panepeek/updates/UpdatePresentationTests.swift#L18) use unbounded Task.yield loops to wait for continuations. A missing event can consume the phase's process watchdog instead of producing a local diagnostic. [The old drag-receipt test](../../tests/panepeek/ScopedFileCommandsTests.swift#L76) yields ten times before a negative assertion, without proving the old callback ran.

The repository already has [bounded coordination and scoped teardown](../../tests/panepeek-core/TestRequestGate.swift#L106). The native target needs a proportionate equivalent, not a duplicate framework.

**Direction:** use bounded event waits, guaranteed continuation cleanup and completion evidence before asserting that a late callback had no effect.

### F9: Common bundle metadata has multiple owners

**Priority: low. Confidence: high.**

Common protected-folder explanations and bundle metadata are authored in both [the scripted generator](../../scripts/build-app.mjs#L78) and [Xcode Info.plist](../../xcode/Info.plist#L18). [The wording check](../../tests/tooling/folder-permissions.test.mjs#L11) verifies the Xcode source only.

The current values match, and [existing evidence](../specs/001-mvp/evidence/protected-folder-purpose-strings.md) checked both bundle paths. Future edits can drift while automated checks pass for one path.

**Direction:** maintain common values once and verify produced bundle metadata, preserving explicit channel-specific values.

## Preview design considerations

These refine F7 and map to four planned C4 units for the existing built-in previews.

| Consideration | Code-quality consequence |
| --- | --- |
| Central route | One decision should govern classification, loading, status, controls and presentation. Preserve SVG's editable-source route and [TypeScript precedence over video](../../sources/panepeek/VideoPreview.swift#L24). |
| Focused preview host | Move preview assembly out of metadata/layout code. Keep source editing and Save ownership in the shared document; [PreviewDocument](../../sources/panepeek/ReadOnlyPreview.swift#L5) deliberately retains its native editor across rich presentations. |
| Concrete renderer state | C4.3 makes presentation work/resource ownership explicit, separating Markdown presentation state from source/draft/Save ownership while preserving video teardown, PDF lifetime, HTML local-resource access and per-format limits. Keep distinct concrete owners rather than a universal payload/lifecycle protocol. |
| Static built-in catalogue | C4.4 gives current built-ins one registration source with stable identifiers, matching/precedence metadata and lazy construction. [SyntaxGrammarCatalogue](../../sources/panepeek-core/SyntaxGrammarCatalogue.swift) provides a local precedent. The route resolver consumes the catalogue; typed presentation dispatch preserves concrete resource types. |

[PreviewState](../../sources/panepeek-core/PreviewState.swift#L145) begins initial Markdown rendering during document loading and also owns later rendering requests. C4.3 separates that presentation work from document ownership while preserving drafts, Undo and Save.

## Keep and follow-up

Keep language-specific lexical scanners, concrete media lifecycles, native document identity, meaningful filesystem tests and intentional distribution-channel differences. File size alone and cosmetic naming preferences are not findings.

The recommended route is the linked cluster plan, with F1–F9 retained as stable identifiers and each coding unit reviewed separately.
