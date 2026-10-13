---
task: independent-windows-shared-operation-coordination
verdict: Pending
closed: ""
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

The current isolated review bundle and disposable directory are recorded in the ignored `.build/t16-unit1-review.json`. From the repository root:

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
