# PanePeek

A focused local file browser for macOS 26+, with independent directory panes and a Details sidebar for inspecting and editing text.

The application lists directories in two independent panes beside Details. Navigate with Home, root/ancestor breadcrumbs, directory double-click or Return, Go to Folder/Command-L, and the shared folder chooser or Enclosing Folder action (Command-Up). Long breadcrumbs scroll horizontally; directory links follow their canonical target. Click each pane's Name or Modified heading to sort; click again to reverse. Name keeps folders first; Modified sorts folders and files together by date. URL selections stay intact through reordering. Command-click toggles rows, Shift-click selects a range, and Edit → Select All (Command-A) selects visible rows. Escape clears the focused listing. Details shows the primary selected name and full absolute path, with an adjacent copy action. Rows show relative recent dates or exact older dates, with complete timestamps in help/accessibility, and distinguish packages/links. Directory actions and the View menu offer Show Hidden Files (Command-Shift-period) and Refresh (Command-R) for the focused pane. Visibility and sorting survive navigation and Refresh. Failed reads keep the previous directory usable. File mutations remain in later tasks. The bundle uses the accepted peeking-P development icon.

Details reads creation/modified dates, Unix permissions, owner/group, type and available byte size for the focused pane's primary item. Unavailable fields are explicit; folders and packages have no aggregate size. Links show their own metadata and stored target path separately, including broken links. Selection changes and successful Refresh reload metadata; failed reads clear previous values and show an error. Metadata remains visible while content preview is unavailable.

Above metadata, Details previews UTF-8 text with or without a BOM, up to 1 MiB including the BOM. Text is selectable, copyable and read-only. Empty files, NUL-containing binary files, invalid UTF-8, oversized files, folders/packages and read errors have explicit states. File links can preview regular text targets while retaining their listed path and own metadata. Refresh rereads the selected file, including when its size and timestamp have not changed. The preview uses installed Operator Mono Lig, then JetBrains Mono, then the system monospaced font. Fonts are optional and are not bundled. Swift, JSON, YAML/YML, TOML, JavaScript/TypeScript, HTML/XML, JSX/TSX, CSS/SCSS and PHP previews have lexical highlighting with light/dark colours. JavaScript includes `.js`/`.mjs`/`.cjs`; TypeScript includes `.ts`/`.mts`/`.cts`; HTML includes `.html`/`.htm`. Markup remains source text; HTML script/style bodies stay plain. JSX/TSX distinguish tags, attributes and embedded code expressions while preserving plain child text and literal entities. CSS/SCSS colour selectors, properties, values and comments; SCSS also colours variables and directives. PHP highlights standard blocks, variables, strings and comments; surrounding markup and configuration-dependent `<?` tags stay plain. Indented `.sass` stays plain. Other extensions stay plain. Remaining languages and editing belong to later units.

Right-click an item to copy absolute or relative paths. An unselected row becomes selected; a selected row preserves the selection and becomes primary. Multiple paths copy one per line in displayed order, preserving plain spaces, Unicode and listed link paths. Relative paths use that pane's directory. The Edit menu also offers Copy Absolute Path (Command-Option-C) and Copy Relative Path (Command-Option-Shift-C). Directory actions and Go → Copy Directory Path copy the focused directory, including with no selection.

Each pane's breadcrumb star saves or removes its displayed directory without changing pane focus, navigation or selection. Both panes reflect the same saved paths. Open a saved directory in the focused pane through the shared toolbar or menu-bar Favourites menu. Favourites persist locally across launches; an unavailable favourite reports the normal navigation error and remains saved. Directory links use the canonical location already displayed by navigation. Independent windows and dirty-document guards remain later tasks.

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

Run the browsing, sorting, visibility, selection, copied-path, favourites, metadata, preview and highlighting behaviour suite:

```sh
node scripts/test.mjs
```

The runner uses `swift test`, adding the installed Testing macro search directory when available. Tests use isolated temporary directories and uniquely named preference suites; completion-order tests use controlled asynchronous reads and sorts. They do not mutate working files or the application's real preferences.

## Browsing review

[T02 evidence](agent-paper-trail/validation/t02-directory-browsing.md) includes disposable fixture setup, executed checks and Bilal's acceptance of both units on 2026-10-05. Use different directories in each pane, switch focus without selecting a row, and try missing/regular-file paths. Check Home/root, ancestor clicks, long-path scrolling, keyboard access and native appearance/resizing. The thin Mauve underline identifies the pane targeted by shared actions.

[T01 evidence](agent-paper-trail/validation/t01-launchable-shell.md) retains the accepted shell/icon checks. Task acceptance and remaining criteria live in the [validation checklist](agent-paper-trail/validation/checklist.md).

[T03 evidence](agent-paper-trail/validation/t03-sorting-hidden-visibility.md) includes sorting/date and hidden-file fixtures with manual checklists. The [task tracker](agent-paper-trail/specs/001-mvp/tasks.md) owns current review and publication state.

[T04 evidence](agent-paper-trail/validation/t04-multiple-selection-primary-item.md) includes the disposable selection fixture, executed checks and manual acceptance record.

[T14 evidence](agent-paper-trail/validation/t14-context-actions-copied-paths.md) includes the path-copy fixture, executed clipboard checks and accepted manual review.

[T15 evidence](agent-paper-trail/validation/t15-persistent-favourites.md) includes the favourites fixture, accepted persistence/navigation checks and restored native toolbar review.

[T05 evidence](agent-paper-trail/validation/t05-details-metadata-sidebar.md) includes the metadata fixture, filesystem comparisons, Refresh/error checks and accepted manual checklist.

[T06 evidence](agent-paper-trail/validation/t06-read-only-preview-highlighting.md) includes accepted bounded-preview, Swift/JSON/YAML/TOML highlighting and Details scrolling checks. [Unit 4 JavaScript/TypeScript](agent-paper-trail/validation/t06-read-only-preview-highlighting.md#unit-4-javascript-and-typescript-highlighting) is accepted, with disposable fixtures and run instructions.

[Unit 5 HTML/XML](agent-paper-trail/validation/t06-read-only-preview-highlighting.md#unit-5-html-and-xml-highlighting) is accepted after all five manual checks passed, with markup boundaries, source copy/scroll and Refresh evidence.

[Unit 6 JSX/TSX](agent-paper-trail/validation/t06-read-only-preview-highlighting.md#unit-6-jsx-and-tsx-highlighting) is accepted after all five manual checks passed, with mixed-syntax boundaries, source copy/scroll and Refresh evidence.

[Unit 7 CSS/SCSS](agent-paper-trail/validation/t06-read-only-preview-highlighting.md#unit-7-css-and-scss-highlighting) is accepted after all five manual checks passed, with style boundaries, source copy/scroll and Refresh evidence.

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

[Unit 8 PHP](agent-paper-trail/validation/t06-read-only-preview-highlighting.md#unit-8-php-highlighting) is accepted after all five manual checks passed, with block/string boundaries, source copy/scroll and Refresh evidence.
