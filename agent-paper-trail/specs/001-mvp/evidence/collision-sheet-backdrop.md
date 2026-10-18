---
task: collision-sheet-backdrop
verdict: Passed
closed: 2026-10-18
---

# Attached collision-sheet backdrop

## Observed gap (2026-10-18)

Agent-observed native presentation shows a neutral grey collision-sheet background when attached to the browser, despite the accepted Dark Mantle role. The horizontal row, active Mauve button and dark label render correctly. Earlier standalone Light/Dark fixture renders did not expose the attached-window difference.

The owned content view now paints the adaptive floating role and invalidates its drawing when effective appearance changes. Native sheet material no longer supplies the content backdrop. Transfer handling and the horizontal controls are retained.

## Executed checks (2026-10-18)

- The existing 15 native prompt, accent-control and browser-lifecycle tests pass. No new behaviour test was added for this presentation-only change; the previously observed attached grey sheet supplies the visual baseline.
- A temporary native fixture rendered the same attached sheet through Dark, Light and Dark again. Agent visual inspection confirms Mantle in Dark, the native Light role and repainting on return to Dark. The fixture helper was removed after inspection.
- App packaging passes. In the isolated running review app, the attached Dark sheet shows Mantle with dark Mauve-button text; Escape cancels and reopening preserves the horizontal row, name focus and actions. Full VoiceOver/settings checks remain pending.

Tighten keeps one private content view with direct drawing; probe checks dynamic repainting and retained native interaction. The presented backdrop unit is accepted overall; full VoiceOver/settings outcomes remain unreported.
