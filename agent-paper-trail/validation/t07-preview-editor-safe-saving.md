# T07 Preview editor toggle and safe saving

Task outcome: Accepted on 2026-10-11. Bilal confirmed the reserved-label correction keeps filename wrapping and the preview pane stable, then confirmed all remaining safe-saving and affected accessibility checks passed. See [final manual acceptance](#final-manual-acceptance).

## Unit 1: draft editor and loss guards

Status: Accepted. Bilal approved this draft-only unit on 2026-10-11 and subsequently confirmed all five manual checks. Editing, Discard and highlighting are accepted. Bilal subsequently accepted the mode-control correction and approved continuing to safe saving. The final Save/Discard/Cancel requirements remain unchanged.

T06 is accepted and merged through PR #13 (`4e73984`); implementation `504881d` is an ancestor of `main`. Work uses `bcinarli/t07-preview-editor-safe-saving`, created from that verified main revision under [decision 0002](../decisions/0002-feature-branches-and-prs.md). Bilal authorised the current-unit local commit on 2026-10-11; `9ecf861` records the editor, safe saving and Undo correction. Existing shared T06 publication records remain unstaged. Push and PR creation are not authorised or performed. The subsequent accepted header corrections are authorised for local commit.

The window owns one draft. Preview shows it read-only; Edit keeps native text selection, scrolling and undo. Exact UTF-8 comparison drives the Unsaved indicator. Edited text uses the existing filename-routed highlighter. Empty text is editable; unavailable content and file links are not. Drafts are limited to 1 MiB of UTF-8. There are no disk writes or Save placeholders.

Discard/Cancel sheets protect replacement, primary selection, pane focus, context targeting, clear/Escape, navigation, favourites, Refresh, hidden pruning, close and quit. Cancel retains the draft and original selection/focus. Discard resumes the captured action; context menus open after targeting succeeds. Pending and duplicate decisions cannot replace a different document. Metadata remains independent.

Unit 1 coverage at its checkpoint: partial A11/A12/A32; Edit pipeline A15; A14 link restriction; dirty guard portions of A16/A17/A19/A28/A29. A13 and saving preservation were deferred to Unit 2. Multi-window behaviour remains T16.

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4, macOS SDK 27, Node.js 26.1.0. macOS 26 execution is not claimed.

- Initial behavioural red: 17 editor/preview tests compiled and reported 53 issues before implementation. Focused green subsequently passed.
- Cross-pane context Cancel regression: one observed failure before atomic focus/selection protection, then green.
- Deferred confirmation regression: four observed issues before captured decision handling, then green.
- Context Discard continuation regression: two observed issues before the menu continuation, then green. A Testing macro closure compilation diagnostic was corrected separately and is not counted as behavioural red.
- Final `node scripts/test.mjs`: **231 tests in 26 suites pass**, with four existing intentional known issues from bounded missing-request/completion diagnostics. Includes stale highlight/read ordering, dirty loads, exact Unicode/newline revert, unchanged disk bytes, link eligibility, Cancel/Discard transitions, hidden pruning, pending navigation, deferred favourites and stale/duplicate decisions.
- `node scripts/build-app.mjs`: passes. The existing Command Line Tools linker search-path warnings are non-blocking.
- Bundle plist lint passes; bundled executable SHA-256 matches the fresh build. The generated-executable recovery was explicitly approved and preserves backups. The packaging script is unchanged.
- Original disposable fixture checksums remain unchanged after typing, Discard, Refresh and quit. The documented fixture script also runs successfully; all 32 regular files in that final fixture remain unchanged after hidden-primary, close, star and Refresh checks. Local links/anchors, criterion table structure and whitespace checks pass.

Native checks on the final app pass: Swift draft highlighting, Preview/Edit text and selected-word retention, rejected Preview typing, undo/redo and dirty restoration across mode changes, Unicode cut/paste and exact revert, selection Cancel, cross-pane context Discard with menu opening, hidden-primary Cancel, close/quit Cancel and Discard, Refresh Discard, empty editing, unavailable/link Edit restrictions with metadata retained, rejection of an oversized multibyte paste, and opposite-pane star toggling without changing the draft, selection or pane focus. Earlier unit checks verified favourite navigation Cancel retains the current pane. Temporary review favourites were removed after testing.

An undo-history reset exposed a native abort during development. History is now cleared before disabling presentation undo registration; document replacement happens read-only. Discard Refresh passes repeatedly after this correction. Isolation-only presentation delays and split-host changes were removed. Initial SwiftUI accessibility frames did not establish an OS defect.

Accessibility evidence: native names/roles/selected mode, Unsaved text, editor/read-only labels, error text and disabled editing states were inspected in the accessibility tree. Keyboard undo/redo, clipboard, Refresh, close and quit were exercised. Dark appearance was observed. Bilal subsequently confirmed all five manual checks, including the requested appearance/accessibility and language checks. This is Bilal's reported acceptance, not an agent-executed VoiceOver or light-appearance result. Bilal subsequently validated the mode-control correction.

Tighten removed isolation-only scaffolding and consolidated confirmation into one callback. Probe added context-menu continuation, stale/duplicate decision and deferred favourite regressions, plus native byte-boundary, hidden-primary and close checks. The presentation correction was separately approved and accepted; safe saving is the next approved unit.

## Run and fixtures

From the repository root, quit any running app, then:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

If the existing local signature-cache issue prevents launch, follow the [generated-executable recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery). Packaging changes retain their separate gate.

Create disposable files with representative accepted language routes and boundary cases:

```sh
node --input-type=module <<'JS'
import { mkdtemp, mkdir, writeFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const reviewRoot = await mkdtemp(join(tmpdir(), 'panepeek-t07-review-'));
const samples = {
  '01-example.swift': '// Preview and Edit\nlet greeting = "Hello"\nvar count = 42\n',
  '02-plain.txt': 'Plain text\nCafé 👀\n',
  '03-empty.txt': '',
  '.hidden.swift': 'let hidden = true\n',
  'sample.json': '{"ready": true, "count": 42}\n',
  'sample.yaml': '# config\nready: true\n',
  'sample.toml': '[config]\nready = true\n',
  'sample.js': '// code\nconst value = "Hello";\n',
  'sample.ts': 'const count: number = 42;\n',
  'sample.html': '<!-- markup --><div title="hello">Text</div>\n',
  'sample.xml': '<root key="hello"><child/></root>\n',
  'sample.jsx': 'const view = <div title="hi">{42}</div>;\n',
  'sample.tsx': 'const view = <div title="hi">{42}</div>;\n',
  'sample.css': '/* style */ .card { color: #fff; }\n',
  'sample.scss': '$size: 12px; .card { width: $size; }\n',
  'sample.php': '<?php $value = "hello"; // comment\n?>\n',
  'sample.go': 'package main\nvar value = "Hello" // comment\n',
  'sample.rs': 'fn main() { let value = "Hello"; }\n',
  'sample.java': 'class Sample { int count = 42; String value = "Hello"; }\n',
  'sample.py': '# code\nvalue = "Hello"\nready = True\n',
  'sample.md': '# Heading\n**bold** and `code`\n',
  'sample.sh': '# shell\nif true; then echo "$HOME"; fi\n',
  'sample.sql': '-- query\nSELECT name FROM items WHERE id = 42;\n',
  'sample.c': '#include <stdio.h>\nint count = 42; // comment\n',
  'sample.cpp': 'const char* value = R"(Hello)";\n',
  'sample.cs': 'class Sample { string value = "Hello"; }\n',
  'Dockerfile': '# build\nFROM alpine:latest\nENV MESSAGE="Hello"\n',
  'Makefile': 'VALUE := hello\nall:\n\t@echo "$(VALUE)"\n'
};
for (const [name, text] of Object.entries(samples)) await writeFile(join(reviewRoot, name), text);
await writeFile(join(reviewRoot, '04-bom-mixed.txt'), Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('Café 👀\r\nsecond\nlast\r')]));
await writeFile(join(reviewRoot, '05-binary.bin'), Buffer.from([0, 0xff]));
await writeFile(join(reviewRoot, '06-large.txt'), 'x'.repeat(1048577));
await symlink('01-example.swift', join(reviewRoot, '07-link.swift'));
await symlink('missing.txt', join(reviewRoot, '08-broken.txt'));
await mkdir(join(reviewRoot, 'child'));
await writeFile(join(reviewRoot, 'child', 'child.txt'), 'Child folder\n');
console.log(reviewRoot);
JS
```

Open the printed directory with Command-L. Use the same directory in both panes for focus/context/star checks. Show Hidden Files reveals `.hidden.swift`. The accepted [T06 fixtures](t06-read-only-preview-highlighting.md) provide language-specific boundaries and filename aliases for broader Edit review.

## Manual review checkpoint

1. Edit text, select a word and switch Preview/Edit. Check current-buffer Preview, read-only typing, caret/selection/scroll retention, Unsaved, undo/redo, clipboard and empty files.
2. Edit representative files from each accepted A15 language; check live colours, incomplete input and plain fallback. Inspect links, binary/oversized/broken content and metadata.
3. With a dirty draft, try selection/range/primary changes, other-pane context targeting, Escape, path/chooser/parent/Home/breadcrumb/directory/favourite navigation, Refresh and hiding the primary row. Cancel must retain the original state; Discard must continue the captured action.
4. Toggle stars while dirty; check focus/selection/buffer retention. Test close and quit with Cancel and Discard. Confirm fixture bytes remain unchanged.
5. Check light/dark contrast, narrow layout, native text enlargement, full keyboard traversal and VoiceOver names/status/focus. Confirm modes and dirty state are perceivable without colour alone.

Bilal's outcome on 2026-10-11: “all manual checks confirmed. I tested different files and editing/discard/highlights work fine.” Bilal also reported movement of the Edit button while typing. The recording confirms a brief widening of the selected segment and a corresponding shift of Unsaved while both mode and dirty state remain unchanged.

## Mode-control follow-up

Status: Accepted. Bilal approved this presentation correction on 2026-10-11. `BrowserWindow.swift` gives the native segmented picker its intrinsic horizontal size. This single modifier keeps the picker independent of changing width proposals and allows native font sizing. No new control view or fixed pixel width was added.

Executed: bundle build and launch pass. The first sandboxed build could not write the compiler module cache; the same build passed with required cache access. Approved generated-executable recovery was applied with a preserved backup. Native HTML typing/highlighting, Preview/Edit buffer retention, undo to clean and redo to dirty pass. Observed control placement remains stable in clean/dirty and post-typing screenshots. Native mode names/roles/selected states and Unsaved remain exposed. Bilal's disposable HTML draft was retained before rebuilding and restored in memory afterwards; fixture bytes are unchanged. The existing Unit 1 core test evidence above is unchanged; no artificial tests were added or core suite rerun for this presentation-only modifier.

Tighten kept the correction to one layout modifier. Probe checked clean/dirty and mode/undo transitions, retained native sizing and identified the remaining observation limit: the app tools could not obtain a new frame-rate recording. Post-input screenshots do not establish absence of the single-frame movement in Bilal's original recording. Bilal subsequently reported validation of the changes; this supplies the manual acceptance for the correction. No agent-executed frame-rate capture or VoiceOver check is claimed. Covers toggle presentation in A32 and the affected accessibility baseline.

Manual checkpoint:

1. In the running HTML draft, type and undo repeatedly; Preview/Edit and Unsaved should stay in place, including undo to clean and redo to dirty.
2. Switch modes; confirm text, selection and undo remain intact.
3. Recheck narrow/enlarged layout and keyboard/VoiceOver access to the mode control.

Bilal’s follow-up outcome on 2026-10-11: “Validated the changes. Approved to continue”. The correction is accepted and continuing to the remaining Save unit is approved. Commit and push retain separate gates.

## Unit 2: safe saving

Status: Accepted. Bilal approved this continuation on 2026-10-11 and confirmed all remaining manual checks after the Undo and header corrections. This unit adds explicit Save and the Save branch of the existing loss guards. Publication and another coding unit require separate approval.

Save is available in Preview and Edit, with Command-S. A successful Save advances the disk baseline, clears Unsaved and refreshes Details without resetting native text, selection or undo history. The sheet offers Save / Discard / Cancel. Only successful Save or explicit Discard resumes the captured action; failure leaves the app, document, selection and focus intact. Duplicate sheet answers and save submissions are rejected.

The original bytes and file identity are captured during the editor's bounded read. Save compares identity, size, modification/change timestamps, permissions and actual bytes before staging and again before replacement. It rejects modification, identical-byte replacement, deletion and link/special-file substitution. A same-directory temporary file receives UTF-8 bytes with the original BOM presence, unchanged newline sequences and Unix permission bits. The staged file is flushed before atomic rename; failures retain the draft and attempt cleanup of the owned staging file. The final 1 MiB bound includes any BOM. Save does not lock other applications: a simultaneous external write after the final check remains the accepted MVP limitation. No fallback overwrites the file in place.

Editing and replacement are blocked during the write. The native edit preflight checks the live document state as well as the displayed editability, preventing input from arriving between save start and the read-only redraw. Same-file selection revisions can still follow pane focus while the draft and undo identity remain protected. Symlink editing remains disabled.

Coverage: remaining single-window A11–A14/A32 behaviour, Save guards in A16/A17/A19/A28/A29, and A33 save metadata refresh. Manual acceptance is complete. Multi-window coordination remains T16; other file mutations remain their own tasks. The bounded M2 quality checkpoint is recorded separately below.

### Executed Unit 2 checks

Same environment as Unit 1. Required compiler-cache access was used; no toolchain or packaging-source change.

- Initial compiled behaviour red: four Save tests, 18 issues. The unimplemented Save did not write bytes or report conflicts/failures. Green passes after implementation.
- Save prompt red: one parameterised test, eight issues before the Save branch. A callback inside the Testing macro caused a compilation diagnostic first; this was corrected and is not red evidence. Green covers captured cross-pane context success, conflict retention and duplicate answers.
- Pending-save red: one issue, same-file selection revision was stale while saving. Green now covers revision publication, rejected duplicate Save, protected draft/load/Discard/transition and unchanged native document identity.
- Focused tests: 38 tests in seven suites pass before the final pending-save regression. Final `node scripts/test.mjs`: **237 tests in 27 suites pass**, with the four existing intentional known issues. The final six Save tests also pass after the timeout-diagnostic update. Includes real plain/BOM/mixed-newline/Unicode fixtures, permission preservation, an already-open descriptor retaining the original bytes after replacement, successive save baselines, modification/replacement/deletion/link/FIFO conflicts, file and directory permission failures, staging cleanup and the BOM-inclusive byte boundary.
- `node scripts/build-app.mjs`: passes, including the final native preflight rebuild; bundle plist lint and fresh executable hash match pass. The separately approved generated-executable recovery preserves a backup. No packaging-source changes.
- Native checks: Save button and Command-S in Edit, Save from Preview, updated size/modified metadata, native undo to dirty and redo to the saved clean baseline, external-conflict error/draft retention, failed selection Save preserving the original row, Escape Cancel, Discard continuation, permission-denied error/draft retention and failed quit Save keeping the app open. Saving an empty-file draft permits close; successful quit Save exits. Disk bytes confirm the requested writes and unchanged permission-denied source. Native BOM/mixed-newline Save preserves the exact expected bytes and 0640 mode.
- Cross-pane context Save writes the old draft, selects the captured row in the other pane and opens its path menu. Closing that menu leaves the new preview visible. The app is left running with both panes on the disposable Save fixture and a saved Swift file selected.
- Final preflight build: launches; native typing, selected-word retention through Save, metadata refresh and post-save undo/redo pass. A bounded test write gate reports a specific timeout rather than a misleading file-read error.
- Accessibility: native Save name/role/help/disabled state, sheet choices, Unsaved and readable errors are exposed. Command-S, undo/redo, Escape cancellation and close/quit shortcuts were exercised. Dark layout and readable editor colours were inspected. Agent did not execute full VoiceOver announcements, light appearance, narrow/enlarged layout or complete keyboard traversal of the new Save control. Bilal subsequently confirmed these checks in the final manual acceptance below.

Tighten keeps one bounded reader/snapshot/writer and the existing transition replay, with no generic filesystem provider. Metadata refresh uses one Save-change trigger rather than duplicating initial loads. Probe covers fail-closed file identity/content checks, pending-save protection, duplicate answers, native preflight and unchanged source bytes on failure. No second-model review or unrelated refactor was required.

### Unit 2 fixtures

The running app already has a disposable fixture. For a fresh review, create one with:

```sh
node --input-type=module <<'JS'
import {mkdtemp, mkdir, writeFile, chmod, symlink} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const reviewRoot = await mkdtemp(join(tmpdir(), 'panepeek-t07-save-review-'));
const samples = {
  '01-save.swift': '// Save review\nlet greeting = "Hello"\n',
  '02-conflict.txt': 'Original disk version\n',
  '03-readonly.txt': 'Read-only file\n',
  '04-empty.txt': '',
  '05-next.txt': 'Next selection\n'
};
for (const [name, text] of Object.entries(samples)) {
  await writeFile(join(reviewRoot, name), text);
}
await chmod(join(reviewRoot, '03-readonly.txt'), 0o444);
await writeFile(join(reviewRoot, '06-bom-mixed.txt'), Buffer.concat([
  Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('Café 👀\r\nsecond\nlast\r')
]));
await chmod(join(reviewRoot, '06-bom-mixed.txt'), 0o640);
await symlink('01-save.swift', join(reviewRoot, '07-link.swift'));
await mkdir(join(reviewRoot, 'child'));
console.log(reviewRoot);
JS
```

Open the printed directory in each pane with Command-L. Build/run instructions remain [above](#run-and-fixtures). To create a conflict, load `02-conflict.txt` in PanePeek, edit its draft, then save different content to that same disposable file from another editor before clicking PanePeek's Save. `03-readonly.txt` provides a reproducible permission failure. Use the Unit 1 language fixtures for broader highlighting checks.

### Unit 2 manual checkpoint

1. Save edited and empty text with the button and Command-S in both modes. Check Unsaved clears, disk content and Details update, caret/selection stay intact, and undo/redo still work against the saved baseline.
2. Save `06-bom-mixed.txt`; verify BOM, CRLF/LF/CR and 0640 permissions remain. Confirm links stay read-only. Automated tests cover the final BOM-inclusive size boundary.
3. Try Save / Discard / Cancel before selection, context targeting, navigation (including Home/breadcrumbs/favourites), Refresh, close and quit. Save continues only after success. Star toggling must retain the draft.
4. Modify a loaded disposable file externally, then attempt Save and transition-Save. Try the read-only fixture. Errors must preserve draft/selection/focus and keep the app open; external/denied disk content must remain intact.
5. Check the new Save control and sheets in light/dark, narrow/enlarged layout, keyboard traversal and VoiceOver. Check error/state announcements and continued mode-control stability while typing.

Bilal's Unit 2 outcome: accepted after the approved Undo and header corrections. Bilal confirmed all remaining Save and affected accessibility checks on 2026-10-11. The feedback below records the earlier failure and its correction.

### Undo and design review feedback

On 2026-10-11, native investigation reproduced Command-Z doing nothing after fresh typing, paste and a direct keypress in the focused Edit text view. The Edit menu's enabled Undo also left the direct-key edit unchanged. Returning through Preview to Edit did not restore Undo. Bilal's original draft was restored after the checks; no Save was performed. This is a failing runtime result despite the earlier narrow native checks recorded above. Redo after a successful Undo and the exact history/routing cause remain unresolved.

The accepted editable [draft](../design/001-mvp/app-draft.fragment.html) places Save at the trailing end of the Preview/Edit row and Unsaved beside the filename. The native app puts Save on a separate leading row and Unsaved beside the mode control, adding a row above the editor. Its bordered preview/editor above the path and metadata follows the accepted structure. Native typography, accessibility and adjustable proportions remain governed by the spec rather than exact draft pixels.

Proposed sequence at this checkpoint: first correct native undo/redo with a meaningful AppKit regression and real keyboard/menu checks; then review the header layout as a separate unit. The first unit covers A11/A32, including saved-baseline dirty state, highlighting, mode retention, save-time input protection and history reset only on replacement/Discard. Expected production scope is the text-view bridge, with command integration only if routing evidence requires it. An AppKit behaviour test target may be added to cover the native seam that core tests cannot exercise. The proposal itself supplied no implementation approval; Bilal's subsequent explicit approval is recorded below.

Tighten keeps these as separate reviewable units and reuses the existing editor and draft state. Probe treats the reproduced runtime failure as acceptance-blocking; earlier core greens and native happy-path checks do not establish correct Undo for the reported route. The precise root cause must be verified before choosing the implementation.

## Undo correction

Status: Accepted. Bilal explicitly said “approved” to the bounded Undo correction on 2026-10-11 and subsequently confirmed all three presented behaviour checks as OK. Full T07 acceptance is recorded below; publication and any remediation retain separate gates.

The editor owns a stable native UndoManager. Its Undo/Redo responder actions apply native history and publish the resulting text through the existing draft callback. Menu validation and both actions check the live edit gate, including the save-time protection before redraw. Save breaks native typing coalescing without clearing history, allowing the next edit to undo to the saved baseline. The existing document identity still clears history only for replacement/Discard. Production changes are local to the native text-view bridge and passing the Save revision from its existing sidebar call site. No custom history stack, window command layer or header-layout change was added.

### Executed Undo checks

Same host/toolchain as Unit 1; macOS 26 execution is not claimed.

- Compiled behavioural red: the original native Undo restored visible text without updating the draft (one issue). The first correction allowed Undo through a closed live edit gate (two issues). Typing across Save skipped the saved baseline (one issue). Each regression passes after its local correction. An unsupported direct selector diagnostic caused a test-process exception; this harness error is excluded from behavioural red evidence.
- Three native AppKit tests use a real hosted text view, native insertion/responder actions and menu validation. They cover presentation/caret retention, exact Unicode dirty state, Undo/Redo, Preview and live edit gates, post-Save typing boundaries, Discard reset and unchanged saved bytes.
- `node scripts/test.mjs`: **237 core tests in 27 suites pass**, with four existing intentional known issues; **three native tests in one suite pass**. `node scripts/build-app.mjs`, bundle plist lint and fresh executable hash match pass. The already-approved generated-executable recovery retains a backup; packaging source is unchanged.
- Running-app keyboard Command-Z / Command-Shift-Z and actual Edit-menu Undo / Redo restore the expected text and clean/dirty state. Menus enable only available history and disable both actions in Preview. Typed text and Unicode paste work; dark Swift colours remain readable.
- Save button retains the selected word; Undo makes the saved document dirty and Redo returns to clean. Command-S between typed characters creates a saved baseline that the next Undo reaches exactly. Save from Preview updates bytes/metadata; returning to Edit retains prior history and compares dirty state against that new baseline.
- Moving focus to Copy Absolute Path and back retains history. Cancelled selection retains the draft and history when focus returns to the editor. Discard continues to the requested file; the new document has disabled Undo/Redo and cannot restore the previous document's text. Exact disk checks confirm only requested fixture Saves occurred.
- Bilal's exact pre-build unsaved draft and original two-pane folder are restored. Its source bytes are unchanged. Accessibility exposes editor/read-only labels, mode state, Unsaved, Save and native menu availability; keyboard actions were exercised. Full VoiceOver announcements and light/enlarged/narrow review remain manual checks.

Standard tighten keeps native history and the existing callback, with two short local responder actions and one Save-boundary trigger. Standard probe verifies live-gate protection, saved-baseline coalescing, disabled menu states and replacement/Discard reset through both tests and the running app. No remaining implementation blocker or second-model escalation was identified. Bilal's reported behaviour acceptance is recorded below; remaining affected accessibility checks are confirmed in the final manual acceptance.

### Undo manual checkpoint

The rebuilt app is running. Use the disposable [Unit 2 fixture](#unit-2-fixtures), or create a fresh one using those instructions. Build/run instructions remain [above](#run-and-fixtures).

1. Type and paste in Edit. Use both keyboard shortcuts and the Edit menu; text, highlighting and Unsaved must follow Undo/Redo.
2. Save, type again, then Undo to the saved clean baseline. Switch Preview/Edit and move focus away/back; history must survive. Preview must reject Undo/Redo.
3. Cancel a dirty selection change, return focus to the editor and check history. Then Discard to another file; its history must start empty. Recheck native menu availability and VoiceOver announcements.

Bilal's correction outcome on 2026-10-11: typing/paste Undo/Redo with shortcuts and menus, Undo to the saved baseline after new typing, and Cancel retention/Discard reset are each confirmed “OK”. This accepts the three presented behaviour checks; no additional VoiceOver result is inferred.

Bilal also observed Undo returning to pre-save text after saving and switching back to Edit, with Redo restoring the saved text. This is expected: Save and mode changes retain earlier undo history. Undo changes only the in-memory draft and marks it Unsaved when it differs from the latest saved bytes; Redo back to those bytes makes it clean. Disk content changes only on another explicit Save. Bilal subsequently approved the header unit below.

## Header layout correction

Status: Accepted after the reserved-label correction. Bilal authorised this bounded unit on 2026-10-11 and subsequently accepted stable wrapping and all remaining layout/accessibility checks.

The accepted [editable draft](../design/001-mvp/app-draft.fragment.html) places Unsaved beside the filename and Save at the trailing end of the Preview/Edit row. `DetailsSidebar` now follows that placement, removing the extra Save row above the bordered editor. The existing native segmented control retains its intrinsic sizing; the filename wraps and Unsaved remains readable. This changes only the header in `BrowserWindow.swift`, covering A11/A32 presentation and affected accessibility. Editor, Save, Undo, path and metadata behaviour are retained.

### Executed header checks

Same host/toolchain as Unit 1; macOS 26 execution is not claimed.

- `node scripts/build-app.mjs` passes. Bundle plist lint, fresh executable hash and native launch pass. Previously approved local executable recovery preserves a backup; packaging source is unchanged.
- Dark screenshots show Unsaved beside the filename, Preview/Edit and trailing Save on one row, then the bordered editor, path and metadata. A long filename wraps fully, with the full name exposed in accessibility and Unsaved readable on the first baseline. Clean and dirty states expose the expected Save availability and mode selection.
- Clicking trailing Save preserves the selected word and clears Unsaved. Saved bytes and Details size update from 40 to 63 bytes. Undo restores the pre-save draft as dirty; Redo restores the saved clean baseline. Command-S from Preview saves the long-name draft exactly, updating size from 34 to 43 bytes. Edited Swift highlighting remains visible.
- Empty text exposes editable modes and disabled clean Save. Binary and folder previews retain metadata with editing disabled and Save absent. Links retain their own metadata and read-only preview with editing/Save disabled. Mode, Save, dirty and editor names/roles remain accessible; keyboard Save/Undo/Redo were exercised.
- The six regular files in Bilal's previous review fixture retain their pre-build hashes. Native checks use a fresh disposable fixture. The running app is left with both panes on that fixture, left `01-layout.swift` in dirty Edit and right unselected.
- No new behaviour tests are warranted for this placement-only change. The preceding Undo correction's 237 core tests and three native tests remain the latest full-suite evidence; they were not rerun for layout. Whitespace, changed-document links/anchors and table checks pass.

Standard tighten keeps two local rows and existing native controls, without a new component or fixed pixel widths. Light probe checks long names, conditional Save states, native Save/history and preserved file bytes. No implementation blocker was found. Two attempted divider drags did not change width, so minimum-width validation is not claimed. Agent did not execute light appearance, enlarged text, full keyboard traversal, VoiceOver or a live typing recording in this unit. Bilal subsequently confirmed the remaining checks in the final manual acceptance below.

### Header fixtures and manual checkpoint

The app is running. Use the current fixture or create a fresh one:

```sh
node --input-type=module <<'JS'
import {mkdtemp, writeFile, symlink, mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const reviewRoot = await mkdtemp(join(tmpdir(), 'panepeek-t07-header-review-'));
const longName = '02-' + 'long_document_name_'.repeat(8) + 'preview.swift';
await writeFile(join(reviewRoot, '01-layout.swift'), '// Header review\nlet greeting = "Hello"\n');
await writeFile(join(reviewRoot, longName), '// Long filename\nlet ready = true\n');
await writeFile(join(reviewRoot, '03-empty.txt'), '');
await writeFile(join(reviewRoot, '04-binary.bin'), Buffer.from([0, 255]));
await symlink('01-layout.swift', join(reviewRoot, '05-link.swift'));
await mkdir(join(reviewRoot, 'child'));
console.log(reviewRoot);
JS
```

Open the printed directory with Command-L. [Build/run instructions](#run-and-fixtures) and the remaining [safe-saving checklist](#unit-2-manual-checkpoint) still apply.

1. Type/paste, Undo/Redo and switch Preview/Edit. Check the mode control stays steady, Unsaved stays beside the filename, and trailing Save/Command-S work in both modes.
2. Try the long filename and smallest sidebar width, enlarged text and light/dark appearance. Check wrapping, spacing and readable controls without overlap or clipping.
3. Traverse the header by keyboard and VoiceOver; check mode selection, Save availability and Unsaved announcements. Empty/binary/link/folder states must retain their preview restrictions and metadata.

Bilal's header outcome: accepted after the reserved-label correction. Layout commit, push and further coding units retain separate gates.

### Long-filename wrap feedback

Bilal's manual review on 2026-10-11 reports that Unsaved appearing beside a multiline filename changes its wrapping and pushes the preview/editor down. The reviewed header inserted the label only while dirty, reducing the width available to the filename. The earlier dirty-state screenshot did not verify a stable clean-to-dirty transition. This feedback led to the reserved-label correction below.

Bilal explicitly approved reserving the label space on 2026-10-11. The correction below is implemented and manually accepted.

### Reserved-label correction

Status: Accepted. Bilal confirmed stable filename wrapping and preview-pane position on 2026-10-11. The existing Unsaved label now always occupies its intrinsic space. Its opacity and accessibility visibility follow dirty state, keeping filename width constant without pixel widths or truncation. Only this label in `BrowserWindow.swift` changes; coverage is A11/A32 presentation and affected accessibility.

- `node scripts/build-app.mjs`, bundle plist lint, fresh executable hash and native launch pass on the same host/toolchain as Unit 1. Previously approved local executable recovery preserves a backup; packaging source is unchanged. No behaviour tests were added or rerun for this layout-only unit.
- Native dark screenshots retain the same multiline filename wrapping and editor position through the first dirty paste, Undo to clean and Command-S in Preview. Redo restores the dirty label; mode changes retain text. Preview Save clears the indicator and updates exact bytes/Details size from 32 to 41.
- Short-name typing, Undo/Redo and trailing Save in Edit pass; saved bytes/Details size change from 33 to 34. The clean accessibility tree excludes Unsaved; dirty state exposes it with the full filename. Mode and Save names, selection and availability remain exposed; keyboard Save/Undo/Redo were exercised.
- Ten regular files across the two previous review fixtures retain their pre-build hashes. Save checks use a fresh disposable fixture. The app is running with its long-name file selected in clean Edit, ready for the first edit; right pane is Home.

Standard tighten retains the existing label with two visibility modifiers. Light probe checks clean/dirty/Undo/Save transitions and excludes a hidden clean-state announcement; no remaining implementation blocker was found. Bilal subsequently confirmed narrow/enlarged layout, light appearance, full VoiceOver and stable live typing in the final manual acceptance below. Agent execution did not include a frame-rate recording or successful minimum-width resize.

Use the running fixture or the [header fixture instructions](#header-fixtures-and-manual-checkpoint), with [build/run instructions](#run-and-fixtures). Manual checkpoint:

1. With a long wrapped filename, type/paste, Undo/Redo and Save in Preview/Edit. Filename wrapping and preview/editor position must stay unchanged as Unsaved appears or disappears.
2. Recheck narrow/enlarged layout and light/dark appearance. VoiceOver must expose Unsaved only while dirty.

Bilal's reserved-label outcome: accepted. Bilal confirmed stable wrapping and preview position, then confirmed all remaining layout/accessibility checks. No new commit, push or further coding unit is authorised by this acceptance.


## Final manual acceptance

Bilal accepted the reserved-label correction on 2026-10-11: “Filename wrapping and the preview pane stay stable now.” In response to the remaining-checks confirmation, Bilal reported: “All remaining checks passed.” This completes the Unit 2 and header checkpoints: Save/Discard/Cancel for selection/navigation/Refresh/close/quit; external-conflict and read-only failures retaining edits; BOM/newline/permission preservation; keyboard/VoiceOver and narrow/enlarged/light/dark Save controls and sheets. The earlier Unit 1, mode-control and Undo checks were already accepted.

These are Bilal's reported manual results. Agent-executed checks and their limits remain in the individual sections; no agent frame-rate recording or macOS 26 run is claimed. Latest behavioural evidence is 237 core tests in 27 suites, with four intentional known issues, plus three native tests in one suite. The accepted layout corrections passed build, bundle and running-app checks without artificial layout tests or a repeated full suite.

T07 is done. A11–A14/A32 and the remaining A29 dirty-navigation portion are passed; cross-window and later-mutation criteria remain partial. Local commit `9ecf861` exists; accepted header corrections and current evidence updates are authorised for local commit. Push, PR and merge are not authorised or performed.

## M2 quality checkpoint

Read-only analysis completed on 2026-10-11 at `9ecf861` plus accepted header corrections. This is a sample of M2: full reads of PreviewState, TextPreview, TextFileSnapshot, BrowserState, DetailsState, BrowserWindow, ReadOnlyPreview, BrowserLifecycle, PanePeekApp and ItemPathContextMenu, paired Preview/Editor/Save/native Undo tests, and targeted caller/test searches. The accepted language scanner corpus, later tasks, packaging and whole-repository correctness audit are excluded. Lenses: state ownership, complexity, concrete reuse and test relevance/consistency.

F1 (medium priority, high confidence): the parameterised Discard transition test in `tests/panepeek-core/EditorTests.swift`, lines 90–125, checks prompt count and cleared/restored draft but asserts the requested transition only for Cancel. Selection, focus, navigation, Refresh and clear can lose their Discard continuation without those assertions detecting it. Dedicated deferred context/favourite tests provide counter-evidence for those paths; no runtime failure is claimed. Recommended direction: strengthen the existing test with observable destination/selection/Refresh outcomes and bounded completion. This is one optional test-focused unit, not a production refactor.

Keep the same-read snapshot, original draft/colour baseline, pre/post-await guards and native Undo ownership. Their responsibilities differ and justify their local state/control flow; small local POSIX and fixture duplication does not justify shared infrastructure. No production correctness blocker was identified by this bounded quality analysis.

Standard tighten removed subjective naming/line-count concerns and redundant findings. Evidence probe checked the positive-transition assertions against callers and neighbouring tests, separated the coverage gap from a runtime defect, and limited the result to the sampled area. The internal-doc writing preset was applied. Documentation links/anchors/tables and whitespace checks pass; no code, tests, app state or build was changed by this checkpoint. Existing test/build evidence remains linked above.

Findings await Bilal's review. Recommended route: direct implementation of the single test-focused unit if accepted, or explicit deferral as optional maintenance. Neither remediation nor commit/push/PR/merge is authorised.
