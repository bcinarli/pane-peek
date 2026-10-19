---
task: css-cleanup
verdict: Passed
closed: "2026-10-19"
---

# CSS cleanup

2026-10-19, agent-observed in the local in-app browser: Layout rectangles and 48 computed-style properties match the captured baseline in 40 cases. All four pages were checked at 1280 and 320 px in Light/Dark, and at 851/850, 761/760 and 581/580 px in Light, each with a 900 px viewport height. Summary-arrow styles were included. Full-page 1280 px Light screenshots of Home and 404 have identical JPEG bytes before and after. All 40 cases retain no horizontal overflow, a footer at the document bottom and separation from main content; the 320 × 600 recovery page scrolls without overlap.

2026-10-19, agent-observed: Keyboard skip navigation, Mauve focus on links/FAQ/modal controls, FAQ expansion and arrow rotation, modal focus containment, Escape dismissal, scroll unlocking and focus return pass. Dark selection persists from Home to Support; returning to System restores the current system appearance. Editor secondary copy remains 16 px. A script-free copy of the actual homepage, using the served stylesheet, retains a hidden theme control, a hidden closed dialog, a hero matching the current Dark system appearance and an operable native FAQ. No browser console errors were reported.

Tighten retains one stylesheet and existing markup/JavaScript hooks, with component states beside their base rules and no new dependencies. Probe covers breakpoint boundaries, theme selection, hidden/open guards and short-window footer behaviour. VoiceOver, actual browser zoom, OS-theme changes, browser-wide JavaScript disabling and hosted verification were not exercised by this unit; the script-free fixture is a bounded fallback check.

2026-10-19, agent-observed: Home, Support and 404 HTML differ only in the stylesheet cache version; Privacy composition is covered by [Privacy layout evidence](privacy-layout.md). JavaScript is unchanged. Repository privacy checks and Gitleaks report zero findings across 14 changed/new files. Whitespace and 164 local Markdown targets pass.
