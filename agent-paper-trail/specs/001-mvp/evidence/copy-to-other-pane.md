---
task: copy-to-other-pane
verdict: Pending
closed: ""
---

# T10 Copy selected items to the other pane

## Unit 1, 2026-10-12

- Bilal approved safe single-item copy and required isolation for parallel work. Implemented on `feature/t10-single-item-copy` from verified `main` at `ad97158`, containing T09 PR #20 head `b42a7f7`. Bilal accepted Unit 1’s presented manual/accessibility scope and authorised its commit plus continuation to Unit 2 on 2026-10-12. Individual native settings/outcomes were not separately supplied. Push remains unapproved.
- Agent-observed intentional red: filesystem copies/rejections (6 tests, 29 issues), browser integration (6 tests, 20 issues), Shift-F10 routing (1 issue), unrelated-draft completion refresh (2 issues), and the affected edit lock after Save (1 issue). Compilation/setup failures were corrected and excluded from red evidence. Commands used `node scripts/test.mjs --filter` with `ItemCopyTests`, `CopyTests`, `keyboardContextMenu`, `completionRefreshRetainsAnUnrelatedDraft` and `capturedTargetsSurvive` respectively.
- Agent-observed green: affected regressions passed, then `node scripts/test.mjs` passed 326 tests (21 native, 305 core), with four expected `withKnownIssue` gate-diagnostic cases. `node scripts/build-app.mjs` succeeded and the isolated app process launched with `open -n .build/PanePeek.app`. Tighten then probe applied. Agent native interaction was blocked by the locked Mac. Bilal accepted the presented Unit 1 manual/accessibility scope on 2026-10-12; this is reviewer acceptance, not an agent-observed native result.

Scope covers single-item copy portions of A5–A8/current-window A9 and affected A4/A18/A25/A33/A34 checks. A20 batches and cross-window coordination remain later units/tasks. Full criteria remain Pending because batch copying and later-task scope are incomplete.

Runtime: macOS 27.0.1 (26A434), Apple Swift 6.4, Node 26.1.0; selected Command Line Tools with the documented Xcode asset-compilation fallback. Existing toolchain deprecation/link-search warnings remain outside this unit.

## Disposable fixture and run instructions

Run from this feature checkout. Quit only its app instance before rebuilding; keep parallel app instances untouched.

```sh
node scripts/build-app.mjs
open -n .build/PanePeek.app
python3 - <<'PY'
from pathlib import Path
import tempfile
root = Path(tempfile.mkdtemp(prefix='panepeek-t10-review-'))
left, right = root / 'left', root / 'right'
left.mkdir(); right.mkdir()
(left / 'copy-me.txt').write_text('Original copy fixture 👀\n')
(left / 'unrelated.txt').write_text('Unrelated document\n')
(left / 'occupied.txt').write_text('Source collision bytes\n')
(right / 'occupied.txt').write_text('Keep destination bytes\n')
(right / 'from-right.txt').write_text('Right-to-left fixture\n')
(left / 'folder' / 'nested').mkdir(parents=True)
(left / 'folder' / 'nested' / 'child.txt').write_text('Nested copy fixture\n')
(left / 'sample.app' / 'Contents').mkdir(parents=True)
(left / 'sample.app' / 'Contents' / 'sample.txt').write_text('Package fixture\n')
(left / 'file-link').symlink_to('copy-me.txt')
(left / 'broken-link').symlink_to('missing.txt')
(left / 'directory-link').symlink_to('folder')
(root / 'descendant-alias').symlink_to(left / 'folder' / 'nested')
(right / 'unwritable').mkdir(); (right / 'unwritable').chmod(0o555)
(left / 'many-files').mkdir()
for index in range(2500):
    (left / 'many-files' / f'{index:04}.txt').write_text('Copy responsiveness fixture\n')
print(f'Open these with Go to Folder: {left} and {right}')
PY
```

Each run creates a fresh directory; do not test mutations on working files. Relative links retain their stored target text, so their targets may be absent after copying. Existing collisions are intentionally rejected. The unwritable-directory fixture provides a real copy failure under ordinary non-root execution. Injected partial-destination coverage is automated; no real partial-write/volume claim is made.

## Unit 1 native/manual and accessibility checklist

- [ ] Open `left`/`right`, copy `copy-me.txt`, `folder`, `sample.app` and each link; inspect bytes/nested contents/link text and intact sources. Copy `from-right.txt` back. Verify row appearance, independent settings and Details after refresh.
- [ ] Reject `occupied.txt`, the same directory and `folder` into its own nested directory, including a destination alias. Preserve existing bytes. Use `right/unwritable` as destination and read/dismiss the accurate error.
- [ ] Copy `many-files`; navigate and switch One/Two Panes while active, keeping the captured destination. Reject new One Pane, stale-selection and multiple-selection requests; keep conflicting creation/rename disabled while copying.
- [ ] Edit a source and check Save/Discard/Cancel. Cancel or failed Save copies nothing. Check affected edits stay disabled during execution, while an unrelated draft survives completion refresh.
- [ ] With a selected row and table focus, open its menu using Shift-F10 (Fn may be needed), use arrows/Return, then Escape. Check focus, no traps, right-click targeting, row accessibility actions and VoiceOver status/error announcements.
- [ ] Check light/dark contrast and non-colour status cues, narrow/long-path layouts, supported text-enlargement mechanism/sizes and limits, pointer targets, increased contrast and reduced motion. These unit checks do not close the T18 app-wide audit.

Unit 1 manual review: Passed by Bilal on 2026-10-12 for the presented scope; individual checklist observations were not separately supplied. Unit 2 coding and Unit 1 commit are approved. Task verdict remains Pending. Publication: none; push unapproved.
