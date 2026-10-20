# PanePeek website plan

## Local homepage unit

Implement the homepage in `website/`, with static HTML/CSS and unchanged distribution copies of the accepted logo and design images. Use native HTML for navigation and the FAQ. Use concise released-app content and CSS system-appearance selection: Latte for light mode and Macchiato for dark mode. Remove pre-launch sections and use the selected download destination from the spec.

Validate the served page, local references/assets, desktop/mobile reflow, light/dark visual states and colour contrast, keyboard navigation and FAQ behaviour. Check asset provenance and content claims against the product sources. Layout and native HTML use browser checks rather than artificial behaviour tests.

Apply tighten followed by probe. Present the running local page and executed checks for manual review before the next unit. Manual acceptance, commit, push and publication retain separate gates under the [source-control decision](../../decisions/0002-feature-branches-and-prs.md).

## Support page unit

Add `website/support/index.html` with concise getting-started instructions, verified shortcuts, common troubleshooting questions and an email link. Reuse shared CSS and native HTML. Add homepage navigation to Support and return navigation to Home; use the selected download destination from the spec.

Check both pages’ link graph, Support keyboard behaviour, desktop/mobile reflow and both colour themes. Verify product guidance against implemented app documentation. Apply tighten then probe and present the running page for manual review before another coding unit. Commit, push and publication remain separate.

## Privacy page unit

Add `website/privacy/index.html` with an app-focused policy, confirmed publisher name and source-backed explanations of local processing/storage, support correspondence and platform services. Reuse system themes and shared navigation; link Privacy in the Home and Support footers. Keep legal and operational claims proportionate to verified facts and identify remaining publication prerequisites in the records.

Check the three-page link graph, semantic structure, narrow and desktop reflow, both themes, visible focus and keyboard navigation. Review wording against the source and official platform guidance, then apply tighten and probe. Present the local page for manual review before further coding.

## Project and social links unit

Add a labelled project/social navigation group to each footer with the repository origin and supplied X/LinkedIn profile URLs. Also add the project GitHub link to each top menu and adjust header reflow for the extra item. Keep links native and styling shared, with no widgets or new dependencies. Verify exact destinations, keyboard focus and header/footer reflow in both themes, then apply tighten/probe and present the local result for manual review.

## Native dark screenshot unit

Capture the updated native Macchiato UI from the identified app worktree using a copied bundle and isolated preferences with fictional demo files. Add a theme-aware dark hero while retaining the light hero. Replace the old dark illustrative editing preview with native light and dark editing captures, both visible in either website theme. Frame native app content below the capture title bar; remove only the cursor/glow within a bounded title-bar region and verify unchanged resolution/pixels outside it, update alternatives/captions/provenance and verify full-size navigation and responsive display. Apply tighten then probe and present the website image for review. Do not alter or integrate native app code.

## Page interactions unit

Add CSS smooth scrolling under the no-preference reduced-motion condition across the shared pages. Enhance homepage screenshot links with one native dialog and a small local script, retaining ordinary links as fallback. Use native modal focus and Escape handling, a Close action and outside-click dismissal; lock background scrolling while open.

Activate the confirmed support@panepeek.app mailbox in Support and Privacy and remove their placeholder notices. Check the displayed address and mailto destinations without sending email.

Observe the current behaviour as the red browser baseline, then verify the changed interaction in the browser: each screenshot, image load/alt/caption, keyboard open/close and focus return, inside/outside clicks, narrow/both-theme display, anchor movement and reduced-motion fallback. Preserve normal modified clicks and no-script navigation. Apply tighten/probe and stop for manual review before another unit.

## External links unit

Add native `target="_blank"` and `rel="noopener noreferrer"` to external HTTP(S) links on all three pages, with a visually hidden new-tab cue. Keep existing destinations and local/email/image behaviour. Check all anchors structurally, activate representative external links in the browser, verify internal navigation and lightbox behaviour, then apply tighten/probe and present the preview for manual review.

## Copy consistency unit

Review all three pages using the internal-doc preset. Rewrite public copy, metadata and accessible labels with everyday vocabulary; remove rhetorical contrasts and staged three-step beats while preserving factual limits and exact UI command names. Compare destinations/markup with the previous version and review rendered copy at desktop/narrow widths in both themes. Apply sentence, paragraph and section checks, tighten then probe, and present the local pages for manual review.

## Hero and theme menu unit

