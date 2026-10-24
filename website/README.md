# PanePeek website

Local website preview using static HTML/CSS and a small native JavaScript image lightbox. The HTML preview needs no framework, dependencies or build step. The website lives beside the app in this repository and can be served independently. [Markdown generation](../CONTRIBUTING.md#website-markdown-generation) uses separate development tooling.

## Preview

From the repository root:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory website
```

Open [Home](http://127.0.0.1:4173/), [Support](http://127.0.0.1:4173/support/) or [Privacy](http://127.0.0.1:4173/privacy/). Stop the server with Control-C. Opening `index.html` directly also works.

The [Pages preview](../CONTRIBUTING.md#pages-preview) exercises same-URL Markdown negotiation and Cloudflare routing.

## Search and agent discovery

Home, Support and Privacy declare canonical URLs on `https://panepeek.app/` and include Schema.org JSON-LD in the initial HTML. The homepage describes the website and Mac app; each page has its own WebPage entry. Structured descriptions match the existing metadata and application facts. No price, rating or public-release availability is inferred.

`robots.txt` allows crawling and declares `sitemap.xml`, which lists the three canonical content pages. Its [Content Signals](https://contentsignals.org/) allow search indexing, search results and AI input, including generated answers, while disallowing AI training. These preferences apply to all user agents; CDN bot controls are configured separately. `llms.txt` gives agents a short product summary and links to those pages; each page links to it with `rel="describedby"`. This supplementary index does not guarantee search or AI inclusion.

Each canonical page also advertises its generated Markdown through `rel="alternate"` and an HTTP Link header. `llms.txt` lists the static Markdown URLs. These documents use `text/markdown; charset=utf-8` and remain outside Function routing; canonical HTML URLs support GET/HEAD negotiation with `Accept: text/markdown`.

`404.html` gives missing URLs a themed recovery page with Home and Support links and `noindex`. Its assets and destinations use root-relative URLs so they work at nested missing paths. Cloudflare Pages uses this top-level file to disable its default homepage fallback. Verify the actual 404 status and crawler-file content types after publication. The local Python server can display [the page](http://127.0.0.1:4173/404.html), but its missing-route error body is Python's own, rather than the custom page.

See [discovery validation](../agent-paper-trail/specs/2026-10-17-website/evidence/search-ai-discovery.md) for executed checks and remaining review.

## Shared-link previews

Home, Support and Privacy include Open Graph and X summary-large-image metadata in the HTML, with individual titles/descriptions and their canonical URLs. They share the 1200 × 630 JPEG at `assets/social-preview.jpg`, with explicit type/dimensions and descriptive alternatives. The image reuses the logo and native dark editor capture; its [editable artwork](../agent-paper-trail/design/website/README.md) stays outside the deployed site.

After publication, verify that crawlers can fetch the page and image, inspect cached metadata and check actual previews in WhatsApp, X, LinkedIn and Bluesky. Client settings and caching affect rendering. The 404 page retains its missing-page metadata. See [validation](../agent-paper-trail/specs/2026-10-17-website/evidence/social-previews.md).

## Stylesheet organisation

`styles.css` groups global tokens/themes, base elements, layout/accessibility utilities, components, page composition and responsive width breakpoints in that order. Component states stay with their owners; theme and motion conditions stay beside the rules they govern. Structural `:where()` filters keep component specificity low. Avoid declarations that undo earlier rules. See [CSS validation](../agent-paper-trail/specs/2026-10-17-website/evidence/css-cleanup.md).

## Assets and content

`assets/peeking-p.svg` is an unchanged copy of the [accepted logo source](../agent-paper-trail/design/001-mvp/README.md).

`app-browse.png` and `app-browse-dark.png` show native Light and Macchiato Markdown previews with highlighted YAML front matter beside the shared fictional Project folder. `app-preview-pdf.png` shows a read-only PDF fitted to the preview width, with native zoom controls; `app-preview-html.png` shows a styled local HTML page. These captures use the current app source and share 2436 × 1200-pixel window geometry. PNG masters preserve the decoded native capture pixels, colour profile and EXIF, without retouching. The captures contain no cursors or glows.

`app-edit-dark.png` and `app-edit-light.png` show highlighted TypeScript TSX and Python drafts beside a folder of fictional code and configuration files. Both are native PanePeek 1.0.0 (5) captures at 2436 × 1200 pixels, prepared using keyboard input so no cursor or glow appears. PNG exports preserve the decoded capture pixels, without retouching. Both editing appearances remain visible in either theme; their frames and captions align.

Every homepage section uses wrap directly. Editing and Preview share one full-width background container and use the same layout, screenshot frames and section-space padding at every breakpoint. A short paragraph describes the six preview formats and links to Support, with PDF and HTML screenshots below it. File Previews follows Syntax highlighting in Support, with brief format details and limits. The [rendering evidence](../agent-paper-trail/specs/2026-10-17-website/evidence/rendering-content.md) owns current acceptance limits.

Inline images and full-size links use [lossless WebP derivatives](../agent-paper-trail/specs/2026-10-17-website/evidence/lossless-webp.md) of the unchanged PNG masters. The full-resolution derivatives retain native dimensions, decoded pixels, ICC colour profiles and EXIF. Regenerate derivatives after master changes and verify decoded pixels and colour profiles.

Inline screenshots also provide [responsive WebP previews](../agent-paper-trail/specs/2026-10-17-website/evidence/responsive-webp.md) through width-based `srcset` and layout-matched `sizes`. Native captures have 480, 800, 1200 and 1600 px previews plus the original. Previews are resized directly from PNG masters with Lanczos, encoded losslessly and retain their ICC colour profiles. Full-size links always open the unchanged original-resolution WebP. Regenerate preview sizes with their masters and check mobile/Retina selection after layout changes.

CSS frames app content below the title bar, omitting the system control badge. Full-size links open the complete WebP images. Final release screenshot selection remains separate. See [editing capture provenance and validation](../agent-paper-trail/specs/2026-10-17-website/evidence/syntax-highlighting-content.md).

Every page fills at least the browser height. Main content grows to keep the footer at the bottom on short pages, while longer pages scroll naturally with the footer after the content.

Paired editing previews share a visible frame ratio and caption baseline; their PNG masters and full-size WebP modal images retain native dimensions. The homepage highlights useful shortcuts and links to the grouped Support reference. That reference focuses on app-specific and less-obvious commands, with readable key names and active-pane context. Familiar Mac shortcuts are linked separately. See [image and shortcut validation](../agent-paper-trail/specs/2026-10-17-website/evidence/images-shortcuts.md).

The website defaults to system appearance, with a native System/Light/Dark menu in every page’s footer. An explicit choice is saved in this browser; System clears it. Without JavaScript, CSS follows system appearance. A small shared script applies the saved choice before the stylesheet loads, and the Privacy page explains this browser setting. The palettes use CSS `light-dark()` with [Catppuccin Latte and Macchiato](https://catppuccin.com/palette/). System fonts are used. Accent, focus, button-hover and shadow colours adapt to each appearance. Focus rings use Mauve in both themes. Anchor navigation and the FAQ use native HTML. Anchors scroll smoothly unless reduced motion is requested. Screenshot links open a native dialog, with Close, Escape and outside-click dismissal and focus returned to the image link. Without JavaScript or modal-dialog support, the links open the image directly; modified clicks keep normal browser behaviour. The theme preference is the only browser storage used. Cloudflare Pages adds its Web Analytics script to the deployed website. The macOS app has no analytics.

All four footers include plain links to the project GitHub repository, X (@panepeek), X (@bcinarli) and Bilal’s LinkedIn profile. GitHub also appears in each top menu. External HTTP(S) links across the site open in a new tab/window, with opener isolation and an accessible new-tab cue. Internal routes, screenshot previews and email links keep their existing behaviour. No embedded social widgets are used.

Download links point to [GitHub Releases](https://github.com/bcinarli/pane-peek/releases). Replace the destinations and labels with PanePeek’s product listing after App Store approval. Public access to the repository and downloadable release assets must be verified separately.

Support and Privacy use the confirmed working contact address `support@panepeek.app`, with separate email subjects for support and privacy requests.

The Privacy page covers the macOS app, Cloudflare website hosting and voluntary support correspondence through Apple’s iCloud Mail. Support emails and attachments are deleted three months after receipt. GitHub Issues is an additional support route with its own data handling; the email retention period does not apply there. Support is provided as time allows, without a guaranteed reply or resolution.

The website is live at [panepeek.app](https://panepeek.app) through Cloudflare Pages. The GitHub integration deploys `main` using the [publication settings](../CONTRIBUTING.md#pages-publication-settings), generating Markdown alongside the static HTML. Website and Markdown-tooling changes publish automatically; native-only changes are excluded by the watched paths. [Markdown publication evidence](../agent-paper-trail/specs/2026-10-17-website/evidence/markdown-publication.md) records live verification and remaining acceptance limits.

See the [deployment evidence](../agent-paper-trail/specs/2026-10-17-website/evidence/cloudflare-publication.md) for hosting, domains and preserved mail routing. [Live verification](../agent-paper-trail/specs/2026-10-17-website/evidence/deployed-verification.md) confirms the discovery files, share metadata/image and custom HTTP 404 responses.

Public copy uses everyday wording and consistent terms across Home, Support and Privacy. The internal-doc preset guides wording, including metadata and accessible labels. Exact app command names and file limits retain their technical spelling.

[Scope and validation](../agent-paper-trail/specs/2026-10-17-website/README.md).
