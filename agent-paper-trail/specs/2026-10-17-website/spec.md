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

The homepage explains side-by-side browsing and inline previews/editing, includes useful Mac shortcuts and a small FAQ, and uses released-app copy without pre-launch messaging. Appearance defaults to the visitor’s system preference. The footer offers System, Light and Dark on all three pages; an explicit choice is saved locally in the browser, and System clears it. CSS still follows system appearance without JavaScript. All keyboard focus rings use Mauve from the active palette. Website responsiveness does not imply an iOS app.

The Support page provides getting-started steps, verified keyboard shortcuts and common troubleshooting guidance, with an email contact link. It shares the homepage’s appearance and navigation. The contact address is the confirmed working mailbox `support@panepeek.app`.

The Privacy page identifies Bilal Cinarli as publisher and explains local file processing, saved preferences, optional support correspondence and Apple/platform services. Its wording follows the implemented app; it must distinguish app behaviour from OS-managed cloud storage and Apple diagnostics. Privacy questions use the confirmed support mailbox. Production hosting/mail-provider disclosures require confirmation before publication.

All three pages include plain footer links to the [project repository](https://github.com/bcinarli/pane-peek), [X profile](https://x.com/bcinarli) and [LinkedIn profile](https://www.linkedin.com/in/bcinarli), without embedded widgets or claims about repository visibility or licensing. The project GitHub link also appears in each top menu.

The hero follows the selected appearance, retaining the illustrative light preview and showing an updated native Macchiato capture in dark mode. The editing section shows native light and Macchiato captures in either website appearance. Native images use fictional sample documents; capture preparation isolates preferences and avoids modifying the parallel app worktree. Cursor/glow cleanup is limited to its title-bar area and preserves the native resolution and every pixel outside that area.

Final release screenshot selection must reflect the final native app appearance, including full Macchiato dark mode.

The planned primary domain is `panepeek.app`; `panepeek.com` is also owned. Bilal confirmed `support@panepeek.app` is working on 2026-10-18; Support and Privacy use it.

In-page anchors scroll smoothly when reduced motion is not requested. Screenshot links open an accessible native modal lightbox, with Close, Escape and outside-click dismissal, contained focus and return focus to the triggering image. Ordinary image links remain a fallback without JavaScript; modified clicks retain browser behaviour.

External HTTP(S) links open in a new tab/window using native HTML, with opener isolation and an accessible new-tab cue. Local routes, fragments, screenshot links and email links retain their existing behaviour.

The homepage hero begins “A little more room to see what you’re working with” and retains a warm, everyday tone.

Public copy uses the internal-doc preset: plain everyday words, consistent terms and direct positive phrasing. Avoid rhetorical contrast and staged three-step beats. Keep actual UI labels, file limits and privacy facts precise across visible copy, metadata and accessible labels.

## Acceptance criteria

| ID | Outcome |
| --- | --- |
| W1 | Latte light mode and Macchiato dark mode, existing logo and prominent app imagery establish the accepted visual direction. |
| W2 | Product copy reflects implemented features; illustrative imagery is labelled as such, native captures are identified, and pre-launch messaging is absent. Download links use the requested App Store homepage placeholder in the local preview; publication requires PanePeek’s actual product URL. |
| W3 | Section navigation, full-size image links and the native HTML FAQ work without JavaScript or dead links. The explicitly requested App Store placeholder is a preview exception, not a product listing. |
| W4 | Layout reflows at narrow widths and enlargement; semantic structure, image alternatives, contrast, visible focus and keyboard access support applicable WCAG A/AA requirements. Avoid unnecessary motion. |
| W5 | The homepage runs independently from the app with local assets and fonts, documented preview instructions and no remote runtime dependencies. |
| W6 | The Support page is reachable from the homepage, provides guidance consistent with implemented app behaviour, and exposes the confirmed working support contact. Its local sections and FAQ work without JavaScript. |
| W7 | A readable Privacy page identifies the publisher, describes app data handling accurately, links to contact information and is reachable from Home and Support without JavaScript. Unconfirmed operational details remain explicit publication prerequisites. |
| W8 | Home, Support and Privacy expose the project GitHub repository and supplied X/LinkedIn URLs as accessible plain links, with GitHub also in the top menu; the header and footer reflow without remote runtime dependencies. |
| W9 | Updated dark app imagery is an authentic native Macchiato capture with fictional data, accurate alternatives/captions, documented provenance and correct responsive display. The hero follows the selected appearance and light editing imagery remains visible in either theme. |
| W10 | In-page anchors scroll smoothly while respecting reduced motion; screenshot links open a responsive, keyboard-operable lightbox with reliable dismissal/focus return and ordinary-link fallback. |
| W11 | All external HTTP(S) destinations open in a new tab/window, announce the context change accessibly and isolate the opener; local navigation, email and screenshot previews retain their behaviour. |
| W12 | Home, Support and Privacy use consistent everyday wording, with positive phrasing and factual product/privacy details preserved; copy reflows and accessible labels remain clear. |
| W13 | System is the default theme choice; Light/Dark overrides persist across pages and reloads, update screenshots/browser chrome and remain keyboard accessible. Storage failure retains current-page switching. The restored hero wording fits the layout; the browser setting is disclosed in Privacy. |

## Boundaries

Final release screenshot selection/icon, actual App Store URL, pricing, hosting/domain configuration and deployment remain outside these local preview units. The requested placeholder does not establish a live PanePeek product listing or App Store approval. App release work remains under the app workstream.
