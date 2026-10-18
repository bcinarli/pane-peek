---
task: transfer-duplicate-choices
verdict: Passed
closed: 2026-10-18
---

# Transfer duplicate choices

Copy and Move share collision planning and one owned native sheet with a horizontal Keep Both / Cancel / Replace row. Keep Both retains the Mauve default action and an editable numbered name; Replace is offered only for regular files. Copy stages new contents privately before displacing the approved destination, publishes exclusively and restores the previous destination on failure when its path is free. A late winner is retained, with the previous destination's recovery path reported. Sources are retained.

## Executed checks (2026-10-18)

- Red: the three initial Copy behaviour tests failed with 14 issues before implementation. The native alert layout check separately observed three different button Y positions instead of one horizontal row.
- Shared planning preserves invalid/occupied/batch-reserved name handling, captured source/destination identities and all-before-write resolution. New checks cover Copy Keep Both/Replace, Cancel before the first copy, foreign destination Save/Discard/Cancel and failed Save, folders/packages/links, staging failures, late changes and publication recovery.
- Native sheet checks exercise owner-change cancellation, edited names, duplicate callback suppression, ordered non-overlapping button frames, real sheet attachment/completion, name-field submission and Escape. Inactive default-button handling does not establish a physical Return-key pass.
- Probe red/green exposed a second click changing the first answer before queued completion. The sheet now accepts only its first answer. Final focused checks pass 75 tests (four app, 71 core); full `node scripts/test.mjs` passes 571 (109 app, 462 core), with nine expected timeout self-test diagnostics. Incoming-drop coverage now checks Keep Both and whole-batch Cancel under the revised Copy policy. Environment: macOS 27.0.1, Xcode 27.0, Apple Swift 6.4, arm64; Xcode explicitly selected.
- Agent-inspected Light/Dark native renders show the horizontal row, editable name and readable inactive controls. The temporary rendering helper was removed. Active Mauve presentation remains a live review check.
- App packaging, diff whitespace and changed-document local links pass. An isolated review app was launched and its process verified, with disposable duplicate files configured as its starting folders. No live visual/VoiceOver pass is inferred from that launch.
- Unlocked live follow-up: Copy Keep Both completed via Return from the selected name field, Escape cancelled the next attempt, and clicking Replace completed the regular-file replacement. Visible notifications/listings and byte checks verified the numbered copy, source retention, unchanged bytes after Cancel and replacement contents. The active horizontal row and dark Mauve-button text are readable. Full Move, draft and accessibility checks remain pending.
- The attached sheet uses a neutral grey backdrop despite the intended Mantle role. [Backdrop follow-up](collision-sheet-backdrop.md) tracks this remaining visual gap; inactive standalone renders did not reveal it.

## Review passes and remaining checks

Tighten reuses the existing collision planner and replacement metadata, with local Copy staging/recovery. Probe covers late winners, prior-destination retention, destination draft guards and shared operation locks. Automated checks do not establish live keyboard or VoiceOver acceptance.

- [ ] In the running app, Copy and Move a duplicate regular file: review the horizontal button row and accent, edit the Keep Both name, use Replace and Cancel, and verify the source/destination contents.
- [ ] Try a duplicate folder/package/link and a batch with a later conflict. Check Keep Both naming and whole-batch Cancel before any write; no folder merging or link replacement.
- [ ] Keep an affected destination draft open in another window. Exercise Save/Discard/Cancel and failed Save, then verify draft/data retention and operation-lock release.
- [ ] Check Return from the name field and buttons, Escape, focus order/rings, VoiceOver names and states, Light/Dark/active/inactive contrast and enlarged/long-path content.

The presented unit is accepted overall. Individual live keyboard, appearance and accessibility outcomes remain unreported. Full A6/A20 and app-wide accessibility verdicts remain Pending.
