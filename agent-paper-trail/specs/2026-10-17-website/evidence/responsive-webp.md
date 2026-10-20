---
task: responsive-webp
verdict: Passed
closed: 2026-10-20
---

# Responsive screenshot delivery

Fourteen proportional WebP previews retain source colour interpretation and decode identically to their resized PNG source pixels, with PNG masters and original-resolution WebP targets unchanged.

Mobile/desktop browser checks cover 1×/2× selection, layout-matched source sizes and original-resolution keyboard previews; a fresh 390 px Retina load selects 800 px assets totalling 258,004 bytes, 74.2% below the 998,800-byte full-resolution WebP set.

Hosted delivery remains unverified; browsers may reuse larger cached candidates, while VoiceOver and actual zoom retain their W4 limits.
