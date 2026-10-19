---
task: favourites-menu-labels
verdict: Passed
closed: "2026-10-19"
---

# Favourites menu labels

Scope: folder-name labels in the menu-bar Open and Remove Favourite entries, with distinguishing parent context only for duplicate names. Existing order, persistence and actions are retained. Presented scope accepted overall on 2026-10-19. Individual unreported accessibility checks remain explicit below.

## Automated checks, 2026-10-19

- Red: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer node scripts/test.mjs --filter FavouriteMenuItemsTests` compiled and failed all five new functions with six expected label assertions against full-path output. Green: the five label functions and seven existing favourites, guarded-navigation and shared-window functions pass with `--filter 'FavouriteMenuItemsTests|FavouritesTests|EditorTests/deferredFavourite|WindowCreationTests'`.
- `node scripts/build-app.mjs` packages successfully using Xcode's Swift 6.4 SDK/toolchain on macOS 27.0.1 arm64. No build/test warnings on the final runs. Review executable/catalog bytes match the package; review plist, 454 local Markdown links/anchors and whitespace checks pass. No full-suite or macOS 26 execution claim.

## Native review

- Agent-observed in an isolated app/settings domain: both menu sections expose matching compact labels for root, unique/Unicode names, duplicate Projects and deeper duplicate Notes parents. Open reaches the intended directory and targets a newly focused right pane while retaining the left location.
- Keyboard submenu navigation/Return removes the current Work favourite without navigating; Personal immediately becomes `Projects` in both sections. Re-adding through the current-directory star restores both qualifiers and appends the saved entry. Unavailable-path removal persists without navigating; the disposable fixture text remains unchanged.
- Full-path help and accessibility modifiers are present, but the automation snapshot reports menu titles only. Actual tooltip/VoiceOver output, complete keyboard-only access, Light appearance, enlargement and increased-contrast settings remain manual. Menu screenshots were unavailable; native titles/actions were observed through accessibility, with overall visual acceptance recorded on 2026-10-19.

## Reproduce

Build and run using the [contributor instructions](../../../../CONTRIBUTING.md#build-and-run). In a disposable settings domain, save `Work/Projects`, `Personal/Projects`, `Company/Shared/Notes`, `Private/Shared/Notes`, a unique Unicode name and `/`; an unavailable saved path needs no corresponding directory. Check both menu sections, open each duplicate, remove one and confirm the survivor loses its qualifier. Check full-path help/VoiceOver and keyboard access separately. The existing toolbar popover retains full paths and search.

Standard tighten followed by standard probe retained one app-local formatter and the existing store/actions. Root, shared parent suffixes, unavailable paths and duplicate removal are covered; manual/accessibility limits above remain open.
