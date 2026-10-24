---
task: markdown-integration
verdict: Passed
closed: "2026-10-24"
---

# Markdown discovery and build integration

The [website build](../../../../scripts/website/package.json), published in [PR #110](https://github.com/bcinarli/pane-peek/pull/110), generates Markdown before CI checks; HTML metadata, response headers and llms.txt advertise the matching static documents. Visible page content is unchanged; hosted CI passes, and [publication evidence](markdown-publication.md) covers Cloudflare delivery.
