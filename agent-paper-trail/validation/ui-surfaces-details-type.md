> Historical detail and fixtures. Current verdict: [Content surfaces and Details typography validation](../specs/001-mvp/evidence/surfaces-details-type.md). Earlier publication/checkpoint statements below are historical.

Status: Archived

# Content surfaces and Details typography validation

Status: accepted. Bilal accepted the earlier native surface shades and Details typography/path layout on 2026-10-09, then authorised Apple-guided typography. Bilal confirmed text enlargement, contrast and VoiceOver checks passed and accepted the remaining manual review checks.

## Change

The draft's chrome/paper relationship now uses two native macOS roles. Breadcrumb headers and Details use [`underPageBackgroundColor`](https://developer.apple.com/documentation/appkit/nscolor/underpagebackgroundcolor); lists, column headings and the inset preview area use [`textBackgroundColor`](https://developer.apple.com/documentation/appkit/nscolor/textbackgroundcolor). The native toolbar keeps its system presentation. [`scrollContentBackground(.hidden)`](https://developer.apple.com/documentation/swiftui/view/scrollcontentbackground(_:)) exposes the list's paper surface while preserving native rows and selection.

Window and text background roles resolved to the same shade on the observed OS. The under-page role provides the required separation: native colour inspection returned approximately `#282828` chrome / `#1E1E1E` paper in dark appearance, and `#F6F6F6` / white in light. These are observed system values, not hard-coded app colours or a promise of exact draft RGB matching.

The earlier accepted Details presentation used 11-point muted title/section labels, a 13-point medium filename above the preview card, and an 11-point monospaced path with wrapping. The 236-point preview placeholder has a native separator border and seven-point corners. Its message used 12-point system text. File information is separated below the path, following the draft's hierarchy. Preview/metadata functionality remains in T05/T06; this unit changes existing presentation only.

## Executed checks

Same OS/toolchain as the [icon/accent unit](ui-icons-accent.md#executed-checks).

- Build/package, Info.plist lint and whitespace checks pass. Existing Command Line Tools search-path warnings remain.
- The corrected build launches after the documented [generated-executable recovery](../notes/0001-build-and-bundle.md#rebuilt-executable-recovery). The previous generated executable is preserved; no signing or global setting was changed.
- Dark screenshots show distinct headers/Details and list/preview surfaces, with native Mauve selected rows and the existing focus underline. Dividers remain below the toolbar.
- At the 280-point Details minimum, a long filename stays readable and the full path wraps without clipping. Copying that path and pasting into a cancelled Go to Folder sheet confirms the full displayed value.
- Escape clears the selection, filename and path/copy action. The empty preview message remains visible. Independent right-pane navigation and selection update Details; the sidebar was restored to 300 points for review.
- Native colour roles were inspected in both appearances without changing system settings. This verifies role values, not the complete light UI.

No new or rerun automated behaviour tests for this styling unit, following the [plan](../specs/001-mvp/plan.md#task-workflow-and-exit-gates). Standard tighten kept two shared colour roles and direct native text styling. Standard probe checked shade separation, native selection and narrow-sidebar text/copy behaviour. Light appearance and whole-window resizing were left for Bilal's manual review.

## Manual review

The rebuilt app is running with validation files on the left and scripts on the right, selecting `build-app.mjs`.

- [x] Compare the header/Details shade against the list/preview shade in light and dark appearance, including selection/focus contrast.
- [x] Review Details font sizes and spacing. Narrow the sidebar/window and confirm long names/paths remain readable and copyable.

Bilal accepted both presented changes: the surface shade separation, and smaller labels/medium-weight filename/wrapping monospaced path. Bilal subsequently confirmed the remaining checks were reviewed and working OK. Commit and push of the implementation were authorised on 2026-10-09.

## Apple typography follow-up

[Changed, 2026-10-09] Bilal requested Apple-guided typography and established the [app-wide accessibility baseline](../specs/001-mvp/spec.md#accessibility-baseline). Details now uses native `subheadline` for labels/path, `body` with medium weight for the filename, and `callout` for the preview message. The path retains monospaced rendering. Other app font declarations already use semantic styles.

This replaces the five fixed point-size declarations. It does not establish native text enlargement or completion of the wider accessibility baseline. Verify the actual macOS resizing mechanism under WCAG2ICT before selecting any app-provided fallback. The existing wrapping, scroll surfaces, widths and actions are retained.

Follow-up build/package, Info.plist lint and whitespace checks pass in the environment recorded above. The generated executable was preserved using the documented recovery before rebuilding; the new bundle launches successfully. Existing compiler search-path warnings remain.

Native dark review confirms the filename, labels and monospaced path remain readable at the 280-point Details minimum. Copying the long path and pasting into a cancelled Go to Folder sheet preserves the full value. Escape clears the filename/path/copy action. Independent right-pane navigation/selection updates Details; its width is restored to 300 points. No new or rerun automated behaviour tests for this font-style unit.

Light tighten kept direct native styles without a typography wrapper. Light probe verified the build, long-path layout and copy/selection seam; enlargement, VoiceOver and contrast awaited Bilal's review at that point. Documentation uses the internal-doc writing preset. No system accessibility or appearance settings were changed by the agent.

Use the [build/run instructions](../../README.md#build-and-run); the rebuilt app is running. No filesystem mutation or fixture is needed for this review.

- [x] Accept the semantic-font hierarchy in light/dark appearance and with narrow panes/windows; confirm long filenames/paths remain readable and copyable.
- [x] Check text enlargement. Bilal confirmed it looks good on 2026-10-09.
- [x] Check contrast. Bilal confirmed it looks good on 2026-10-09.
- [x] Check VoiceOver. Bilal confirmed it looks good on 2026-10-09.

Bilal reiterated that these checks were performed. These are manual results for the current UI. The resizing mechanism/percentage, measured contrast ratios and individual VoiceOver scenarios were not supplied; the complete app-wide accessibility review remains in T18.

[Accepted, 2026-10-09] Bilal confirmed the remaining manual review checks were reviewed and working OK, and requested `done` status. This accepts the semantic-font follow-up and completes this unit's manual review. The app-wide T18 accessibility review remains separate.

Bilal authorised commit and push of the implementation on 2026-10-09, then authorised commit, push and merge of the review-evidence updates.
