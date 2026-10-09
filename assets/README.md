# Native UI assets

`ui.xcassets` holds editable SVG template images and the named `accent` colour. The [app bundler](../scripts/build-app.mjs) compiles them into `Contents/Resources/Assets.car`; SwiftUI loads them from the main app bundle. Running the bare Swift executable does not package these resources.

The icon paths come from the official [Lucide 1.17.0 package](https://registry.npmjs.org/lucide/1.17.0), matching the version pinned in the [editable UI draft](../agent-paper-trail/design/001-mvp/app-draft.fragment.html). The package tarball was checked against its published SHA-512 integrity before extraction. No package code runs at build time or in the app.

| Asset | Lucide source | Placement |
| --- | --- | --- |
| `icon-folder-open` | `folder-open` | Go to Folder toolbar button |
| `icon-star` | `star` | Favourites menu and unsaved directory star |
| `icon-star-filled` | `star`, with the draft's filled state | Saved directory star |
| `icon-sliders-horizontal` | `sliders-horizontal` | Directory actions menu |
| `icon-house` | `house` | Home buttons |
| `icon-folder` | `folder` | Directory rows |
| `icon-file-text` | `file-text` | Regular file rows |
| `icon-copy` | `copy` | Details path-copy button |

Images use the original 24-unit view box, a 16-point display size and two-unit rounded strokes. Template rendering allows native control and selection colours. Package/link symbols and standard chevrons remain SF Symbols, preserving their existing distinctions. The full Lucide/Feather licence is retained in [lucide-LICENSE.txt](lucide-LICENSE.txt) and copied into the app bundle.

The accent asset uses sRGB `#8255B6` in light appearance and `#C6A0F6` in dark appearance, as required by the accepted spec. `NSAccentColorName` registers it for native controls; SwiftUI also uses the named colour for existing focus/favourite indicators.
