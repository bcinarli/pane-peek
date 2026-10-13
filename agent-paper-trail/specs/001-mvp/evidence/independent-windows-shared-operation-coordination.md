---
task: independent-windows-shared-operation-coordination
verdict: Passed
closed: "2026-10-13"
---

# T16 independent windows and shared operation coordination

## Unit 1, 2026-10-13

Bilal approved window-bound prompts and safe Quit. Full T13 PR #27 head `2791521` and T15 PR #8 head `87f836a` are ancestors of verified local/live `main` at `8fd0a22`. Implementation uses `feature/t16-independent-windows`; commit, push and manual acceptance remain separate.

Implemented window-owned dirty/Move/Trash prompts, lifecycle registration/cleanup and Quit resolution of all registered dirty documents. Discard is deferred until every document accepts Quit; later cancellation or failed Save retains pending drafts. The Quit portion of A28 and A12/A13 regressions are this unit's scope. New Window, shared mutations, cross-window recovery/drag and independent native state remain later reviewed units. Bilal directed a combined M3/M4 quality checkpoint, which remains pending.

Agent-observed checks on macOS 27.0.1 (26A434), Apple Swift 6.4, Node 26.1.0 and Xcode 27.0:

- Intentional red: `node scripts/test.mjs --filter BrowserLifecycleTests` found that Quit overlooked a dirty first window and its sheet attached to the second window. Probe's `--filter BrowserLifecycleTests/changedDocument` regression then demonstrated that canonically equivalent, differently encoded Unicode edits could be discarded. Compilation/cache setup failures are excluded from red evidence.
- Green: seven lifecycle tests pass, including native owner-sheet attachment, deferred Discard after later Cancel/failed Save, successful Save/Discard, stale/duplicate answers, closed-window cleanup and real same-file Save conflicts. Full `node scripts/test.mjs` passes: 39 native tests plus 395 core tests, with four expected gate-expiry diagnostics enclosed in `withKnownIssue`.
- `swift build --product PanePeek`, isolated asset/bundle packaging, plist validation, `open -n` and process verification pass. Tighten introduced a focused Quit snapshot and reused the existing prompts/save/close behaviour; probe added byte-exact buffer validation. Interactive app inspection was blocked by the locked Mac, so no visual/manual/accessibility pass is claimed.

## Run and disposable fixture

At the review checkpoint, the isolated review bundle and disposable directory were recorded in the ignored `.build/t16-unit1-review.json`. From the repository root:

```sh
node --input-type=module <<'JS'
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const { bundle, fixture } = JSON.parse(readFileSync('.build/t16-unit1-review.json', 'utf8'));
execFileSync('open', ['-n', bundle]);
console.log(`Go to Folder: ${fixture}`);
JS
```

