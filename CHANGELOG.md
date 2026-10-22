# Changelog

User-visible changes to the macOS app are collected here before release. GitHub Release notes reuse the corresponding dated entry. Release headings use `## [X.Y.Z] - YYYY-MM-DD` with the actual publication date.

## Unreleased

### Added

- Duplicate selected items in their containing folder from the item menu.

### Changed

- Allow Details up to 66% of the content width in One Pane, retaining 50% in Two Panes.
- Start fresh windows with one pane and expanded Details while restoring the saved layout when reopening.
- Reduce repeated metadata checks when loading folder listings.
- Group item-menu actions by item editing, path copying, pane transfers and Trash.

### Fixed

- Copy and paste items into their own folder using unused numbered names.
- Restore window dragging and the system double-click action across title text and empty title-bar space.
- Fix navigation to the filesystem root with remembered folder access.

## [1.1.0] - 2026-10-21

### Added

- Show Markdown YAML front matter as highlighted code above the rendered document.
- Preview SVG artwork and edit its XML source in Details.
- Preview PDF pages in Details with scrolling, zoom and Fit Width.
- Preview HTML pages with local styles, images and fonts while editing their source in Details.

### Changed

- Markdown previews open HTTP/HTTPS links; other link targets appear as plain text.
- Grant folder access through the native folder picker, with approved folders and favourites remembered between launches.
- Upgrading from 1.0.0 may require selecting folders and re-adding favourites.

### Fixed

- Retain text Undo history after saving and refreshing file information.

## [1.0.0] - 2026-10-20

### Added

- Browse folders in one or two independent panes, with sorting and hidden-file visibility.
- Search shared favourites by folder name or path, with parent context for repeated folder names.
- Preview Markdown, images and local videos beside file information; open saved files in native Quick Look.
- Edit UTF-8 text inline with syntax highlighting and explicit Save. Consistent Save, Discard and Cancel prompts protect unsaved changes.
- Preview and edit TypeScript `.ts` and `.mts` files as highlighted text.
- Copy absolute or relative file paths for sharing with AI agents and other applications.
- Create and rename files and folders, copy or move selections between panes, move items to Trash and drag files to or from Finder, including Command-move.
- Copy and paste files, cut and paste between PanePeek panes or windows, use Move Item Here with Option-Command-V and send selections to Trash with Command-Delete.
- Resolve duplicate names with Keep Both or Cancel, plus Replace for regular files.
- Work in independent windows and restore the last active window's folders and layout when reopening the app.
- Use Catppuccin Macchiato colours in Dark appearance, including About and Preview controls.
- Open About PanePeek for the app description, selectable version/build and project links, with privacy and acknowledgement documents available offline.
