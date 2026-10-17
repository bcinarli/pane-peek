---
task: linker-warning-cleanup
verdict: Passed
closed: "2026-10-17"
---

# Evidence: linker-warning cleanup

- 2026-10-17: After accepting and authorising the source-warning commit, Bilal approved fixing the three remaining linker warnings without suppression. This packaging unit followed separate manual, commit and publication gates.
- Environment: macOS 27.0.1 (26A434), Swift 6.4, Node 26.1.0, with Command Line Tools selected globally. The deployment minimum remains macOS 26; no macOS 26 runtime check is claimed.

## Implementation and checks

The bundler resolves its environment before compiling and shares it across Swift build, binary-path lookup, package inspection and asset compilation. `xcrun` resolves each tool in that environment. Explicit `DEVELOPER_DIR` wins; with no override and global Command Line Tools selection, the existing standard-Xcode fallback now applies to the whole build. No linker diagnostic flags, filtering or synthetic search directories are added. README and build notes describe this behaviour.

- Before: the accepted source-warning unit's normal build reports three missing Command Line Tools `Developer` search paths. A full-Xcode comparison removes all three without suppression.
- Normal `node scripts/build-app.mjs` passes without warnings or errors. A fresh isolated source copy, with no build products copied and `DEVELOPER_DIR` unset, also builds and packages without warnings or errors. The raw combined build output is inspected; it is not filtered by the bundler.
- Explicit full-Xcode override also builds/packages with zero warnings or errors. An invalid explicit override fails with exit 1 before replacing the existing bundle, confirming it is honoured rather than silently ignored. Global selection is still Command Line Tools after the checks.
- The bundle retains macOS 26.0 as its deployment minimum. Normal/review executable bytes match the accepted source-unit executable. JavaScript syntax, plist, diff and new task-link checks pass. Packaging validation uses actual tools/builds; no artificial unit tests or new app behaviour are claimed.
- An isolated review bundle was prepared with its own preferences and the existing disposable fixtures. The process is confirmed running, but the native UI tool timed out during capture. No fresh visual, keyboard, Save or VoiceOver pass is claimed for this packaging unit; those observations remain pending manual review.
- Standard tighten moves the existing fallback to one shared environment without adding a helper framework. Standard probe checks fresh linking, explicit override success/failure, unchanged global selection, binary-path/manifest consistency, deployment metadata and bundle identity. No suppression or empty search-path directories are introduced.
- 2026-10-17: Bilal accepted the presented unit overall and authorised its commit, a PR containing both warning fixes and merge. The native capture limitation remains recorded above; individual unreported UI/accessibility outcomes are not inferred from overall acceptance.
- Implementation commit: [`28f5d08`](https://github.com/bcinarli/pane-peek/commit/28f5d08dd1050c390460e8235653d034c291f258) (Use one Xcode toolchain throughout app bundling). Closing publication: [PR #35](https://github.com/bcinarli/pane-peek/pull/35), targeting `main`, alongside the source corrections.

## Run and manual review

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

Check the terminal output and launch the resulting app. Recheck icons, text preview, Space/Escape and Save using disposable fixtures. No control/layout changes are intended; app-wide VoiceOver/settings acceptance remains T18.
