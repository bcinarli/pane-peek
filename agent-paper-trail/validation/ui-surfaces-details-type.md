# Content surfaces and Details typography validation

Status: accepted. Bilal confirmed the distinct native surface shades and Details typography/path layout on 2026-10-09. Individual light-appearance and whole-window resizing results were not separately reported.

## Change

The draft's chrome/paper relationship now uses two native macOS roles. Breadcrumb headers and Details use [`underPageBackgroundColor`](https://developer.apple.com/documentation/appkit/nscolor/underpagebackgroundcolor); lists, column headings and the inset preview area use [`textBackgroundColor`](https://developer.apple.com/documentation/appkit/nscolor/textbackgroundcolor). The native toolbar keeps its system presentation. [`scrollContentBackground(.hidden)`](https://developer.apple.com/documentation/swiftui/view/scrollcontentbackground(_:)) exposes the list's paper surface while preserving native rows and selection.

Window and text background roles resolved to the same shade on the observed OS. The under-page role provides the required separation: native colour inspection returned approximately `#282828` chrome / `#1E1E1E` paper in dark appearance, and `#F6F6F6` / white in light. These are observed system values, not hard-coded app colours or a promise of exact draft RGB matching.

Details uses an 11-point muted title/section labels, a 13-point medium filename above the preview card, and an 11-point monospaced path with wrapping. The 236-point preview placeholder has a native separator border and seven-point corners. Its message is 12-point system text. File information is separated below the path, following the draft's hierarchy. Preview/metadata functionality remains in T05/T06; this unit changes existing presentation only.

## Executed checks

Same OS/toolchain as the [icon/accent unit](ui-icons-accent.md#executed-checks).

- Build/package, Info.plist lint and whitespace checks pass. Existing Command Line Tools search-path warnings remain.
- The corrected build launches after the documented [generated-executable recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery). The previous generated executable is preserved; no signing or global setting was changed.
- Dark screenshots show distinct headers/Details and list/preview surfaces, with native Mauve selected rows and the existing focus underline. Dividers remain below the toolbar.
- At the 280-point Details minimum, a long filename stays readable and the full path wraps without clipping. Copying that path and pasting into a cancelled Go to Folder sheet confirms the full displayed value.
- Escape clears the selection, filename and path/copy action. The empty preview message remains visible. Independent right-pane navigation and selection update Details; the sidebar was restored to 300 points for review.
- Native colour roles were inspected in both appearances without changing system settings. This verifies role values, not the complete light UI.

No new or rerun automated behaviour tests for this styling unit, following the [plan](../specs/001-mvp/plan.md#task-workflow-and-exit-gates). Standard tighten kept two shared colour roles and direct native text styling. Standard probe checked shade separation, native selection and narrow-sidebar text/copy behaviour. Light appearance and whole-window resizing remain manual.

## Manual review

The rebuilt app is running with validation files on the left and scripts on the right, selecting `build-app.mjs`.

- [ ] Compare the header/Details shade against the list/preview shade in light and dark appearance, including selection/focus contrast.
- [ ] Review Details font sizes and spacing. Narrow the sidebar/window and confirm long names/paths remain readable and copyable.

Bilal accepted both presented changes: the surface shade separation, and smaller labels/medium-weight filename/wrapping monospaced path. The checklist above retains individually unreported checks. Bilal authorised commit on 2026-10-09; push remains separately gated.
