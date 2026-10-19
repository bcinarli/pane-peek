# PanePeek website

Local website preview using static HTML/CSS and a small native JavaScript image lightbox. No framework, dependencies or build step. The website lives beside the app in this repository and can be served independently.

## Preview

From the repository root:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory website
```

Open [Home](http://127.0.0.1:4173/), [Support](http://127.0.0.1:4173/support/) or [Privacy](http://127.0.0.1:4173/privacy/). Stop the server with Control-C. Opening `index.html` directly also works.

## Assets and content

`assets/peeking-p.svg`, `app-browse.png` and the retained unused `app-edit.png` are unchanged copies of the [accepted design sources](../agent-paper-trail/design/001-mvp/README.md). The light hero is labelled “Design preview”.

`app-browse-dark.png`, `app-edit-dark.png` and `app-edit-light.png` come from native captures of the updated app with fictional sample files. The hero follows the selected appearance; both editing appearances remain visible in either theme. The cursor and glow were removed only within a 160 × 104-pixel title-bar area, using matching native title-bar pixels. Lossless PNGs retain the original resolution and identical pixels everywhere outside that area. The unused JPEG originals remain as capture sources.

CSS frames app content below the title bar, omitting the system control badge retained in the light capture. Full-size links open the cursor-free PNGs. Final release screenshot selection remains separate. See [capture provenance and validation](../agent-paper-trail/specs/2026-10-17-website/evidence/native-dark-screenshot.md).

The website defaults to system appearance, with a native System/Light/Dark menu in every page’s footer. An explicit choice is saved in this browser; System clears it. Without JavaScript, CSS follows system appearance. A small shared script applies the saved choice before the stylesheet loads, and the Privacy page explains this browser setting. The palettes use CSS `light-dark()` with [Catppuccin Latte and Macchiato](https://catppuccin.com/palette/). System fonts are used. Accent, focus, button-hover and shadow colours adapt to each appearance. Focus rings use Mauve in both themes. Anchor navigation and the FAQ use native HTML. Anchors scroll smoothly unless reduced motion is requested. Screenshot links open a native dialog, with Close, Escape and outside-click dismissal and focus returned to the image link. Without JavaScript or modal-dialog support, the links open the image directly; modified clicks keep normal browser behaviour. The theme preference is the only browser storage used. No external runtime resources, analytics or data-collection forms are used.

All three footers include plain links to the project GitHub repository and Bilal’s supplied X/LinkedIn profiles. GitHub also appears in each top menu. External HTTP(S) links across the site open in a new tab/window, with opener isolation and an accessible new-tab cue. Internal routes, screenshot previews and email links keep their existing behaviour. No embedded social widgets are used.

Download links point to [GitHub Releases](https://github.com/bcinarli/pane-peek/releases). Replace the destinations and labels with PanePeek’s product listing after App Store approval. Public access to the repository and downloadable release assets must be verified separately.

Support and Privacy use the confirmed working contact address `support@panepeek.app`, with separate email subjects for support and privacy requests.

The Privacy page covers the macOS app, Cloudflare website hosting and voluntary support correspondence through Apple’s iCloud Mail. Support emails and attachments are deleted three months after receipt. GitHub Issues is an additional support route with its own data handling; the email retention period does not apply there. Support is provided as time allows, without a guaranteed reply or resolution.

Publication uses Cloudflare Workers Static Assets with `website/` as the only asset directory. `panepeek.app` is primary; `panepeek.com` and the `www` versions redirect to it with permanent redirects preserving paths and query strings. Deployment and live-domain verification are tracked in the website records below.

Public copy uses everyday wording and consistent terms across Home, Support and Privacy. The internal-doc preset guides wording, including metadata and accessible labels. Exact app command names and file limits retain their technical spelling.

[Scope and validation](../agent-paper-trail/specs/2026-10-17-website/README.md).
