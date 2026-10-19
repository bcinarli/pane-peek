---
status: Active
date: 2026-10-17
supersedes: []
superseded_by: ""
---

# PanePeek website specification

The website introduces the released PanePeek app. The accepted local homepage direction uses Things’ simplicity and DaisyDisk’s focus on app screenshots, with Catppuccin Latte for light appearance and Macchiato for dark appearance.

## Scope

Keep the website in `website/` in the application repository. Use static HTML/CSS with a small native JavaScript enhancement for image previews, with no framework, dependencies or build step. Reuse the [accepted logo and editable UI sources](../../design/001-mvp/README.md); mark illustrative imagery visibly. The [MVP spec](../001-mvp/spec.md) remains authoritative for product claims.

Every page fills at least the browser viewport height. The main content grows to keep the footer at the bottom on short pages; longer content scrolls normally with the footer after it.

Organise the shared stylesheet as global tokens/themes, base elements, layout/accessibility utilities, components with their states, page composition and responsive width breakpoints. Keep theme and motion conditions beside the rules they govern. Use low-specificity selectors and avoid declarations that merely undo earlier rules. CSS maintenance preserves the accepted appearance, keyboard access and interactive behaviour.

The homepage leads with editing text files while browsing documents, without opening a separate editor. Dual panes are a supporting feature. Put editing before folder-layout features and introduce it immediately after opening a folder in Support. Include useful Mac shortcuts and a small FAQ, using released-app copy without pre-launch messaging. Appearance defaults to the visitor’s system preference. The footer offers System, Light and Dark on all three pages; an explicit choice is saved locally in the browser, and System clears it. CSS still follows system appearance without JavaScript. All keyboard focus rings use Mauve from the active palette. Website responsiveness does not imply an iOS app.

The Support page provides getting-started steps, verified keyboard shortcuts and common troubleshooting guidance. It shares the homepage’s appearance and navigation. Contact uses `support@panepeek.app` or GitHub Issues for bugs, suggestions and questions. Support is provided as time allows, without a guaranteed reply or resolution.

The Privacy heading area uses the shared container capped at 1120 px; its policy sections align with the heading’s left edge and are capped at 760 px, shrinking to the available width on smaller screens.

The Privacy page identifies Bilal Cinarli as publisher and explains local file processing, saved preferences, optional support correspondence and Apple/platform services. Its wording follows the implemented app; it must distinguish app behaviour from OS-managed cloud storage and Apple diagnostics. Privacy questions use the confirmed support mailbox. Group website hosting/request processing and the saved browser theme disclosure in one Website section. Disclose Apple’s iCloud Mail for support. Support emails and attachments are deleted three months after receipt; this policy does not apply to GitHub Issues.

