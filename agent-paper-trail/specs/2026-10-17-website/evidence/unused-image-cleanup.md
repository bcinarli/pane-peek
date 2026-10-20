---
task: unused-image-cleanup
verdict: Passed
closed: 2026-10-20
---

# Unused website image cleanup

Reference: [PR #71](https://github.com/bcinarli/pane-peek/pull/71).

Three obsolete JPEGs and the unused illustrative editing PNG are removed from website/assets, reducing the directory by 882,710 bytes (862.0 KiB); the four current PNG masters and referenced WebP, logo and social-preview images remain intact.

Local page/image delivery, references and all four original-resolution previews pass, including keyboard opening, Escape dismissal and focus return.

Hosted delivery remains unverified; VoiceOver and actual zoom retain their W4 limits.
