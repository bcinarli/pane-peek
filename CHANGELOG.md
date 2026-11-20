# Changelog

## Unreleased

## [1.3.0] - 2026-11-20

### Added

- Open folders or select files through native macOS opening and the optional `panepeek` terminal command. Install or remove the command from the PanePeek menu; use `--reveal` to select an item in its parent.
- Use Command-F to search folders or find text in documents. Document Find works in rendered Markdown and HTML previews and their source editors.
- Copy a document’s complete source text from Preview or Edit, including unsaved changes.
- Highlight Python stubs (`.pyi`), windowed Python scripts (`.pyw`), `.gitmodules` and ripgrep/fd ignore files.
- Add basic shell highlighting for Korn shell scripts and `.bash_aliases`.
- Render `.markdown`, `.mdown`, `.mkd` and `.mkdn` files as Markdown.
- Highlight `.dockerignore` and Dockerfile-specific ignore files using Docker’s rules for comments and whitespace.
- Highlight `.env` and scoped `.env.<name>` files, keeping known extensions such as `.env.json` unchanged.
- Highlight Kotlin source and scripts (`.kt`, `.kts`).
- Highlight Ruby files, including `Gemfile`, `Rakefile`, `Podfile`, `Brewfile` and `Vagrantfile`.
- Highlight Objective-C and Objective-C++ files (`.m`, `.mm`); `.h` headers keep C-family highlighting.

### Changed

- Show the beta or release candidate label in About PanePeek for prerelease builds.
- Fit the Name column when a browser pane changes width while keeping chosen Size and Modified widths.
- Rank folder search matches by relevance and sort results independently of the folder listing.
- Reduce typing and pasting delays in large text files.
- Improve responsiveness when browsing and selecting files in large folders and search results.
- Stop cancelled folder searches promptly and end searches when they reach a search limit.

### Fixed

- Restore the last browser window’s folders and layout when reopening from the Dock.
- Remember each browser’s column widths when reopening the last window or relaunching the app.
- Scroll to the active document Find match, keep it visible when resizing Details and indicate when there are no matches.
- Use Restore Previous Width after dragging the expanded Details divider. If the saved width is at the maximum, Details returns to its compact width.
- Reduce CPU use when switching file previews.
- Keep hidden files hidden after Rename when a symbolic link was replaced outside PanePeek and the folder listing cannot refresh.
- Explain how Desktop, Documents and Downloads access supports file previews, editing and organisation in macOS permission prompts.

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
- Load folder listings faster.
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
- Copy absolute or relative file paths.
- Create and rename files and folders, copy or move selections between panes, move items to Trash and drag files to or from Finder, including Command-move.
- Copy and paste files, cut and paste between PanePeek panes or windows, use Move Item Here with Option-Command-V and send selections to Trash with Command-Delete.
- Resolve duplicate names with Keep Both or Cancel, plus Replace for regular files.
- Work in independent windows and restore the last active window's folders and layout when reopening the app.
- Use Catppuccin Macchiato colours in Dark appearance, including About and Preview controls.
- Open About PanePeek for the app description, selectable version/build and project links, with privacy and acknowledgement documents available offline.
