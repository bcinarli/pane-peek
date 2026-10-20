---
task: lossless-webp
verdict: Passed
closed: 2026-10-20
---

# Lossless screenshot delivery

Reference: [PR #71](https://github.com/bcinarli/pane-peek/pull/71).

Full-resolution WebP derivatives and full-size links retain the four PNG masters’ dimensions, decoded pixels and colour interpretation; their combined size is 998,800 bytes, 50.8% below the 2,029,152-byte PNG set.

Local image delivery, full-size keyboard previews and ordinary-link fallback checks pass in both themes at desktop and narrow widths.

Hosted delivery remains unverified; VoiceOver and actual zoom retain their existing W4 limits.
