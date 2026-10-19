---
task: social-previews
verdict: Passed
closed: "2026-10-19"
---

# Social link previews

Accepted for the presented local metadata and artwork scope on 2026-10-19. Hosted platform verification remains pending.

2026-10-19, agent-observed: Home, Support and Privacy each expose 15 unique Open Graph/X tags in the initial HTML. Titles/descriptions match each page, og:url matches its canonical and both image URLs use the primary HTTPS domain. Image type, dimensions and alternatives are consistent. All 63 page references resolve locally. Page bodies and the 404 file remain unchanged.

2026-10-19, agent-observed through local HTTP serving: All three pages and the shared image return 200. The image returns image/jpeg, is 1200 × 630 and contains 48,257 bytes. Preview metadata is present in the document head. Browser inspection confirms the expected titles, card type and tag counts, with no horizontal overflow or reported console errors.

2026-10-19, agent-observed visual review: Branding and headline remain readable at 600 × 315 and within a central 630 × 630 crop. The JPEG uses the accepted SVG geometry and native dark editing capture with fictional sample files. The visible raster contains no private information. The editable source and its local image references are outside the deployed website directory.

Tighten retains one shared raster and static metadata without new runtime code or dependencies. Probe checks image response type/size, page/canonical consistency, duplicate tags, no-script availability, reduced/cropped legibility and native asset provenance. Hosted crawler fetches, platform caches and actual WhatsApp, X, LinkedIn and Bluesky previews remain post-deployment checks.

2026-10-19, agent-observed: Repository privacy checks and Gitleaks 8.30.1 report zero findings across 14 changed/new files. The JPEG is the single binary file and was visually inspected. Whitespace and 160 local Markdown targets pass.

## Sources

- [Open Graph protocol](https://ogp.me/)
- [LinkedIn sharing requirements](https://www.linkedin.com/help/linkedin/answer/a521928)
- [Bluesky website-card guidance](https://github.com/bluesky-social/bsky-docs/blob/main/docs/advanced-guides/posts.md)
- [Editable artwork and asset provenance](../../../design/website/README.md)
