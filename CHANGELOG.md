# Changelog

User-visible changes to the macOS app are collected here before release. GitHub Release notes reuse the corresponding dated entry. Release headings use `## [X.Y.Z] - YYYY-MM-DD` with the actual publication date.

## Unreleased

### Fixed

- Request containing-folder access when moving files to Trash is denied, then safely retry the remaining selection.

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
