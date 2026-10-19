---
task: privacy-layout
verdict: Passed
closed: "2026-10-19"
---

# Privacy layout

- Results: Eight Light/Dark cases at 1280, 850, 760 and 320 px pass: standard 1120 px heading, seven left-aligned policy sections capped at 760 px, no overflow and correct footer placement. Disclosure text, fragments, labels, keyboard access and theme controls pass. Privacy/secrets, links and whitespace checks pass.
- Reference: [PR #61](https://github.com/bcinarli/pane-peek/pull/61).
- Limits: VoiceOver and actual browser zoom are untested.
