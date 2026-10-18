---
task: copy-consistency
verdict: Passed
closed: 2026-10-18
---

# Copy consistency

2026-10-18, agent-observed: Completed sentence, paragraph and section review with the internal-doc preset. Public copy uses everyday words and consistent terms across all three pages, including metadata and image labels. Negative framing and rhetorical contrasts were removed; technical command names and the UTF-8/1 MiB limit remain precise. Product details were checked against the [app README](../../../../README.md), with privacy wording grounded in the [existing source evidence](privacy-page.md#implementation-and-factual-basis).

Home, Support and Privacy reflow at 1280 × 900 and 320 × 700 in Latte and Macchiato fixtures. All three Home and five Support FAQ answers opened using the keyboard; expanded text has no horizontal overflow. Visual review led to shorter Support questions. Final Privacy introduction and shortened Support labels also pass on the live system-dark page at 320 pixels. New screenshot alternatives and captions appear correctly in the lightbox; Features reaches the existing section.

Snapshot comparison confirms element structure and destinations are unchanged apart from copy attributes. All 74 HTML references/fragments resolve, with external-link targets retained. Tighten cut slogan-like headings and an unnecessary Privacy introduction sentence. Probe checked the copy against file/save behaviour, privacy data flows and mobile wrapping. VoiceOver, actual zoom and OS-theme switching retain their unexecuted W4 scope. All 149 local Markdown paths, 32-file path/privacy scan, Gitleaks, JavaScript syntax and whitespace checks pass. Browser warnings/errors are empty. Presented copy scope accepted overall on 2026-10-18; the hero wording revision is tracked in the next unit. No commit, push or publication performed.
