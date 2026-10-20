# Native UI assets

`ui.xcassets` holds editable SVG template images and named colours. The [app bundler](../scripts/build-app.mjs) compiles them into `Contents/Resources/Assets.car`; SwiftUI and AppKit load them from the main app bundle. Running the bare Swift executable does not package these resources.

The icon paths come from the official [Lucide 1.17.0 package](https://registry.npmjs.org/lucide/1.17.0), matching the version pinned in the [editable UI draft](../agent-paper-trail/design/001-mvp/app-draft.fragment.html). The package tarball was checked against its published SHA-512 integrity before extraction. No package code runs at build time or in the app.

| Asset | Lucide source | Placement |
| --- | --- | --- |
| `icon-square` | `square` | One Pane segment |
| `icon-square-split-horizontal` | `square-split-horizontal` | Two Panes segment |
| `icon-folder-open` | `folder-open` | Go to Folder toolbar button |
| `icon-star-off` | `star-off` | Remove a row from the Favourites popup |
| `icon-star` | `star` | Favourites button and unsaved directory star |
| `icon-star-filled` | `star`, with the draft's filled state | Saved directory star |
| `icon-sliders-horizontal` | `sliders-horizontal` | Directory actions menu |
| `icon-house` | `house` | Home buttons |
| `icon-folder` | `folder` | Directory rows |
| `icon-file-text` | `file-text` | Text files and common extensionless documentation |
| `icon-eye-off` | `eye-off` | Hidden-item badge beside the existing file/folder icon |
| `icon-file` | `file` | Unknown file types |
| `icon-file-code` | `file-code` | Source, markup, scripts and build files |
| `icon-file-cog` | `file-cog` | Configuration files |
| `icon-file-image` | `file-image` | Images |
| `icon-file-video-camera` | `file-video-camera` | Videos |
| `icon-file-music` | `file-music` | Audio |
| `icon-file-archive` | `file-archive` | Archives |
| `icon-file-spreadsheet` | `file-spreadsheet` | Spreadsheets and delimited tables |
| `icon-file-type` | `file-type` | PDF, word-processing and presentation documents |
| `icon-copy` | `copy` | Details path-copy button |
| `icon-maximize-2` | `maximize-2` | Expand Details header button |
| `icon-minimize-2` | `minimize-2` | Restore Previous Width header button |

Images use the original 24-unit view box, a 16-point display size and two-unit rounded strokes. Template rendering allows native control and selection colours. Package/link symbols and standard chevrons remain SF Symbols, preserving their existing distinctions. The full Lucide/Feather licence is retained in [lucide-LICENSE.txt](lucide-LICENSE.txt) and copied into the app bundle.

The accent asset uses sRGB `#8255B6` in light appearance and `#C6A0F6` in dark appearance, as required by the accepted spec. `NSAccentColorName` registers it for native controls; SwiftUI also uses the named colour for existing focus/favourite indicators.

The [accepted muted selection change](../agent-paper-trail/specs/001-mvp/evidence/muted-selection-prototype.md) adds a separate `selection` colour matching the draft's selection role. It is used by the owned native table rows; the global accent remains unchanged.

File-category selection uses the listed name/extension and macOS type information, without opening file contents. Explicit source/configuration names take precedence over ambiguous extension registrations (for example, `.ts` source files). Directory/package/link identity takes precedence over the filename. These icons describe categories, not an editable-preview guarantee.

Hidden items retain their type icon and use an adjacent eye-off badge. The icon area has a fixed width so names stay aligned. Hidden status comes from listing metadata (including dot names and filesystem flags), appears in the row help/accessibility value and does not create an extra accessibility element.

## Application icon

`app-icon.xcassets` supplies the macOS AppIcon set for native Xcode archives, including its 1024×1024 Store image. It uses the same artwork and size variants as `PanePeek.icns`, which remains the icon for the Swift-package bundler and DMG volume. Regenerate both with `node scripts/export-app-icon.mjs` from the accepted vector source.

## DMG artwork

[dmg/background.svg](dmg/background.svg) is original editable installer artwork: a 760 × 450 Macchiato Base-to-Mantle surface, Mauve directional arrow and native-label backing. The app and Applications icons are actual Finder items. The build reuses `PanePeek.icns` as the volume icon and renders the background at 1×/2× without third-party artwork or a new runtime dependency.

Finder layout is fixed in [dmg-layout.mjs](../scripts/dmg-layout.mjs); AppKit creates its native background bookmark. The metadata writer implements the bounded single-leaf layout documented by the [Finder store format reference](https://metacpan.org/dist/Mac-Finder-DSStore/view/DSStoreFormat.pod). Changes to window dimensions, icon positions or label size require checking the mounted image in Finder.