Restore the preferred two-sentence hero copy. Add a native, labelled System/Light/Dark select to every footer, with a small shared script that reads the browser preference before the stylesheet and stores explicit choices. Use CSS palette selection for page colours and matching hero imagery. Keep the theme control hidden without JavaScript, retain system appearance as fallback and disclose the saved browser setting in Privacy.

Verify the missing control as a red baseline, then test switching, reload/page persistence, return to System, keyboard focus, screenshots, meta theme colours and responsive header and footer layout. Exercise invalid/unavailable storage and OS-change handling with bounded isolated checks. Apply tighten then probe, present the local preview and retain the manual-review gate.

## Mauve focus rings

Map the shared focus colour to the existing Mauve palette token in both themes. Check keyboard focus on links, FAQ summaries, the lightbox Close button and theme selector, plus contrast against their backgrounds. Apply tighten/probe and present the local preview for manual review.

## Launch content

Point all download links to GitHub Releases with accurate header labels until App Store approval. Add Cloudflare hosting and iCloud Mail disclosures, three-month email retention from receipt, best-effort support wording and GitHub Issues links. Keep the three-month policy specific to email. Update the smallest relevant records, check the complete local link graph and external-link accessibility, and review desktop/narrow layouts in both themes. Apply tighten then probe and present the local preview for manual acceptance before publication.

## Cloudflare publication

Deploy only `website/` through Cloudflare Pages, using the GitHub connection scoped to this repository without a separate deployment API token. Use `main`, framework None, build command `exit 0` and output directory `website`. Set build watch paths to include only `website/*` and check that an ordinary push outside that directory skips deployment. Verify the hosted preview before binding panepeek.app. Configure permanent redirects for panepeek.com and both www aliases, preserving paths and query strings. Inspect DNS first and preserve email records. Keep native email links available without JavaScript. Verify HTTPS, nested pages/assets, unknown paths and redirect behaviour from outside the authenticated dashboard. Public repository/release access, source-control approval and the live website result retain distinct checks.

## Editing emphasis

Lead the homepage hero and metadata with editing text files while browsing, without opening another editor. Move the existing editing section before folder-layout features and point Features links on all pages to it; retain the browsing anchor. Introduce editing before dual panes in Support. Reuse existing screenshots and scripts, with responsive space below the hero caption. Keep UTF-8/1 MiB and explicit Save guidance accurate. Check all local references/fragments and desktop/narrow layouts in both themes, apply tighten/probe and present the local preview. Manual acceptance, commit/push/PR and deployment retain separate gates.

## Search and AI discovery

Use a shared full-height column layout on all four pages, allowing main content to grow and the footer to sit below it. Verify short and long content at desktop/narrow widths in both themes, plus lightbox scroll-lock and focus return.

Add canonical URLs and factual JSON-LD to Home, Support and Privacy. Use a homepage WebSite/SoftwareApplication graph and page-specific WebPage descriptions, keeping application facts aligned with visible content. Add the public crawl allowance, three-page sitemap and a concise llms.txt with discovery links. Add a root 404.html using the existing layout and theme control, with root-relative assets and noindex. Keep social-preview metadata and imagery in the separate social-preview unit.

Observe the missing metadata/files as the baseline, then parse the resulting HTML, JSON-LD, sitemap and robots rules and check the complete local asset/link graph. Serve all pages and crawler files; inspect the 404 page at desktop/narrow widths in both themes, including keyboard focus, theme persistence and no-script recovery. Use the documented Cloudflare Pages 404-file contract; verify its actual missing-route status and response after publication. Local serving alone does not establish hosted behaviour, crawler inclusion or ranking.

Apply tighten then probe, update criterion/task evidence and present the running website for manual review. Manual acceptance, the social-preview unit and source-control/publication steps retain separate gates.

## Social link previews

Add page-specific Open Graph and X large-image-card metadata to the three canonical pages. Reuse their current titles/descriptions and primary URLs. Compose a shared 1200 × 630 JPEG from the accepted logo, editing headline and native dark editing screenshot. Retain the editable artwork under design/website and keep the public site buildless.

Check metadata uniqueness, page text/canonical consistency, absolute image URLs, image type/dimensions/size, no-script availability and local HTTP responses. Review the artwork at full size and reduced preview sizes, including a central crop; confirm native screenshot provenance and inspect the raster for private data. Verify the website still renders, then apply tighten/probe and present the image for manual acceptance. Hosted crawler fetches, platform cache behaviour and actual client previews remain post-deployment checks. Commit and publication retain separate gates.

