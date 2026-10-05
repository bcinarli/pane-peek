# PanePeek

A focused local file browser for macOS 26+, with independent directory panes and a Details sidebar for inspecting and editing text.

The application lists directories in two independent panes beside Details. Navigate with Home, directory double-click or Return, Go to Folder/Command-L, and the shared folder chooser or Enclosing Folder action (Command-Up). Failed navigation keeps the previous directory usable. Breadcrumbs, sorting controls, file actions and Details content remain in later units/tasks. The bundle uses the accepted peeking-P development icon.

## Build and run

Requirements: macOS 26+, Swift 6.2 or later with a macOS SDK supporting the deployment target, and Node.js 22 or later. Command Line Tools are sufficient for the current shell; no third-party dependencies are required.

From the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

The script builds the debug executable and creates a local app bundle in `.build/PanePeek.app`, including the checked-in icon. Its minimum macOS version comes from `Package.swift`. Quit the running app before rebuilding it. Generated build files are ignored by Git.

The local development bundle runs outside the App Sandbox. Distribution signing and notarisation are deferred.

## Tests

Run the browsing behaviour suite:

```sh
node scripts/test.mjs --filter DirectoryBrowsingTests
```

The runner uses `swift test`, adding the installed Testing macro search directory when available. Tests use isolated temporary directories; completion-order tests use controlled asynchronous reads. They do not mutate working files or preferences.

## Browsing review

[T02 Unit 1 evidence](agent-paper-trail/validation/t02-directory-browsing.md) includes disposable fixture setup, executed checks and the pending manual checklist. Use different directories in each pane, switch focus without selecting a row, and try missing/regular-file paths. Check Home, parent navigation, empty directories and native appearance/resizing. The thin Mauve underline identifies the pane targeted by shared actions.

[T01 evidence](agent-paper-trail/validation/t01-launchable-shell.md) retains the accepted shell/icon checks. Task acceptance and remaining criteria live in the [validation checklist](agent-paper-trail/validation/checklist.md).

## Structure

- `Package.swift` owns the macOS deployment target and application executable.
- `sources/panepeek/` contains the SwiftUI app entry point, native navigation controls and window layout. Independent windows belong to a later task.
- `sources/panepeek-core/` contains asynchronous directory listing and per-pane/window browsing state.
- `tests/panepeek-core/` contains the meaningful browsing behaviour tests.
- `scripts/build-app.mjs` builds and bundles the app using Swift and Node's built-in libraries.
- `assets/PanePeek.icns` is the development icon derived from the accepted SVG composition. To regenerate it, run `node scripts/export-app-icon.mjs`; this uses built-in macOS Quick Look, Swift/AppKit, `sips` and `iconutil`, with intermediate files in `.build/app-icon/`. The exporter preserves the SVG geometry and adds transparent margins and a rounded background. Final icon refinement and small-size acceptance remain in T18.

Swift target/module names keep their normal capitalisation. Explicit package paths allow lowercase source/test directories. The platform requires `Contents`, `MacOS` and `Resources` inside the app bundle.

## Project context

- [Project paper trail](agent-paper-trail/README.md)
- [MVP specification](agent-paper-trail/specs/001-mvp/spec.md)
- [Implementation plan](agent-paper-trail/specs/001-mvp/plan.md)
- [Task tracker](agent-paper-trail/specs/001-mvp/tasks.md)
- [Accepted draft UI and logo](agent-paper-trail/design/001-mvp/README.md)
