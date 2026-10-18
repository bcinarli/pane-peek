---
task: native-drag-initiation
verdict: Passed
closed: 2026-10-18
---

# Native drag initiation

The native source path accounts for selection and session-start ordering. Proposed unselected rows use the existing guarded selection transition. Exported file URLs survive mouse-handler return until native session end; preparations without a writer still release their locks. Copy/move execution, collision policy and Finder-controlled outgoing behaviour are unchanged.

## Executed checks (2026-10-18)

- Native baseline: agent-observed drag attempts selected a file without delivering it to the receiving pane. Callback tracing showed preparation before native selection commitment and session start after the mouse handler's unused-preparation cleanup.
- Red: `node scripts/test.mjs --filter 'nativeDragCanStartBeforeTheClickedRowIsSelected|hostedRowsProvideNativeDragImages'` failed on rejected first-row initiation. The diagnostic image check passed; no image change or image-only test was retained. A second `--filter FileDropTests` red failed both exported-snapshot retention expectations after mouse-handler cleanup.
- Green: focused `FileDropTests`, `OutgoingDragTests`, `DropTransferTests`, `WindowRecoveryTests` and `DirectoryTableTests` passed 37 functions. Coverage includes empty/prior selection, cancelled dirty selection, exported-writer retention, abandoned preparations, end cleanup, captured order, copy/move and cross-browser handoff.
- Full `node scripts/test.mjs` passed 561 tests (106 app, 455 core), with nine expected timeout self-test diagnostics. `node scripts/build-app.mjs` and `git diff --check` passed. Environment: macOS 27.0.1 (`26A434`), arm64, Xcode 27.0 (`27A266a`), Apple Swift 6.4; Xcode was selected explicitly.
- The isolated packaged app launched with separate preferences. Post-fix automation started a native drag but did not verify a completed drop. The locked Mac then prevented further native checks. No successful end-to-end pane/Finder gesture is claimed.

## Review passes and remaining checks

Tighten retains one local selection correction and one exported-writer lifetime flag, with shared end cleanup. Probe checks the existing dirty-selection, stale/partial-set, reordering, operation-choice and cross-window guards through the focused suites. No core transfer or duplicate-handling change is included.

Use the [T13 disposable fixture recipe](drag-and-drop-finder.md#disposable-fixture-and-run-instructions). Quit the review app before rebuilding, then use `node scripts/build-app.mjs` and open `.build/PanePeek.app`. Keep test mutations within disposable directories.

- [ ] Drag an initially unselected file, an already selected file and a multiple-item selection between panes in both directions. Check empty receivers, folder-row drops and visible outcomes; default copy retains source bytes.
- [ ] Hold Command for a move into a fresh destination; verify source removal only after success. Check cancelled drags release editing and file actions. Repeat across windows and with Finder.
- [ ] Drag a dirty selected file and drag a different row while the old selection has a dirty draft. Check Save/Discard/retry, Cancel and failed Save without lost edits or exported stale selections.
- [ ] Check keyboard/context transfer alternatives, logical focus and no traps; VoiceOver names/status, long paths/enlarged text, light/dark contrast and relevant increased-contrast/reduced-motion settings. Automated native table/selection regressions do not establish these interactive outcomes.

The presented correction is accepted overall; individual native/accessibility outcomes remain unreported. Publication is recorded in the task row. Full A19–A21/A34 and app-wide accessibility verdicts remain unchanged.