## CSS cleanup

Reorganise the shared stylesheet in one unit using the spec's responsibility order. Keep component states with their owners and width breakpoints at the end. Reduce unnecessary selector ancestry and remove redundant declarations, retaining the current editor-copy size, theme/hidden guards, modal open state and existing JavaScript hooks. Refresh stylesheet URLs on all four pages without changing their content.

Capture the current layout and computed styles before editing, then compare Home, Support, Privacy and 404 at desktop/narrow widths in both themes and on either side of each breakpoint. Compare representative full-page screenshots and verify keyboard focus, FAQ expansion, theme persistence, script-free fallback, modal scroll lock/dismissal/focus return and full-height footer layout. Apply tighten then probe, record executed checks and present the running preview for manual acceptance. Commit and publication remain separate gates.

## Privacy layout

Let the Privacy article use the shared container width and cap its policy sections at 760 px, aligned with the heading’s left edge. Combine hosting and saved-theme disclosures under Website, preserving their paragraph text and existing fragment targets. Preserve typography and shared page behaviour. Check the heading's alignment with site navigation, reading-column width and paragraph wrapping, narrow reflow, both themes, footer placement and keyboard access. Apply tighten/probe and present the local page for manual review; commit and publication retain separate gates.

## Screenshot alignment and shortcuts

Use a common visible frame ratio for the paired editing captures while retaining original image files and full-size destinations. Curate homepage highlights around navigation, editing, copied paths, hidden files and Details sizing, with a link to Support. Curate Support into grouped shortcuts sourced from app commands, native browser key handling and the usage guide. Omit well-known Finder-style and standard Mac bindings; link to Apple’s reference for those. Keep glyph alternatives, table labels and active-pane context clear.

Verify equal frame heights and caption baselines when side by side, consistent proportions when stacked, responsive tables in both themes, source accuracy and the omission of familiar bindings, full-size modal dismissal/focus return and navigation to the reference. Check other pages for shared-style regressions. Apply tighten/probe and present the local result for manual review; commit and publication remain separate gates.

## Repository documentation alignment

Keep Support’s curated shortcut list and put the full 36-action reference in docs/usage.md using the six task groups. Check all explicit app bindings and context notes. Align PRIVACY.md with the accepted public contact, provider, retention and website disclosures while preserving its file, clipboard, settings and draft details. Check source consistency, Markdown targets and repository privacy rules; apply tighten/probe before publication.

## Syntax highlighting content

Refresh both native editing captures using the standard fictional demo folder, a varied code/configuration listing and highlighted TSX (Dark) and Python (Light) drafts in Edit. Use keyboard-only capture preparation to exclude cursor glow. Preserve native pixels and document provenance; align paired frames and update their dimensions, captions and alternatives. Add a linked Support section listing the implemented languages/formats, verified against the highlighting dispatcher and A15. Check both themes, paired/stacked layouts, full-size previews, keyboard focus and local references. Apply tighten then probe and present the local preview for manual acceptance. Native app behaviour and website publication retain separate gates.

## Lossless screenshot delivery

Add lossless WebP derivatives of the four displayed homepage PNGs and use them for inline images and full-size links. Retain PNG masters and the existing native dimensions, alternatives, theme selection and lightbox behaviour. Preserve native ICC profiles, EXIF and the light design preview’s sRGB interpretation.

Verify decoded-pixel and profile identity against the PNG masters, HTTP image delivery, Light/Dark rendering, paired/stacked layouts and full-size previews. Exercise keyboard opening, dismissal, focus return and ordinary image links. Apply tighten then probe and present the running local site for manual review; commit and publication retain separate gates.

## Responsive screenshot delivery

Generate proportional 480, 800, 1200 and 1600 px previews directly from each native PNG master using Lanczos, then lossless WebP with the original ICC profile. The 1218 px design master needs only 480 and 800 px previews before its original. Add native width descriptors and sizes matching the wrapper margins, screenshot border and paired editing layout. Preserve original-resolution WebP href targets, native width/height attributes, alternatives, lazy loading and PNG masters.

Observe the full-resolution mobile baseline, then verify actual currentSrc and requested image bytes at mobile, stacked and paired widths for 1× and 2× density. Check candidates against their resampled source pixels and profiles, with no upscaling; recheck original assets, lightbox resolution, keyboard dismissal/focus return and ordinary links. Apply tighten then probe and present the running result for manual review. This unit’s commit and publication retain separate gates.
