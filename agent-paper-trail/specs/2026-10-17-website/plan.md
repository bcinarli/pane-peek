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

Deploy only the static website through Workers Static Assets. Prefer a GitHub connection scoped to this repository after reviewing the access grant; manual uploads are an alternative. Verify the hosted preview before binding panepeek.app. Configure permanent redirects for panepeek.com and both www aliases, preserving paths and query strings. Inspect DNS first and preserve email records. Verify HTTPS, nested pages/assets, unknown paths and redirect behaviour from outside the authenticated dashboard. Public repository/release access, source-control approval and the live website result retain distinct checks.
