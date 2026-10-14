---
task: m3-m4-editor-lock-ownership
verdict: Passed
closed: "2026-10-14"
---

# M3/M4 editor-lock ownership

C2.1 addresses reviewed finding F1. Bilal approved this unit on 2026-10-14 after clarifying the next-unit reference. Bilal accepted the presented unit overall and authorised its commit on 2026-10-14; committed as `e9cf3a6`. Individual native/accessibility outcomes remain unreported; publication retains separate approval.

## Change

The shared coordinator owns affected-path edit/Save exclusion. Capture installs the scope before Move/Trash confirmation or deferred dirty prompts, and dirty resolution reuses it. PreviewState's mirrored Copy/Move/Trash/drag collections and temporary Save clear/restore path are removed. The coordinator's existing permitted-Save slot now authorises the normal Save method directly. Per-window progress, native drag source snapshots and local rename presentation remain with their existing owners.

The regression exposed an existing confirmation gap: the initiating editor was locked, but another window could still edit the same source before answering Move/Trash. Both windows now reject those edits until cancellation or completion. Unrelated buffer editing and the existing conservative Save/mutation reservation remain available under their established rules. Filesystem services, outcome semantics and persistence are unchanged.

## Checks

- 2026-10-14, red: the two Move/Trash cases in `confirmationLocksEveryAffectedEditorAndCancellationReleasesThem` failed because the foreign editor remained editable and accepted changed text during confirmation. Existing coordination tests passed; the run exited 1 with six related assertion failures.
- 2026-10-14, green: 120 targeted tests passed. The full suite passed 414 core tests across 48 suites and 56 native tests across ten suites (470 total). Nine expected issues are intentional timeout-diagnostic self-tests. Coverage includes confirmation/cancellation locks, operation-authorised Save, failed Save, deferred Discard, rename presentation, drag handoff, same-file conflicts, native text/window bridges and path recovery.
- 2026-10-14: app build, isolated review packaging, launch and process verification passed on macOS 27.0.1 with Swift 6.4. Diff and affected paper-trail link checks pass. Bilal accepted the presented unit overall on 2026-10-14; individual native observations were not separately supplied.

Reproduce automated checks:

```sh
node scripts/test.mjs
swift build --product PanePeek
```

Tighten removed duplicate lock state and setter/cleanup calls without adding an operation framework. Probe checked every capture-to-prompt boundary, early incoming-drop reservations, outgoing drag handoff, authorisation of Save, cancellation cleanup and retained rename presentation. Full native fixture tests pass; individual interactive/accessibility outcomes remain unreported.

## Running app and disposable fixture

From the repository root, activate the isolated app and print its disposable directories:

```sh
node --input-type=module <<'JS'
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const review = JSON.parse(readFileSync('.build/quality-c2-1-review.json', 'utf8'));
execFileSync('open', [review.bundle]);
console.log(`Source: ${review.source}\nDestination: ${review.destination}`);
JS
```

The app has a separate preference domain. The source contains `source.txt`, `unrelated.txt` and `folder/child.txt`; the destination starts empty. Use Command-L for these directories and Command-N for additional windows. Do these checks only with the disposable fixture:

- Open `source.txt` in Edit in two windows. In the first, set the other pane to Destination and invoke Move to Other Pane. Leave confirmation open, then attempt typing or pasting in the second editor. Edits and Save must be blocked in both affected windows. An unrelated editor can still accept buffer edits while Save remains reserved. Cancel and verify editing resumes with text/caret/undo retained. Repeat the cancellation check with Trash.
- Make the second window's source draft dirty, then confirm Move in the first. Cancel the dirty prompt to retain files and draft; repeat with Save to verify the existing authorised Save writes before the move. After success, affected old-path previews close/reload and cannot save to the obsolete source.
- Check an edited `folder/child.txt` while moving its containing folder, plus a guarded outgoing drag and rename. Verify Save/Discard/Cancel, retry gesture, rename read-only presentation and unrelated editing still follow the existing workflows.
- Check keyboard/Escape/focus recovery and VoiceOver's disabled Edit/Save states in affected windows, including after cancellation. Individual outcomes remain unreported; app-wide accessibility acceptance remains T18.
