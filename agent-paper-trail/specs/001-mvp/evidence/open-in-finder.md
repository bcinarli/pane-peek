---
task: open-in-finder
verdict: Pending
closed: ""
---

# Evidence: open-in-finder

- 2026-10-12 Unit 1: Bilal approved context/File Open in Finder in an isolated worktree. Intentional red: `node scripts/test.mjs --filter FinderOpeningTests` compiled and failed all four tests with six routing/error expectations. Green: the four tests passed after implementation; the final `node scripts/test.mjs` passed 24 app tests and 292 core tests, with four expected timeout-diagnostic known issues. `node scripts/build-app.mjs` packaged the app; `git diff --check` passed. Environment: macOS 27.0.1 (26A434), Swift 6.4, Node 26.1.0.
- Native observations: an unselected context-clicked file became selected and Finder revealed `notes.txt`; a directory context action opened its contents containing `inside.txt`. File Open in Finder was disabled with no selection, enabled while editing, and retained the exact dirty draft. Moving a disposable selected file externally produced an alert naming the missing item without clearing selection/editor. The final rebuilt app also revealed and selected `file-link` itself in one-pane mode. The original fixture file was restored; no draft was saved.
- Tighten retained one native integration and existing context guards, reduced its input to URLs and split the large SwiftUI expression to keep compilation tractable. Probe checked current filesystem types, packages, broken/file/directory links, Unicode/newline names, missing-item preflight and Finder-opening failures. Unit status remains Active/Pending until Bilal's manual/accessibility review.
- 2026-10-12 Publication approval: Bilal stated “I'll review post merge” and authorised commit and PR creation, including the required branch push. Manual/accessibility review is deferred until after merge as an explicit timing exception; acceptance and A17/A18 remain Pending. Merge is a separate action.
- 2026-10-12 Publication: feature commit [78d2922](https://github.com/bcinarli/pane-peek/commit/78d29228b7cf16abab5ade661f24350e74252253) pushed; [PR #22](https://github.com/bcinarli/pane-peek/pull/22) created against `main`. Publication does not close the pending manual/accessibility checklist.

## Accessibility and limits

The native context/File menu labels and enabled states, and the missing-item alert/OK control, were observed through macOS accessibility. Actual keyboard-only native menu navigation, VoiceOver announcements, light/dark appearance and enlarged-text/increased-contrast checks remain pending. Computer-use key injection did not activate the native File menu, so no keyboard pass is claimed.

The integration uses Apple's [explicit-application opening API](https://developer.apple.com/documentation/appkit/nsworkspace) for directory contents and [Finder selection API](https://developer.apple.com/documentation/appkit/nsworkspace/activatefileviewerselecting(_:)) for files. File reveal provides no completion/error callback; detected filesystem and directory-opening errors are shown, without claiming a confirmed reveal completion. Directory opening may partly succeed before Finder reports a failure. Existing A17/A18 and app-wide accessibility verdicts remain Pending.

## Disposable fixture and run instructions

From the isolated checkout, build with `node scripts/build-app.mjs` and open `.build/PanePeek.app`. Use Command-L to enter the fixture path printed by:

```sh
node --input-type=module <<'JS'
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = mkdtempSync(join(tmpdir(), 'panepeek-finder-review-'));
mkdirSync(join(root, 'folder'));
mkdirSync(join(root, 'Example.app'));
writeFileSync(join(root, 'folder', 'inside.txt'), 'Folder contents\n');
writeFileSync(join(root, 'notes.txt'), 'Original notes\n');
writeFileSync(join(root, 'café 👀.txt'), 'Unicode notes\n');
symlinkSync(join(root, 'notes.txt'), join(root, 'file-link'));
symlinkSync(join(root, 'folder'), join(root, 'folder-link'));
symlinkSync(join(root, 'missing.txt'), join(root, 'broken-link'));
console.log(root);
JS
```

Keep the fixture until cleanup is authorised. Coverage maps to A17/A18; the original T14 acceptance is unchanged.

## Bilal's manual checklist

- [ ] Right-click files/directories in either pane and in one-pane mode. Verify file reveal, directory contents, and retained PanePeek location/selection.
- [ ] Try multiple/mixed selections, packages and file/directory/broken links; check listed-link identity and correct Finder targets.
- [ ] Use the File action with the keyboard and VoiceOver, including empty selection and an unsaved draft. Check the alert's name/focus/announcement for an unavailable item.
- [ ] Check menu readability in light/dark appearance and applicable enlarged-text/increased-contrast settings. Record outcomes or remaining limits.
