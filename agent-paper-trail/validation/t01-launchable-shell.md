# T01 launchable shell validation

Status: Accepted. Bilal approved Unit 1 on 2026-10-03 and Unit 2 on 2026-10-04, then accepted the current shell/icon state on 2026-10-04: “ok. approved the current state”. Bilal subsequently confirmed all four remaining manual checklist items that day. T01 is done.

## Scope and environment

The unit implements the application package, one native window with two pane areas and a far-right Details sidebar, a local bundling script and build/run documentation. Browsing, file operations, actual metadata/preview content and independent windows remain in later tasks.

Validated on macOS 27.0.1 (26A434), Apple Silicon, Swift 6.4, Command Line Tools with SDK 27.0, and Node.js 26.1.0. The package, executable and bundle declare macOS 26.0 as the minimum. Runtime testing on macOS 26 and testing with the minimum documented Swift/Node versions have not been performed.

## Executed checks

Commands below run from the repository root. The separate clean-build directory was fresh for this check; no existing build output was deleted.

These agent checks predate Bilal's final manual confirmation. Their pending observations are resolved in [the manual checklist](#bilals-manual-checklist).

| Check | Evidence | Result |
| --- | --- | --- |
| Build and bundle | `node scripts/build-app.mjs` | Passed; creates `.build/PanePeek.app`. |
| Clean build | `swift build --scratch-path <fresh temporary directory> --product PanePeek` | Passed; exact temporary path is kept in the private session journal. |
| Script syntax | `node --check scripts/build-app.mjs` | Passed. |
| Bundle metadata | `plutil -lint .build/PanePeek.app/Contents/Info.plist` and `plutil -p` | Passed; application bundle, correct executable, minimum macOS 26.0. |
| Executable target | `xcrun vtool -show-build .build/PanePeek.app/Contents/MacOS/PanePeek` and `file` | Passed; arm64 Mach-O, minimum macOS 26.0. |
| Bundle launch | `open .build/PanePeek.app`, application process check and desktop inspection | Passed; window contains both pane areas and Details at the far right. Bilal also confirmed visibility. |
| Native window resizing | Desktop inspection before/after native window zoom and return | Passed at the observed sizes; labels and empty regions remain readable. Dragging dividers remains in Bilal's checklist. |
| Close/reopen | Command-W, then reopen the bundle | Passed; window returns with the shell layout. |
| Quit/relaunch | Command-Q, confirm process exit, then reopen the bundle | Passed; app process and window return. Left open for review. |
| Dark appearance | Desktop screenshot and accessibility tree | Passed for the shell layout. Light appearance remains pending. |
| Whitespace | `git diff --check` | Passed. |

The first sandboxed build failed because Swift could not write its normal compiler caches. Retrying with cache access passed. Both successful builds emitted non-fatal warnings about missing Command Line Tools linker search directories. No application compile or link error remained.

No automated behaviour suite exists for this static shell. Layout and packaging use actual build/launch checks under the plan's explicit exception; setup/import failures are not recorded as red/green behaviour evidence.

## Acceptance and self-review

- T01 build/package/window layout: validated by the checks above; Bilal accepted the current result on 2026-10-04.
- A31: Partially validated for the far-right sidebar layout and preview area above the information area. Selection-driven content and metadata remain pending in later tasks.
- All other A1–A33 criteria: Pending.
- Tighten: kept the layout local, reused the pane view and omitted empty core/test scaffolding. No additional abstraction or refactor was needed.
- Probe: checked real bundle startup/lifecycle, deployment metadata and a fresh build. Kept light appearance, divider interaction and macOS 26 runtime testing explicit; no correctness blocker was found in the exercised shell paths.
- No milestone boundary has been reached. Milestone quality analysis remains at M1 completion.

## Design checkpoint: 2026-10-04

Reviewed the live native shell, its source and the [accepted Browse & peek reference](../design/001-mvp/README.md) after integrating the merged design baseline. The editable UI fragment supplies layout/colour evidence; its simulated behaviour is not the native implementation contract. No native code changed during this review.

