# PanePeek

A focused local file browser for macOS 26+, with independent directory panes and a Details sidebar for inspecting and editing text.

The application currently opens a native window with two empty pane areas, compact headers and a grouped Details sidebar. The bundle uses the accepted peeking-P artwork as its development icon. Directory browsing and file actions will be added in later approved tasks.

## Build and run

Requirements: macOS 26+, Swift 6.2 or later with a macOS SDK supporting the deployment target, and Node.js 22 or later. Command Line Tools are sufficient for the current shell; no third-party dependencies are required.

From the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

The script builds the debug executable and creates a local app bundle in `.build/PanePeek.app`, including the checked-in icon. Its minimum macOS version comes from `Package.swift`. Quit the running app before rebuilding it. Generated build files are ignored by Git.

The local development bundle runs outside the App Sandbox. Distribution signing and notarisation are deferred.

## Shell review

No fixture or filesystem access is needed for this task.

1. Launch the bundle and inspect the left/right pane areas and far-right Details sidebar.
2. Resize the window and its dividers; check that the regions remain readable.
3. Close the window, reopen the bundle, then quit with Command-Q and launch again.
4. Check both system light and dark appearance.
5. Check the peeking-P icon in Finder, the Dock and the app switcher.

There are no automated behaviour tests yet. Layout and packaging use build/launch checks; meaningful behaviour tests will be introduced with the relevant tasks. See the [validation record](agent-paper-trail/validation/checklist.md) for executed checks, current-state acceptance and remaining verification.

## Structure

- `Package.swift` owns the macOS deployment target and application executable.
- `Sources/PanePeek/` contains the SwiftUI app entry point and window layout. The current shell uses one window; independent windows belong to a later task.
- `scripts/build-app.mjs` builds and bundles the app using Swift and Node's built-in libraries.
- `Assets/PanePeek.icns` is the development icon derived from the accepted SVG composition. To regenerate it, run `node scripts/export-app-icon.mjs`; this uses built-in macOS Quick Look, Swift/AppKit, `sips` and `iconutil`, with intermediate files in `.build/app-icon/`. The exporter preserves the SVG geometry and adds transparent margins and a rounded background. Final icon refinement and small-size acceptance remain in T18.

The testable core and its tests will grow with actual filesystem/document behaviour rather than empty scaffolding.

## Project context

- [Project paper trail](agent-paper-trail/README.md)
- [MVP specification](agent-paper-trail/specs/001-mvp/spec.md)
- [Implementation plan](agent-paper-trail/specs/001-mvp/plan.md)
- [Task tracker](agent-paper-trail/specs/001-mvp/tasks.md)
- [Accepted draft UI and logo](agent-paper-trail/design/001-mvp/README.md)
