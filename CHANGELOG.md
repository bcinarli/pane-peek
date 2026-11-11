# Changelog

User-visible changes to the macOS app are collected here before release. GitHub Release notes reuse the corresponding dated entry. Release headings use `## [X.Y.Z] - YYYY-MM-DD` with the actual publication date.

## Unreleased

### Added

- Use Command-F for folder search or native document Find, including rendered Markdown and HTML previews and their source editors.
- Copy a document’s complete source text from Preview or Edit, including unsaved changes.
- Highlight Python stubs (`.pyi`, `.pyw`), Korn shell scripts, `.bash_aliases`, `.gitmodules` and ripgrep/fd ignore files, and render `.markdown`, `.mdown`, `.mkd` and `.mkdn` files as Markdown.
- Highlight `.dockerignore` and Dockerfile-specific ignore files with Docker’s comment and whitespace rules.

### Changed

- Show the beta or release candidate label in About PanePeek.
- Fit the Name column when a browser pane changes width while keeping chosen Size and Modified widths.
- Rank folder search matches by relevance and sort results independently of the folder listing.
- Reduce typing and pasting delays in large text files while preserving line numbering and native editing behaviour.
- Improve responsiveness when browsing and selecting files in large folders and search results.
- Stop cancelled folder searches promptly and enforce search limits while reading directory entries.

### Fixed

- Restore the last browser window’s folders and layout when reopening from the Dock.
- Remember each browser’s column widths when reopening the last window or relaunching the app.
- Scroll to the active document Find match, keep it visible when resizing Details and indicate when there are no matches.
- Reduce CPU use when switching file previews.
- Keep filesystem-hidden files hidden after Rename when a listed symbolic link was replaced externally and the folder cannot refresh.
- Explain how Desktop, Documents and Downloads access supports file previews, editing and organisation in macOS permission prompts.

### Performance in 1.3.0-beta.2 compared with 1.2.0

| Measurement | 1.2.0 | 1.3.0-beta.2 | Change |
| --- | ---: | ---: | ---: |
| Read a folder with 10,000 files | 492 ms | 496 ms | Similar |
| Search 10,000 file names, 100 matches | 693 ms | 703 ms | Similar (+1.5%) |
| Pane-switch cycle with 10,000 files | 3.16 ms | 1.59 ms | 49.6% less time |
| Edit a large text file | 8.60 s | 5.72 s | 33.5% less time |
| CPU time during the editing test | 8.58 s | 5.70 s | 33.6% less CPU time |
| Peak RAM during the editing test | 104.7 MiB | 100.0 MiB | 4.4% lower |
| Idle app CPU | <0.2% of one core | <0.2% of one core | Similar |
| Idle app RAM | 96.8 MiB | 97.1 MiB | 0.4% higher |
| Unpacked app bundle | 7.62 MiB | 7.88 MiB | 3.4% larger |

Runtime figures are medians of three runs with arm64 release builds on an Apple M5 Mac with 32 GB RAM and macOS 27.0.1. Folder, search and pane-switch timings measure the browser core. The search test covers 100 subfolders and includes the 150 ms pause after typing and each build’s default result ordering. The editing test makes 60 insertions in a 1 MB text file. Idle measurements cover the app process with an empty browser window. RAM figures use resident memory (RSS).

## [1.2.0] - 2026-10-26

### Added

- Check for updates in GitHub builds, download a DMG for manual installation and opt into daily update reminders.
- Resize file-list columns with draggable dividers or Column Widths controls, including Restore Defaults.
- Search file and folder names beneath the active folder from an expandable toolbar control, with relative result paths and Open Containing Folder.
- Navigate Back and Forward through each browser’s folder history from the toolbar or Go menu.
- Show logical line numbers when editing text and code in Details.
- Collapse File information to give previews and editing more height, with its state remembered across windows and relaunches.
- Duplicate selected items in their containing folder from the item menu.

### Changed

- Allow Details up to 66% of the content width in One Pane, retaining 50% in Two Panes.
- Start fresh windows with one pane and expanded Details while restoring the saved layout when reopening.
- Reduce repeated metadata checks when loading folder listings.
- Group item-menu actions by item editing, path copying, pane transfers and Trash.

### Fixed

- Keep the editor viewport stable while typing and saving.
- Prevent syntax highlighting from flashing while typing.
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