| Aspect | Finding | Next scope |
| --- | --- | --- |
| Overall layout | Both pane areas remain beside far-right Details; the sidebar is roughly one third of the default window. This matches the balanced direction. Preview is above information. | Retain this structure and adjustable dividers. |
| Native appearance | At this checkpoint, only native dark surfaces had been checked. Bilal later confirmed light/dark appearance in the manual checklist. | Repeat with subsequent UI tasks. |
| Pane headings | Visible `Left pane` / `Right pane` headings conflict with the accepted requirement to avoid visible Left/Right labels. | Remove those visual labels while retaining distinct accessible pane names. |
| Details content flow | The empty preview expands through most of the sidebar and pushes information to its bottom. The draft groups preview, path and metadata in a top-to-bottom content stack. | Align the empty-state grouping without introducing real preview/metadata behaviour. |
| Navigation and focus | Compact Home/root breadcrumbs, focused-pane underline and shared controls are absent. They belong to T02/T03; functional stars belong to T15. | Prepare compact header space in shell alignment; implement actions and focus with their mapped tasks. |
| Preview, paths and logo | The shell has no selected-file path, mode switch, highlighting or custom icon. These are scheduled work, not failures of the initial shell unit. | Follow T05–T07/T14 for Details/paths and T18 for production icon preparation; reuse accepted sources. |

Bilal approved **T01 Unit 2** on 2026-10-04: align static chrome and empty states with the accepted draft, and bundle a development app icon using the accepted peeking-P SVG artwork. Remove visible pane labels, retain accessible names, use compact aligned header areas and group Details content below its heading. Keep native surfaces and the existing three-region split; add functional navigation, favourites, focus state and document behaviour only in their mapped tasks.

Application changes are in `Sources/PanePeek/BrowserWindow.swift`, `Assets/PanePeek.icns`, `scripts/build-app.mjs` and the two icon-export helpers, plus task/run/validation documents. The accepted SVG geometry/composition is unchanged. Validation uses build/package/launch and native resizing, appearance, accessibility and Dock/Finder/app-switcher icon review; no artificial behaviour tests for static layout/packaging. No fixture is needed. This covers T01 layout and the layout portion of A31, not the full criterion. Final production icon refinement and small-size acceptance remain in T18.

Tighten kept the review to observed shell differences and mapped later features rather than proposing a wholesale port of the HTML sample. Probe checked the live window and source, retained the native/preview distinction and kept manual acceptance and revised sequencing pending.

## Unit 2: static alignment and development icon

Implemented under Bilal's explicit approval on 2026-10-04. Both panes have aligned 44-point headers with no visible Left/Right labels; their accessible container names distinguish them. Details groups its 236-point empty preview and information beneath its heading in a scrollable stack. Native surfaces and the three-region split remain. No browsing, selection or file operations were added.

The icon exporter renders the accepted SVG composition with macOS Quick Look, adds transparent margins/rounded background using AppKit, generates 1×/2× representations from 16 through 512 points and writes the checked-in ICNS. Normal builds copy this asset into bundle Resources and name it in `CFBundleIconFile`; they do not need to regenerate it. The SVG/UI draft files have no content changes.

Checks used the same macOS 27.0.1, Swift 6.4, SDK 27.0 and Node 26.1.0 environment stated above.

