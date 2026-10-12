---
task: fluid-details-preview
verdict: Passed
closed: "2026-10-12"
---

# Evidence: fluid-details-preview

- 2026-10-12 Unit 1: Bilal approved remaining-height sizing for Preview/Edit, retaining metadata below and a usable minimum with outer scrolling. The 236-point fixed height becomes a minimum; the existing native text view and controls are reused. Layout uses build/native checks rather than artificial TDD tests. Environment: macOS 27.0.1 (26A434), Swift 6.4, Node 26.1.0.
- Executed regression check: `node scripts/test.mjs --filter 'PreviewTextViewTests|BrowserSplitViewTests|DetailsSizingTests'` passed all 14 tests in three suites, including native undo, mode guards, retained document/selection/scroll and width bounds. `node scripts/build-app.mjs` packaged the app; bundle plist validation and `git diff --check` passed. Existing toolchain/deprecation warnings remain outside this layout unit.
- Agent-observed geometry: an isolated native harness compiled the actual DetailsSidebar and production preview/sizing helpers against the built core. At 500-point width, preview heights were 236, 385 and 785 points for content heights 480, 800 and 1,200. After text layout settled, vertical resizing retained the same native text view, exact disposable dirty draft, selection, scroll origin and Undo. At 280 × 480, long-file, file-link and directory cases retained an outer 427-point scroll region with content heights 801.5, 841 and 857.5 points respectively. These are native layout checks, not live visual or VoiceOver acceptance.
- Tighten retained the existing text view, controls and scrolling, adding only viewport measurement and flexible minimum-height layout. Probe verified growth, minimum height, long paths/link targets and native editor retention. No source changes were needed after the first passing regression run. Live app launch/inspection remained blocked by the locked Mac; no launch or visual pass is claimed.
- 2026-10-12 Acceptance/publication approval: Bilal stated “Approved, commit and create PR”, accepting the presented unit and authorising commit, the branch push required for a PR, and PR creation. Merge retains a separate gate. Individual manual/accessibility outcomes were not separately reported; this acceptance does not establish a whole-app accessibility pass.

## Manual and accessibility review

Bilal accepted the presented unit on 2026-10-12. The review setup covers short/tall windows, compact/expanded Details widths, preview growth, path/metadata/link-target scrolling, loading/empty/unsupported states and Edit draft/selection/scroll/undo retention. Individual keyboard, VoiceOver, enlarged-text and light/dark outcomes remain unreported. The Mac was locked during agent UI inspection attempts; no agent-observed live UI pass is claimed. App-wide accessibility remains T18.

## Build and review setup

Build with `node scripts/build-app.mjs`, then open `.build/PanePeek.app`. Quit a running development bundle before rebuilding. Create disposable review files using:

```sh
node --input-type=module <<'JS'
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = mkdtempSync(join(tmpdir(), 'panepeek-fluid-preview-'));
const folder = join(root, 'long-directory-'.repeat(10), 'nested-directory-'.repeat(10));
mkdirSync(folder, { recursive: true });
const file = join(folder, 'sample.swift');
writeFileSync(file, Array.from({ length: 100 }, (_, i) => `let value${i} = ${i}`).join('\n'));
writeFileSync(join(root, 'empty.txt'), '');
symlinkSync(file, join(root, 'file-link'));
console.log(root);
JS
```

Use Command-L for the printed directory. Preview `file-link`, navigate to its long-path target and resize the window; try Edit with `sample.swift` without saving. Select the directory and `empty.txt` to check metadata access and preview states. The unit is Completed/Passed for its accepted scope; publication is recorded separately. Merge requires separate approval.
