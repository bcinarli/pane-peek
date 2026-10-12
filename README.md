# PanePeek

A focused local file browser for macOS 26+, with independent directory panes and a Details sidebar for inspecting and editing text.

The application lists directories in one or two independent panes beside Details. One Pane / Two Panes in the toolbar and View menu keep the active browser visible while preserving the other browser's directory, selection, settings and scroll position. Returning to Two Panes keeps the current browser on the left and restores the other on the right. Layout changes retain the current editor and do not prompt about unsaved changes. Navigate with Home, root/ancestor breadcrumbs, directory double-click or Command-Down, Go to Folder/Command-L, and the shared folder chooser or Enclosing Folder action (Command-Up). Long breadcrumbs scroll horizontally; directory links follow their canonical target. Click each pane's Name or Modified heading to sort; click again to reverse. Name keeps folders first; Modified sorts folders and files together by date. URL selections stay intact through reordering. Command-click toggles rows, Shift-click selects a range, and Edit → Select All (Command-A) selects visible rows. Escape cancels an inline rename, or clears the focused listing when no name is being edited. Details shows the primary selected name and full absolute path, with an adjacent copy action. Rows show relative recent dates or exact older dates, with complete timestamps in help/accessibility, and distinguish packages/links. Directory actions and the View menu offer Show Hidden Files (Command-Shift-period) and Refresh (Command-R) for the focused pane. Visibility and sorting survive navigation and Refresh. Failed reads keep the previous directory usable. Transfers and Trash remain in later tasks. The bundle uses the accepted peeking-P development icon.

Details reads creation/modified dates, Unix permissions, owner/group, type and available byte size for the focused pane's primary item. Unavailable fields are explicit; folders and packages have no aggregate size. Links show their own metadata and stored target path separately, including broken links. Selection changes and successful Refresh reload metadata; failed reads clear previous values and show an error. Metadata remains visible while content preview is unavailable.

Resize the whole Details column with its divider. Expand/Restore in the Details header and View menu requests half the content width, subject to the visible browsers' minimum widths, then returns to the previous preferred width. Narrow windows temporarily clamp that preference. View → Make Details Wider/Narrower adjusts the visible width in 10-point steps (Control-Command-Left/Right). Entering Edit keeps the chosen width. Preview/Edit fills the height left after other Details content; short windows and long metadata remain scrollable.

Above metadata, Details previews UTF-8 text with or without a BOM, up to 1 MiB including the BOM. Text is selectable, copyable and read-only. Empty files, NUL-containing binary files, invalid UTF-8, oversized files, folders/packages and read errors have explicit states. File links can preview regular text targets while retaining their listed path and own metadata. Refresh rereads the selected file, including when its size and timestamp have not changed. The preview uses installed Operator Mono Lig, then JetBrains Mono, then the system monospaced font. Fonts are optional and are not bundled. Swift, JSON, YAML/YML, TOML, JavaScript/TypeScript, HTML/XML, JSX/TSX, CSS/SCSS, PHP, Go, Rust, Java, Python, Markdown, Shell/Bash/Zsh, SQL, C/C++, C#, Dockerfile and Makefile previews have lexical highlighting with light/dark colours. JavaScript includes `.js`/`.mjs`/`.cjs`; TypeScript includes `.ts`/`.mts`/`.cts`; HTML includes `.html`/`.htm`. Markup remains source text; HTML script/style bodies stay plain. JSX/TSX distinguish tags, attributes and embedded code expressions while preserving plain child text and literal entities. CSS/SCSS colour selectors, properties, values and comments; SCSS also colours variables and directives. PHP highlights standard blocks, variables, strings and comments; surrounding markup and configuration-dependent `<?` tags stay plain. Go colours keywords, quoted/raw strings, runes, comments and numeric forms. Rust adds `.rs` keywords, strings/characters, lifetimes, nested comments and numbers. Java adds `.java` keywords, strings/characters, text blocks, comments and numbers, retaining original Unicode escapes in the displayed source. Python adds `.py` keywords, quoted/raw/byte/triple/formatted/template strings, comments and numbers. Markdown `.md` colours headings, emphasis, links and inline/fenced code while retaining source text. Shell colours reserved words, quoted strings, comments, parameters and heredocs in `.sh`/`.bash`/`.zsh` and common startup files such as `.bashrc` and `.zshrc`. SQL `.sql` colours keywords, quoted strings/identifiers, parameters and nested comments, including PostgreSQL dollar strings. C/C++ source/header files colour keywords, strings/raw strings, comments and preprocessor directives. C# `.cs` adds keywords, quoted/verbatim/interpolated/raw strings, characters and comments. Dockerfile, Dockerfile.* and .dockerfile variants colour instructions, quoted values, variables, line comments and heredocs. Makefile variants colour targets, assignment names, directives, references, quoted values, comments and literal define bodies. Indented `.sass` stays plain. Other extensions stay plain. Preview/Edit now shares this highlighting pipeline. T07 keeps edits in memory until explicit Save, shows Unsaved, and offers Save/Discard/Cancel before replacing a draft. Empty supported text is editable; file links and unavailable content stay read-only. Save uses atomic replacement, preserves UTF-8 BOM/newlines/Unix permissions and rejects changed, replaced or missing files. Errors retain the draft. Simultaneous external writes during saving remain an MVP limitation.

