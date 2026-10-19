---
task: search-ai-discovery
verdict: Passed
closed: "2026-10-19"
---

# Search and AI discovery

Accepted for the presented local scope on 2026-10-19. Hosted HTTP 404 verification remains pending until deployment; W18 and the broader W4 accessibility audit remain Pending.

2026-10-19, agent-observed: HTML/JSON/XML parsing passes for three distinct canonical URLs, the linked llms.txt, the WebSite/SoftwareApplication/WebPage graph and its entity identifiers. Descriptions match existing metadata. All 80 local references/fragments, unique IDs, image alternatives, crawl rules, three canonical sitemap entries and llms.txt destinations pass. The recovery page declares noindex, uses root-relative references and is excluded from the sitemap.

2026-10-19, agent-observed through local HTTP serving: Home, Support, Privacy, robots.txt, sitemap.xml, llms.txt and the directly requested 404.html return 200. Text files return text/plain and the sitemap application/xml. The local Python server uses its own error body for missing routes; this does not verify Cloudflare's custom HTTP 404 response.

2026-10-19, agent-observed in the browser: All four pages pass 16 combinations of 1280 × 1100 / 320 × 900 and Light / Dark. Footers end at the document bottom, content remains before them and no horizontal overflow appears. The 320 × 600 recovery page scrolls normally. Recovery text and button contrast is at least 4.79:1. Skip navigation, visible keyboard focus, recovery links and cross-page theme persistence pass. The screenshot dialog retains scroll lock, Escape dismissal and focus return. No browser console errors were reported.

2026-10-19, agent-observed: Gitleaks 8.30.1 and repository privacy checks pass all 16 changed/new text files with zero findings. Whitespace checks and 148 local Markdown targets pass.

Tighten retains the shared layout and native controls without new runtime dependencies. Probe covers nested-path references, crawl permission parsing, graph consistency, long-content flow and modal behaviour. Structured data uses verified product facts; llms.txt remains supplementary guidance.

Post-publication checks: actual Cloudflare missing-route status/body, crawler-file response types and CDN bot access. Search indexing and AI inclusion are not established by local checks. JavaScript-disabled browsing, VoiceOver, actual browser zoom and OS accessibility/appearance settings remain unexecuted.

## Sources

- [Google AI features guidance](https://developers.google.com/search/docs/appearance/ai-features)
- [Schema.org SoftwareApplication](https://schema.org/SoftwareApplication) and [sitemap guidance](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap)
- [llms.txt proposal](https://llmstxt.org/)
- [Cloudflare Pages serving behaviour](https://developers.cloudflare.com/pages/configuration/serving-pages/)