Use Command-L to open that directory. `draft.txt` and `conflict.txt` are disposable UTF-8 files; the review app has a separate preference domain. For a normal build, use the [README](../../../../README.md#build-and-run). Multi-window behaviour is exercised by controlled native test windows until New Window is enabled in its later unit.

## Manual checkpoint, accepted overall

- Edit `draft.txt`; test Close and Quit with Cancel, Save and Discard. Cancel must preserve the buffer and undo; successful Save must persist bytes and Quit/Close must complete.
- Edit `conflict.txt`, then change its disk contents externally. Choose Save during Quit: the app must stay open with the draft and error, preserving the external version.
- Check Move/Trash confirmations and result announcements target the originating window; cancel disposable operation confirmations.
- Exercise Escape/keyboard access, focus recovery and VoiceOver names/roles/error announcements; check light/dark, increased contrast, reduced motion and enlarged text as applicable. Individual outcomes remain unreported.

On 2026-10-13, Bilal accepted the presented Unit 1 overall and explicitly authorised its commit and continuation to Unit 2. Individual native/accessibility outcomes were not supplied; the locked-Mac observation is retained. Unit 2 implementation is approved; later units, push and merge remain gated. T16 and A28 remain Active/Pending and Pending respectively.

Unit 1 is committed locally as `83af06a`; no push was authorised or performed.

## Unit 2, 2026-10-13

Bilal approved continuation to shared mutation reservations and affected-document guards. One application-owned coordinator serialises creation, rename, copy, move, Trash and Save through preflight, prompts and execution. Incoming drops reserve before scheduling their task. Navigation and unrelated editing remain available; affected editing and conflicting mutations/Saves are blocked. All affected dirty windows resolve choices before mutation. Cancel/failed Save retains pending drafts; explicit Saves use verified source baselines. Successful removals close affected editors, including descendants; failed/unattempted sources retain drafts. Pane refresh/path recovery and cross-window drag handoff remain Unit 3; New Window remains Unit 4.

Agent-observed checks use the Unit 1 toolchain:

- Intentional red: original cross-window tests demonstrated ignored dirty Cancel and Rename/Save during an in-flight copy. Probe also observed red for unattached browser construction invalidating a pending operation and replacement native guards losing registrations/prompt bindings/platform delegate forwarding.
- Green: `node scripts/test.mjs` passes 41 native plus 404 core tests (445 total), with the four expected gate-expiry diagnostics. Added real-filesystem/controlled-failure checks cover later Cancel/failed Save, saved-byte copy, foreign file/folder editor closure, failed/partial removals, listed-link target retention and unrelated edit availability. Final `--filter BrowserLifecycleTests` passes nine tests after delegate-forwarding tightening.
- `swift build --product PanePeek`, isolated packaging using unchanged compiled assets, plist lint, launch/process verification and `git diff --check` pass. Tighten reused the typed capture/baseline safeguards and shared prompt resolution; probe corrected registration timing/ownership. Native access was not retried without an unlock signal; interactive/manual/accessibility outcomes remain pending.

### Unit 2 run and fixture

The running app uses a separate preference domain. The ignored `.build/t16-unit2-review.json` records its bundle and disposable `source`/`destination` directories:

```sh
node --input-type=module <<'JS'
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const review = JSON.parse(readFileSync('.build/t16-unit2-review.json', 'utf8'));
execFileSync('open', ['-n', review.bundle]);
console.log(`Source: ${review.source}\nDestination: ${review.destination}`);
JS
```

Use Command-L to open those directories in the two browsers. Fixtures include `draft.txt`, `folder/child.txt` and `link.txt` pointing to `target.txt`. Foreign-window guards use controlled core/native fixtures until New Window is enabled. Normal rebuild instructions remain in the [README](../../../../README.md#build-and-run).

### Unit 2 manual checkpoint, accepted overall

- Edit a disposable source and exercise Copy/Move/Rename/Trash through Save, Discard and Cancel. Cancel/failed Save must prevent the requested mutation; failed destructive operations retain the draft.
- While copying a sufficiently large disposable folder, verify navigation/layout and unrelated editing remain responsive, while mutation/Save actions and Quit are blocked until the operation finishes.
- Check action availability recovers after success, cancellation, collision and failure; repeat Close/Quit dirty guards to cover the native registration integration.
- Check disabled-state names, keyboard access/focus, Escape, VoiceOver errors/status, and affected light/dark, contrast, enlarged-text and macOS accessibility settings. Individual outcomes remain unreported.

On 2026-10-13, Bilal accepted the presented Unit 2 overall, authorised its commit and approved Unit 3 continuation. Individual native/accessibility outcomes remain unreported. T16 and mapped criteria remain Pending; Unit 4, later commits and push/merge retain separate approval gates.

Unit 2 is committed locally as `06ba58c`; no push was authorised or performed.

## Unit 3, 2026-10-13

Bilal approved cross-window pane refresh, path recovery and drag coordination. Creation, Copy and Save refresh every registered matching pane, preserving unrelated drafts and view settings. Rename/Move apply the existing cached-path recovery to every pane, including hidden panes and pending reads. Trash falls back to the nearest accessible parent and shows a recovery explanation in the affected pane, with an announcement targeted to its owning window. Partial removals update only completed source paths; failures and refresh errors remain visible.

Outgoing drags resolve affected dirty documents across windows before exporting URLs, then require a fresh gesture. Captured sources lock affected editing/Saves and conflicting mutation commands until the drag ends. A matching drop in another PanePeek browser receives the reservation synchronously, retains its submitted destination and avoids the outgoing Finder notice. Finder-controlled transfers retain the explicit Refresh guidance. New Window and independent native state/shared favourites remain Unit 4.

Agent-observed checks use the recorded Unit 1 toolchain:

- Intentional red: `node scripts/test.mjs --filter WindowRecoveryTests` demonstrated stale foreign Copy/creation/Save listings, unchanged foreign Move/Rename descendant paths and rejection of cross-window drops. Probe's `--filter WindowRecoveryTests/foreignDirtyContainer` then demonstrated mutation commands offered during another window's drag even though execution rejected them. Both regressions are green after correction; syntax/setup failures are excluded from red evidence.
- Green: final `node scripts/test.mjs` passes 42 native plus 410 core tests (452 total), with four expected gate-expiry diagnostics. Checks include retained foreign drafts and Save conflicts, failed descendant refresh with usable cached new paths, nearest accessible Trash fallback/status, hidden-pane pending-read invalidation, partial-result listing recovery, cross-window Copy/Move destination capture, outgoing foreign Save/Discard/Cancel and failed Save, and real native table/pasteboard sender/receiver callbacks.
- `swift build --product PanePeek`, isolated packaging with unchanged compiled assets, plist/executable validation, launch/process verification and `git diff --check` pass. Launch required the unsandboxed shell after the sandboxed attempt returned a Launch Services error. Tighten reused the typed recovery helpers and shared the concrete refresh path across Copy/creation/Save; probe aligned command availability with drag exclusion and checked delayed reads/partial outcomes. Interactive/native accessibility access was not retried without an unlock signal.

### Unit 3 run and fixture

The running app has a separate preference domain. The ignored `.build/t16-unit3-review.json` records the isolated bundle and disposable directories. Use the Unit 2 run recipe above with that metadata filename, then Command-L to open `source` and `destination` in the two browsers. Fixtures include `draft.txt`, `folder/nested/child.txt`, `trash-me/nested/disposable.txt`, `.hidden.txt` and a listed `link.txt` to `target.txt`.

### Unit 3 manual checkpoint, accepted overall

- Browse `source` in one pane and `source/folder/nested` in the other. Rename `folder` and verify the nested pane follows its new path and retains its settings. For Trash, repeat with `trash-me/nested`: the nested pane must recover to an accessible parent and explain the change.
- Exercise creation/Copy/Save with matching directories, retaining unrelated drafts and selection/sort/visibility. Check errors and partial-result messages, stale or newer navigation, and normal Save/Discard/Cancel behaviour.
- Repeat pane-to-pane and Finder Copy/Command-Move. Dirty outgoing attempts must export nothing, resolve changes and require another gesture; mutation/edit/Save availability must recover after completion or cancellation.
- Check the new recovery message and disabled actions through keyboard/focus and VoiceOver, plus affected light/dark, contrast and enlarged-text settings. Interactive cross-window gestures and independent state/shared favourites remain the Unit 4 native checkpoint while New Window is disabled.

On 2026-10-13, Bilal accepted the presented Unit 3 overall, authorised its commit and approved Unit 4 continuation. Individual native/accessibility outcomes remain unreported. T16 remains Active/Pending; Unit 4 commit and push/merge retain separate approval gates.

Unit 3 is committed locally as `9a72b92`; no push was authorised or performed.

## Unit 4, 2026-10-13

Bilal approved New Window with independent state and shared favourites. The app now uses `WindowGroup`, retaining each browser's existing SwiftUI State for panes/editor, prompt owner and Details sizing. The app still owns one favourite store and operation coordinator. Native New Window can create fresh home panes in two-browser mode with compact Details. System scene restoration is explicitly disabled, following the accepted single-configuration policy; T17's remembered-directory implementation remains separate. [Apple's scene-restoration documentation](https://developer.apple.com/documentation/swiftui/scenerestorationbehavior) and the installed SDK declaration informed that modifier.

Agent-observed checks use the recorded toolchain:

- New Window is scene/UI integration checked by build and launch, with actual command/scene creation pending manual review. No artificial source-shape red test is claimed. A full SwiftUI-root hosting fixture could not activate scene tasks in this test runner; its setup failures are excluded from behavioural evidence. The final check uses established native split-controller/window-guard fixtures.
- Final `node scripts/test.mjs` passes 43 native plus 410 core tests (453 total), with four expected gate-expiry diagnostics. The added native fixture checks fresh defaults after another window has a draft and changed mode/width, independent presentation/sort/hidden selection/editor state and Details widths, favourite operations retaining document state, actual owning-window Quit sheet attachment and Cancel retaining the draft. It does not claim live New Window creation or star/menu rendering. Existing lifecycle, same-file conflict, mutation/dirty, recovery and pasteboard handoff tests remain green.
- `swift build --product PanePeek`, isolated packaging with unchanged compiled assets, plist validation, launch/process verification and `git diff --check` pass. The first launch used an incorrect generated path; launching the verified metadata path succeeded. Tighten kept the scene change small and reused existing ownership; probe checked restoration policy and retained the explicit manual gaps. Interactive access was not retried without an unlock signal.

### Final T16 run and fixture

The running app has a separate preference domain. Activate its bundle and print the disposable directories from the repository root:

```sh
node --input-type=module <<'JS'
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const review = JSON.parse(readFileSync('.build/t16-unit4-review.json', 'utf8'));
execFileSync('open', [review.bundle]);
console.log(`Source: ${review.source}\nDestination: ${review.destination}`);
JS
```

Create additional windows with File → New Window (Command-N) inside that app. Use Command-L for the disposable directories. Fixtures include `draft.txt`, `conflict.txt`, `folder/nested/child.txt`, `trash-me/nested/disposable.txt`, `.hidden.txt` and `link.txt` to `target.txt`.

### Unit 4 manual checkpoint, accepted overall

- Change one window's directories, active browser, one/two-pane mode and Details width, then Command-N. Verify the new window starts with two home panes and compact Details; navigation, selection, sorting, hidden visibility, preview/editor/caret/undo and subsequent layout/width changes remain independent. Close the final window and use New Window again.
- Toggle and remove favourites from either window. Check both stars and toolbar/menu favourites update without changing either document or selection. Confirm Go/View/File/Refresh/Save actions target the active window, including editor or toolbar focus.
- Copy/Command-Move between windows and to/from Finder. Resolve outgoing and affected foreign dirty buffers through Save/Discard/Cancel. Verify duplicate/conflicting operations are rejected, navigation remains responsive, and completed/failed/unattempted results and source/destination refresh remain accurate.
- Browse a folder descendant in one window and rename/move/Trash its ancestor in the other. Verify followed paths or explained nearest-parent fallback, retained failed/unattempted drafts, and no saving to obsolete paths. Edit the same file in both windows: Save one, then verify the other retains its draft and reports the disk conflict.
- Attempt Quit with dirty windows, including earlier Discard followed by later Cancel/failed Save. Verify pending drafts/undo survive. Check owning sheets/announcements, keyboard/Escape/focus, VoiceOver, light/dark, contrast and enlarged text. Relaunch must not restore all prior windows; remembered configuration remains T17.

On 2026-10-13, Bilal accepted Unit 4 and the final T16 result overall, authorising its commit and PR creation. All four units are accepted; T16 is Completed/Passed for the presented task scope. Individual live New Window/menu/Finder/accessibility outcomes remain unreported, so full criterion verdicts retain their evidence limits. Publication and subsequent merge authorisation are recorded below. T17 and the combined M3/M4 quality checkpoint remain separate gates.

## Publication, 2026-10-13

Unit 4 is committed as `2ade08f`. Feature commits `83af06a`/`06ba58c`/`9a72b92`/`2ade08f` are published in [PR #29](https://github.com/bcinarli/pane-peek/pull/29), targeting `main`. The PR is attached to the task. Bilal authorised its merge and task-workspace cleanup on 2026-10-13; the linked PR records the live merge result. The initial GitHub query reported no checks, so no remote CI pass is claimed. Final local validation remains 453 tests plus the recorded build/bundle/launch checks. No coding units remain; individual live/native/accessibility outcomes and the combined M3/M4 quality checkpoint retain their stated limits. Verify the full closing PR head on current `main` before T17; coding approval remains separate.

## Cleanup authorisation, 2026-10-13

Bilal requested removal of task-owned review bundles, disposable fixtures and ignored scratch files after merge. The metadata-based launch recipes above describe the historical review checkpoints and require those local artifacts. For a fresh app use the [build/run instructions](../../../../README.md#build-and-run); recreate disposable UTF-8 files and source/destination directories for the manual checklist. Existing apps and unrelated artifacts are outside this cleanup.
