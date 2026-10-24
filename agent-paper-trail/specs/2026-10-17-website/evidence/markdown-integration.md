---
task: markdown-integration
verdict: Passed
closed: "2026-10-24"
---

# Markdown discovery and build integration

The [website build](../../../../scripts/website/package.json) generates Markdown before CI checks; HTML metadata, response headers and llms.txt advertise the matching static documents in local Pages. Visible page content is unchanged. Hosted CI and Cloudflare build/watch configuration remain unverified.
