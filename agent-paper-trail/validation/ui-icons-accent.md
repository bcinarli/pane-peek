# UI icons and app accent validation

Status: accepted. Bilal authorised continuation after reviewing this submission, then confirmed the remaining manual review checks work OK on 2026-10-09.

## Change

The native toolbar, Home/favourite controls, normal file/folder rows and Details copy button use the draft's pinned Lucide SVG paths. They retain native controls and their existing actions/accessibility labels. Template rendering provides normal selected/unselected tinting; the saved star uses the same path with a fill. Package and link rows keep their distinct SF Symbols. [Asset sources and licence](../../assets/README.md) document provenance.

A named light/dark Mauve colour replaces the duplicated RGB expression. The bundle compiles the asset catalog and sets [`NSAccentColorName`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaccentcolorname), making it the app's native accent. Under macOS's Multicolor setting, native selection uses the app accent; an explicit system accent takes precedence, following [Apple's colour guidance](https://developer.apple.com/design/human-interface-guidelines/color). Native selection geometry and contrast handling still belong to macOS.

## Executed checks

Environment: macOS 27.0.1 (26A434), Swift 6.4 with macOS SDK 27, deployment target 26.0. The selected Swift toolchain remains Command Line Tools; asset compilation uses the installed full Xcode through a scoped environment. No macOS 26 runtime check is claimed.

- `node scripts/build-app.mjs` builds/packages successfully, including `Assets.car` and the full icon licence. Existing Command Line Tools search-path warnings remain. Info.plist lint passes and its accent key resolves to `accent`; the bundled licence matches its source. Script syntax and whitespace checks pass.
- The rebuilt app launches. Dark screenshots show all eight template images, including the filled saved star, with no missing-image placeholders. Normal file rows have the draft's text-document glyph; selected glyphs/text remain legible.
- Native focused selection is Mauve. Home, focus underline, saved star and copy icon also show the dark accent. The selection fill is macOS's rendering of that accent, rather than a custom copy of the draft's muted rounded row.
- Toolbar Go to Folder opens the native sheet; cancellation retains the selected item. Command-L navigates the right pane independently. Favourites and Directory actions open their existing menus. Favourite toggling retains selection and updates the menu; the temporary saved project directory was removed after the check, restoring its original state.
- Command-click multi-selection and Down-arrow movement still update selection and Details. The copy button retains its accessible label/help and existing handler.

No automated behaviour tests were added or rerun for this presentation/resource unit, following the [plan](../specs/001-mvp/plan.md#task-workflow-and-exit-gates). Existing navigation/selection/favourites logic is unchanged.

Standard tighten kept direct native labels and one colour asset, without an icon-loading wrapper or duplicate palette. Standard probe checked the bundle resource seam and selected template rendering, then exercised native controls. Light appearance and explicit system-accent override were left for Bilal's manual review. No system appearance/accent setting was changed by the agent.

## Manual review

The rebuilt app is running with the project directory on the left and scripts on the right.

- [x] Confirm toolbar, Home/favourite, row and copy icon size/stroke look right in light and dark appearance. Check the filled saved star and normal hover/menu-open feedback.
- [x] With Multicolor selected in macOS, confirm Mauve native selection and focus indicators in both appearances, including inactive selection. If an explicit system accent is already configured, confirm native selection follows it while the existing app indicators retain Mauve.

Bilal authorised commit on 2026-10-09. The implementation was subsequently pushed with separate approval.

[Accepted, 2026-10-09] Bilal confirmed the remaining manual review checks were reviewed and working OK, and requested `done` status. The system-accent check retains its conditional scope.
