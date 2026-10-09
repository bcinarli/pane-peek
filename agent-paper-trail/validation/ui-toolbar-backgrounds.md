# Toolbar background revision validation

Status: accepted. Bilal confirmed all manual checks with "all works" on 2026-10-09 and authorised committing this unit. Push remains separately gated.

## Scope and result

Remove persistent shared glass backgrounds from Go to Folder, Favourites and Directory actions using the public macOS 26 [ToolbarContent.sharedBackgroundVisibility](https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:)) API. Each existing control is placed in a ToolbarItem with hidden shared background. Native transient interaction highlights remain visible when a menu opens.

Labels, accessibility/help, Command-L, menu contents and handlers retain their existing implementation. This presentation unit adds no automated behaviour or fixtures. Divider treatment, icons, accent assets, surfaces and Details typography require later unit approvals.

## Executed checks

Environment: macOS 27.0.1 (26A434), Apple Swift 6.4, macOS SDK 27.0 and Node 26.1.0 on Apple Silicon. Deployment minimum remains macOS 26; no macOS 26 run is claimed.

| Check | Result |
| --- | --- |
| Branch/dependencies | Local and live remote main agree at `8dcbe45`, including accepted T15. Created `bcinarli/ui-toolbar-backgrounds` from clean main. |
| Build/package | `node scripts/build-app.mjs` passes with normal compiler-cache access. The initial sandboxed attempt failed on cache permissions, not changed code. Existing CLT linker search-path warnings remain non-fatal. |
| Bundle/whitespace | `plutil -lint .build/PanePeek.app/Contents/Info.plist` and `git diff --check` pass. |
| Native launch | Rebuilt bundle launches and remains running for review. |
| Dark appearance | All three controls have no persistent background while idle. Both menus were visually inspected open: native transient highlights remain, with no widened outer wrapper. |
| Control integration | Go to Folder click and Command-L open path entry. Navigating each focused pane leaves its neighbour in place. Cancel retains both directories. Favourites exposes existing entries; Directory actions exposes existing commands. Activated Refresh, observing menu dismissal and the retained listing. Accessible labels/help remain present. |

No new tests or full suite rerun for this UI-only unit, following the [plan's validation rule](../specs/001-mvp/plan.md#task-workflow-and-exit-gates). Separate hover-only, light appearance and narrow-layout checks remain manual. The prior T15 behaviour results remain in their own evidence record.

## Review passes

Standard tighten kept the toolbar modifier local to the three existing controls. No helper, forced width, custom button style or AppKit inspection was added. Light probe checked the real build, idle/menu-open rendering, labels, shortcut and path-entry integration. No correctness blocker was found in those checks. Appearance acceptance remains pending.

## Reproduce and review

Quit PanePeek before rebuilding, then run from the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

No disposable fixture is needed. Use any existing directories for navigation; this review requires no filesystem mutation or favourite changes.

- [x] Check idle, hover and menu-open appearance in dark and light modes. Confirm bare idle icons and acceptable native transient feedback.
- [x] Open both menus, use Go to Folder and Command-L, and cancel path entry. Confirm normal interaction and focused-pane targeting.
- [x] Narrow the window and confirm all three toolbar controls remain usable.

Bilal accepted this unit and explicitly authorised the divider unit on 2026-10-09. Agent-only light/hover/narrow checks remain unclaimed; their acceptance is Bilal's manual report.