| Check | Evidence | Result |
| --- | --- | --- |
| Final icon export | `node scripts/export-app-icon.mjs` after tighten | Passed; built-in tools produce the ICNS with transparent margins. |
| Final build/package | `node scripts/build-app.mjs` | Passed; bundle includes the icon. |
| Fresh compilation | `swift build --scratch-path <fresh temporary directory> --product PanePeek` | Passed in 20.10 seconds; same non-fatal CLT linker search-path warnings. |
| Script syntax | `node --check scripts/build-app.mjs` and `node --check scripts/export-app-icon.mjs` | Passed. |
| Bundle/deployment metadata | `plutil -lint`, `plutil -p` and `vtool -show-build` on the bundle | Passed; icon entry present and minimum macOS 26.0. |
| Icon contents | ICNS extraction via `iconutil`; container, PNG dimensions/RGBA, native alpha and asset/bundle checks | Passed; all ten representations have expected dimensions, the outer margin is transparent, the centre is opaque and the copied asset matches. |
| Native icon resolution | AppKit `NSWorkspace.icon(forFile:)` plus Finder icon-view screenshot | Passed; peeking-P artwork replaces the generic app icon in Finder. Bilal later confirmed Dock/app-switcher presentation below. |
| Native layout/accessibility | Running dark window, accessibility tree and native zoom/return | Passed at observed sizes; compact headers align, Details information follows the preview, and both pane/container names are exposed. Agent coordinate drags were inconclusive; Bilal later confirmed resizing/dividers below. |
| Lifecycle | Command-W/reopen; Command-Q, absent process, then relaunch and window inspection | Passed; the single-window app exits when its window closes on this host and relaunches with the shell. |
| Document integrity | Local links/anchors, acceptance IDs, tracker and Git index checks | Passed; 115 links across 20 Markdown files, A1–A33 intact, T01 review/17 later tasks not started, no staged or unmerged changes. |
| Whitespace | `git diff --check` | Passed. |

A temporary agent launch argument (`-AppleInterfaceStyle Light`) did not change the observed dark window and is not counted as a light-mode pass. The app was relaunched without it; no system appearance setting was changed. Agent Dock inspection timed out. Bilal's subsequent manual confirmation supplies the light/dark and Dock/app-switcher outcomes. Screenshots are ignored local review artefacts in `.build/`, not committed acceptance assets.

Tighten retained local views and a separate optional icon exporter, kept normal builds to a checked-in asset, and replaced redundant drawing setup with an explicit clear of the bitmap. Probe exercised fresh compilation, actual native launch/lifecycle, accessible region names, resolved/Finder icon presentation and bundle contents. No blocker was found in the exercised paths. Bilal completed the remaining manual checks below. A31 stays Partially validated; selection-driven content and final production icon acceptance remain in later tasks. M1 is not complete.

## Bilal's manual checklist

No fixture or filesystem setup is required. [Build/run instructions](../../README.md#build-and-run) describe how to rebuild and launch the bundle. Quit it before rebuilding.

Bilal accepted the current result and explicitly confirmed all four remaining checks on 2026-10-04. These are Bilal's manual observations, separate from the agent checks above. Repeat native appearance/divider checks with the relevant UI tasks and the full icon/workflow checks at T18; A31 remains partial and final production icon acceptance remains pending.

- [x] Confirm that the window is visible. Bilal confirmed this on 2026-10-03.
- [x] Accept compact pane headers and the grouped far-right Details layout. Included in current-state acceptance on 2026-10-04.
- [x] Resize the window and drag its dividers; check readability. Bilal confirmed on 2026-10-04.
- [x] Close/reopen and quit/relaunch the app. Bilal confirmed on 2026-10-04.
- [x] Check light appearance and compare with dark appearance. Bilal confirmed on 2026-10-04.
- [x] Check the peeking-P icon in Finder, the Dock and the app switcher. Bilal confirmed on 2026-10-04.
- [x] Accept T01 Units 1–2. Bilal: “ok. approved the current state”, 2026-10-04.

T01 is `done` following Bilal's current-state acceptance. Commit, push, merge and the next coding task retain separate approval gates.

Bilal suggested a wider Details divider range for future consideration. This is recorded in [implementation notes](../notes/README.md#details-width-follow-up); no native change was made. Light tighten then probe on this evidence update preserved check provenance and the remaining acceptance limits. Documentation/whitespace checks passed; no rebuild was needed because source and assets are unchanged.