New Text File (Command-Option-N) and New Folder (Command-Shift-N) are available in the File menu, Directory actions and pane background menus. Enter the exact name, including any desired extension. Creation rejects invalid names and occupied destinations, including broken links, and selects the new empty item. New text is immediately editable. Dot-prefixed creation enables Show Hidden Files only in its creating pane. Other matching panes refresh while preserving their own settings and selection. Dirty drafts use Save/Discard/Cancel before the name prompt; failures remain visible. The [creation review fixture](agent-paper-trail/specs/001-mvp/evidence/new-text-file-folder.md#disposable-fixture-and-run-instructions) provides disposable checks.

Rename one selected file, folder, package or link with Return in the browser list, a file-row double-click, its row context menu or File → Rename (Command-Shift-R). Edit the name inline; Return confirms and Escape cancels with selection retained. The basename is initially selected without its final extension; folders and extensionless dotfiles are selected whole. The extension remains editable. Rename keeps the item in its containing directory. Invalid names and occupied destinations are rejected; case-only renames follow the filesystem. Affected dirty documents use Save/Discard/Cancel before mutation. Cancel or failure retains the draft; Discard takes effect only after successful rename. Matching panes refresh, browsers inside a renamed directory follow the new path, and affected previews reload or close with a fresh save baseline. Renaming a link retains its target text. Rename keeps each pane’s hidden visibility setting. The [rename review fixture](agent-paper-trail/specs/001-mvp/evidence/rename-affected-document-handling.md#disposable-fixture-and-run-instructions) provides disposable checks. Cross-window mutation coordination remains a later task.

Right-click an item to open it in Finder or copy absolute/relative paths. Open in Finder opens directory contents and reveals/selects files, packages and file links in their containing folders. It applies to the selection and is also available in the File menu, disabled when nothing is selected. It retains PanePeek's document and reports detected errors. An unselected row becomes selected; a selected row preserves the selection and becomes primary. Multiple paths copy one per line in displayed order, preserving plain spaces, Unicode and listed link paths. Relative paths use that pane's directory. The Edit menu also offers Copy Absolute Path (Command-Option-C) and Copy Relative Path (Command-Option-Shift-C). Directory actions and Go → Copy Directory Path copy the focused directory, including with no selection.

Each pane's breadcrumb star saves or removes its displayed directory without changing pane focus, navigation or selection. Both panes reflect the same saved paths. Open a saved directory in the focused pane through the shared toolbar or menu-bar Favourites menu. Favourites persist locally across launches; an unavailable favourite reports the normal navigation error and remains saved. Directory links use the canonical location already displayed by navigation. Dirty favourite navigation follows the same Save/Discard/Cancel guard; stars retain drafts. Independent windows remain a later task.

## Build and run

Requirements: macOS 26+, Swift 6.2 or later with a macOS SDK supporting the deployment target, Node.js 22 or later, and full Xcode with its licence accepted for asset compilation. The Swift package and behaviour tests can use Command Line Tools. UI icons are bundled locally; the app has no runtime third-party dependencies.

From the repository root:

```sh
node scripts/build-app.mjs
open .build/PanePeek.app
```

The script builds the debug executable and creates a local app bundle in `.build/PanePeek.app`, including the development icon, compiled UI icons and light/dark accent colours. Its minimum macOS version comes from `Package.swift`. Quit the running app before rebuilding it. Generated build files are ignored by Git.

Asset compilation respects `DEVELOPER_DIR` or the selected Xcode installation. If Command Line Tools are selected and `DEVELOPER_DIR` is unset, the script uses `/Applications/Xcode.app/Contents/Developer` for asset compilation only. For a different Xcode location, set `DEVELOPER_DIR` when building; the script does not change global toolchain selection.

The local development bundle runs outside the App Sandbox. Distribution signing and notarisation are deferred.

If a rebuilt bundle fails to relaunch with an invalid cached executable signature, use the [generated-executable recovery](agent-paper-trail/notes/0001-build-and-bundle.md#rebuilt-executable-recovery). No signing identity or system setting is changed.

## Tests

Run the browsing, sorting, visibility, selection, copied-path, favourites, metadata, preview, editor, creation, rename and highlighting behaviour suite:

```sh
node scripts/test.mjs
```

The runner uses `swift test`, adding the installed Testing macro search directory when available. Tests use isolated temporary directories and uniquely named preference suites; completion-order tests use controlled asynchronous reads and sorts. They do not mutate working files or the application's real preferences.

## Acceptance evidence

The [MVP task tracker](agent-paper-trail/specs/001-mvp/tasks.md) records accepted/merged work and the next gated slice. [Criterion verdicts](agent-paper-trail/specs/001-mvp/validation.md) distinguish completed checks from later-task and app-wide accessibility work. Task evidence links retain detailed native review and disposable fixtures, including the accepted editor/Save and PR #15 corrections.

## Structure

- `Package.swift` owns the macOS deployment target and application executable.
- `sources/panepeek/` contains the SwiftUI app entry point, native navigation controls and window layout. Independent windows belong to a later task.
- `sources/panepeek-core/` contains asynchronous directory listing and per-pane/window browsing state.
- `tests/panepeek-core/` contains the meaningful browsing behaviour tests.
- `scripts/build-app.mjs` builds and bundles the app using Swift and Node's built-in libraries.
- `assets/PanePeek.icns` is the development icon derived from the accepted SVG composition. To regenerate it, run `node scripts/export-app-icon.mjs`; this uses built-in macOS Quick Look, Swift/AppKit, `sips` and `iconutil`, with intermediate files in `.build/app-icon/`. The exporter preserves the SVG geometry and adds transparent margins and a rounded background. Final icon refinement and small-size acceptance remain in T18.
- [`assets/ui.xcassets`](assets/README.md) contains the draft's Lucide template icons and named Mauve accent. The bundler compiles it with Xcode's `actool` and includes the icon licence.

Swift target/module names keep their normal capitalisation. Explicit package paths allow lowercase source/test directories. The platform requires `Contents`, `MacOS` and `Resources` inside the app bundle.

## Project context

- [Project paper trail](agent-paper-trail/README.md)
- [MVP specification](agent-paper-trail/specs/001-mvp/spec.md)
- [Implementation plan](agent-paper-trail/specs/001-mvp/plan.md)
- [Task tracker](agent-paper-trail/specs/001-mvp/tasks.md)
- [Accepted draft UI and logo](agent-paper-trail/design/001-mvp/README.md)