All three pages include plain footer links to the [project repository](https://github.com/bcinarli/pane-peek), [X profile](https://x.com/bcinarli) and [LinkedIn profile](https://www.linkedin.com/in/bcinarli), without embedded widgets or claims about repository visibility or licensing. The project GitHub link also appears in each top menu.

The hero follows the selected appearance, retaining the illustrative light preview and showing an updated native Macchiato capture in dark mode. The editing section shows native light and Macchiato captures of a visibly highlighted code file beside varied supported code/configuration files in either website appearance. Support lists the implemented highlighting languages and formats, including filename-based build and shell files. Editing captures exclude cursor glow. Native images use fictional sample documents; capture preparation isolates preferences and avoids modifying the parallel app worktree. Cursor/glow cleanup is limited to its title-bar area and preserves the native resolution and every pixel outside that area.

Paired editing previews use the same visible frame proportions, keeping image edges and captions aligned. Preserve each capture’s native dimensions, proportions and accessible full-size image links.

Final release screenshot selection must reflect the final native app appearance, including full Macchiato dark mode.

Publish the static site through Cloudflare Pages, serving only `website/`. The primary domain is `panepeek.app`; `panepeek.com` and both `www` versions redirect permanently to `https://panepeek.app`, preserving paths and query strings. Preserve existing email DNS records and native email links. Support and Privacy use the confirmed working mailbox `support@panepeek.app`.

Download links use `https://github.com/bcinarli/pane-peek/releases` until the App Store submission is approved. Header labels describe Downloads. Public repository/release access is a separate verification prerequisite; this choice does not establish that a downloadable release exists.

In-page anchors scroll smoothly when reduced motion is not requested. Screenshot links open an accessible native modal lightbox, with Close, Escape and outside-click dismissal, contained focus and return focus to the triggering image. Ordinary image links remain a fallback without JavaScript; modified clicks retain browser behaviour.

External HTTP(S) links open in a new tab/window using native HTML, with opener isolation and an accessible new-tab cue. Local routes, fragments, screenshot links and email links retain their existing behaviour.

Distinguish editable text files from read-only image/video previews.

Public copy uses the internal-doc preset: plain everyday words, consistent terms and direct positive phrasing. Avoid rhetorical contrast and staged three-step beats. Keep actual UI labels, file limits and privacy facts precise across visible copy, metadata and accessible labels.

The homepage highlights useful browsing, editing, path-copy and Details shortcuts, with a link to more shortcuts in Support. Support groups PanePeek-specific and less-obvious shortcuts by task, omitting familiar Finder-style selection, navigation, clipboard, editing and window commands. Retain useful path copying, hidden-file display, alternate Rename, Go to Folder, New Text File, Refresh, keyboard context-menu access and Details sizing. Use readable key names, accessible symbol alternatives and clear active-pane context; link to Apple’s reference for familiar Mac shortcuts.

The repository usage guide retains the full 36-action shortcut reference in the same six task groups, including familiar Mac commands. The repository privacy policy preserves its app-specific technical detail and aligns website hosting/theme, support contact, iCloud Mail handling and email-retention facts with the public policy.

## Search and AI discovery

Home, Support and Privacy declare their own canonical HTTPS URL on `panepeek.app` and expose factual Schema.org information in the initial HTML. Describe the website, Mac application and individual pages using stable identifiers. Product requirements and descriptions match visible content; omit unverified pricing, ratings and release availability.

Publish `robots.txt` with the public-site crawl allowance and canonical sitemap location, and list only the three canonical content pages in `sitemap.xml`. A concise `llms.txt`, linked from the three pages, summarises verified product facts and points agents to the existing content. It is supplementary guidance, with no promise of indexing, ranking or AI inclusion. Hosting-level bot controls and model-training permissions are outside this source change.

Provide a top-level `404.html` to replace Cloudflare Pages' default homepage fallback for missing URLs. The page has clear Home/Support navigation, shared appearance controls, root-relative assets and `noindex`; exclude it from the sitemap and do not canonicalise it to the homepage. Actual hosted status codes remain a publication check.

## Social link previews

Home, Support and Privacy expose Open Graph and X summary-large-image metadata in their initial HTML. Each uses its own title, description and canonical URL, plus a shared 1200 × 630 JPEG with an absolute HTTPS URL, MIME type, dimensions and descriptive alternative text. The image reuses the accepted logo, current editing headline and native app capture with fictional sample documents. Keep the editable artwork outside the published website directory.

Metadata and the image are available without executing JavaScript. The 404 page keeps its missing-page identity and noindex. Preview caches, hosting bot access and final rendering in WhatsApp, X, LinkedIn and Bluesky require verification after deployment; source metadata alone cannot guarantee a client will display a card.

## Acceptance criteria

| ID | Outcome |
| --- | --- |
| W1 | Latte light mode and Macchiato dark mode, existing logo and prominent app imagery establish the accepted visual direction. |
| W2 | Product copy reflects implemented features; illustrative imagery is labelled as such, native captures are identified, and pre-launch messaging is absent. Download links use the selected GitHub Releases destination until an approved App Store listing replaces it. |
| W3 | Section navigation, full-size image links and the native HTML FAQ work without JavaScript or dead links. Verify the selected download destination is publicly accessible separately from the local link graph. |
| W4 | Layout reflows at narrow widths and enlargement; semantic structure, image alternatives, contrast, visible focus and keyboard access support applicable WCAG A/AA requirements. Avoid unnecessary motion. |
| W5 | The homepage runs independently from the app with local assets and fonts, documented preview instructions and no remote runtime dependencies. |
| W6 | The Support page is reachable from the homepage, provides guidance consistent with implemented app behaviour, and exposes the confirmed working support contact. Its local sections and FAQ work without JavaScript. |
| W7 | A readable Privacy page identifies the publisher, describes app data handling accurately, links to contact information and is reachable from Home and Support without JavaScript. Unconfirmed operational details remain explicit publication prerequisites. |
| W8 | Home, Support and Privacy expose the project GitHub repository and supplied X/LinkedIn URLs as accessible plain links, with GitHub also in the top menu; the header and footer reflow without remote runtime dependencies. |
| W9 | Updated dark app imagery is an authentic native Macchiato capture with fictional data, accurate alternatives/captions, documented provenance and correct responsive display. The hero follows the selected appearance and light editing imagery remains visible in either theme. |
| W10 | In-page anchors scroll smoothly while respecting reduced motion; screenshot links open a responsive, keyboard-operable lightbox with reliable dismissal/focus return and ordinary-link fallback. |
| W11 | All external HTTP(S) destinations open in a new tab/window, announce the context change accessibly and isolate the opener; local navigation, email and screenshot previews retain their behaviour. |
| W12 | Home, Support and Privacy use consistent everyday wording, with positive phrasing and factual product/privacy details preserved; copy reflows and accessible labels remain clear. |
| W13 | System is the default theme choice; Light/Dark overrides persist across pages and reloads, update screenshots/browser chrome and remain keyboard accessible. Storage failure retains current-page switching. The current hero wording fits the layout; the browser setting is disclosed in Privacy. |
| W14 | Home, Support, Privacy and local assets load over HTTPS at panepeek.app; panepeek.com and both www aliases redirect permanently to the primary domain while preserving paths and query strings, without loops or changes to email routing. |
| W15 | The hero, metadata and first feature section lead with editing text files while browsing, without a separate editor. Features links target editing, Support introduces editing before a second pane, and file-format/save limits remain accurate. |
| W16 | Home, Support and Privacy expose distinct canonical HTTPS URLs and parseable, factual WebSite/SoftwareApplication/WebPage structured data in the initial HTML, with consistent identifiers and descriptions. |
| W17 | The public crawl allowance and sitemap declaration are available as robots.txt; sitemap.xml lists only canonical content pages; the linked llms.txt provides a concise, source-backed product summary and working content links. |
| W18 | Unknown hosted URLs return HTTP 404 with an accessible, themed recovery page; its assets and navigation work from nested paths, it declares noindex and it is excluded from the sitemap. |
| W19 | Home, Support, Privacy and the 404 page fill the viewport when short, with the footer at the bottom; longer content remains scrollable and does not overlap the footer in either theme or at narrow widths. |
| W20 | Home, Support and Privacy expose complete Open Graph and X large-image-card metadata in the initial HTML, with page-specific text and canonical URLs, an absolute HTTPS image URL and accurate image alternatives/type/dimensions. |
| W21 | The shared 1200 × 630 JPEG uses accepted logo geometry and a native editing capture with fictional data, remains legible at preview sizes and has an editable source outside the published site. Hosted fetches and final client previews are checked after deployment. |
| W22 | The shared stylesheet follows the defined responsibility order with lower component specificity and fewer redundant overrides, preserving the current rendering and behaviour across all four pages, themes and responsive breakpoints. |
| W23 | The Privacy heading area aligns with the standard 1120 px container while policy sections retain a left-aligned 760 px reading column, responsive reflow and keyboard access. |
| W24 | Paired editing screenshot frames and captions align at desktop widths and reflow at narrow widths in both themes; full-size images retain native dimensions and modal behaviour remains intact. |
| W25 | The homepage exposes useful shortcut highlights and links to a curated, accessible Support reference of app-specific and less-obvious commands consistent with implementation and the usage guide, with familiar Finder-style commands omitted. |
| W26 | The usage guide lists the complete 36-action reference in six groups, and PRIVACY.md preserves app-specific detail while matching accepted website/support/privacy facts. |
| W27 | Editing screenshots visibly demonstrate code highlighting beside varied supported files, without cursor glow. The homepage links to a complete, source-backed Support language/format list; images, alternatives and captions agree and work at paired/stacked widths and full size. |

## Boundaries

App Store listing approval, final release screenshots/icon and public app release remain separate from website publication. Repository visibility, release creation and mail-retention enforcement are not changed by website source edits. Do not publish credentials, certificates or unrelated repository files as website assets. Commit, push and merge retain separate approval gates.
