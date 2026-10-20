# PanePeek website implementation plan

The [spec](spec.md) owns the static site's current requirements. [Tasks](tasks.md) and [validation](validation.md) retain state and acceptance limits. Coding, manual review, commit/push and deployment retain separate gates; apply tighten followed by probe.

## Local homepage unit

Implement the homepage in `website/`, with static HTML/CSS and unchanged distribution copies of the accepted logo and design images. Use native HTML for navigation and the FAQ. Use concise released-app content and CSS system-appearance selection: Latte for light mode and Macchiato for dark mode. Remove pre-launch sections and use the selected download destination from the spec.

## Support page unit

Add `website/support/index.html` with concise getting-started instructions, verified shortcuts, common troubleshooting questions and an email link. Reuse shared CSS and native HTML. Add homepage navigation to Support and return navigation to Home; use the selected download destination from the spec.

## Privacy page unit

Add `website/privacy/index.html` with an app-focused policy, confirmed publisher name and source-backed explanations of local processing/storage, support correspondence and platform services. Reuse system themes and shared navigation; link Privacy in the Home and Support footers. Keep legal and operational claims proportionate to verified facts and identify remaining publication prerequisites in the records.

## Project and social links unit

Add a labelled project/social navigation group to each footer with the repository origin and supplied X/LinkedIn profile URLs. Also add the project GitHub link to each top menu and adjust header reflow for the extra item. Keep links native and styling shared, with no widgets or new dependencies.

## Native dark screenshot unit

Capture the updated native Macchiato UI from the identified app worktree using a copied bundle and isolated preferences with fictional demo files. Add a theme-aware dark hero while retaining the light hero. Replace the old dark illustrative editing preview with native light and dark editing captures, both visible in either website theme. Frame native app content below the capture title bar; remove only the cursor/glow within a bounded title-bar region and verify unchanged resolution/pixels outside it, update alternatives/captions/provenance and verify full-size navigation and responsive display.

## Page interactions unit

Add CSS smooth scrolling under the no-preference reduced-motion condition across the shared pages. Enhance homepage screenshot links with one native dialog and a small local script, retaining ordinary links as fallback. Use native modal focus and Escape handling, a Close action and outside-click dismissal; lock background scrolling while open.

## External links unit

Add native `target="_blank"` and `rel="noopener noreferrer"` to external HTTP(S) links on all three pages, with a visually hidden new-tab cue. Keep existing destinations and local/email/image behaviour.

## Copy consistency unit

Review all three pages using the internal-doc preset. Rewrite public copy, metadata and accessible labels with everyday vocabulary; remove rhetorical contrasts and staged three-step beats while preserving factual limits and exact UI command names.

## Hero and theme menu unit

Restore the preferred two-sentence hero copy. Add a native, labelled System/Light/Dark select to every footer, with a small shared script that reads the browser preference before the stylesheet and stores explicit choices. Use CSS palette selection for page colours and matching hero imagery. Keep the theme control hidden without JavaScript, retain system appearance as fallback and disclose the saved browser setting in Privacy.

## Mauve focus rings

Map the shared focus colour to the existing Mauve palette token in both themes.

## Launch content

Point all download links to GitHub Releases with accurate header labels until App Store approval. Add Cloudflare hosting and iCloud Mail disclosures, three-month email retention from receipt, best-effort support wording and GitHub Issues links. Keep the three-month policy specific to email. Update the smallest relevant records, check the complete local link graph and external-link accessibility, and review desktop/narrow layouts in both themes.

## Cloudflare publication

Deploy only `website/` through Cloudflare Pages, using the GitHub connection scoped to this repository without a separate deployment API token. Use `main`, framework None, build command `exit 0` and output directory `website`. Set build watch paths to include only `website/*` and check that an ordinary push outside that directory skips deployment.

## Editing emphasis

Lead the homepage hero and metadata with editing text files while browsing, without opening another editor. Move the existing editing section before folder-layout features and point Features links on all pages to it; retain the browsing anchor. Introduce editing before dual panes in Support. Reuse existing screenshots and scripts, with responsive space below the hero caption. Keep UTF-8/1 MiB and explicit Save guidance accurate.

## Search and AI discovery

Use a shared full-height column layout on all four pages, allowing main content to grow and the footer to sit below it.

## Social link previews

Add page-specific Open Graph and X large-image-card metadata to the three canonical pages. Reuse their current titles/descriptions and primary URLs. Compose a shared 1200 × 630 JPEG from the accepted logo, editing headline and native dark editing screenshot. Retain the editable artwork under design/website and keep the public site buildless.

## CSS cleanup

Reorganise the shared stylesheet in one unit using the spec's responsibility order. Keep component states with their owners and width breakpoints at the end. Reduce unnecessary selector ancestry and remove redundant declarations, retaining the current editor-copy size, theme/hidden guards, modal open state and existing JavaScript hooks. Refresh stylesheet URLs on all four pages without changing their content.

## Privacy layout

Let the Privacy article use the shared container width and cap its policy sections at 760 px, aligned with the heading’s left edge. Combine hosting and saved-theme disclosures under Website, preserving their paragraph text and existing fragment targets. Preserve typography and shared page behaviour.

## Screenshot alignment and shortcuts

Use a common visible frame ratio for the paired editing captures while retaining original image files and full-size destinations. Curate homepage highlights around navigation, editing, copied paths, hidden files and Details sizing, with a link to Support. Curate Support into grouped shortcuts sourced from app commands, native browser key handling and the usage guide. Omit well-known Finder-style and standard Mac bindings; link to Apple’s reference for those. Keep glyph alternatives, table labels and active-pane context clear.

## Repository documentation alignment

Keep Support’s curated shortcut list and put the full 36-action reference in docs/usage.md using the six task groups.

## Syntax highlighting content

Refresh both native editing captures using the standard fictional demo folder, a varied code/configuration listing and highlighted TSX (Dark) and Python (Light) drafts in Edit. Use keyboard-only capture preparation to exclude cursor glow. Preserve native pixels and document provenance; align paired frames and update their dimensions, captions and alternatives. Add a linked Support section listing the implemented languages/formats, verified against the highlighting dispatcher and A15.
