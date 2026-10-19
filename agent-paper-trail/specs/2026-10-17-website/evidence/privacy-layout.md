---
task: privacy-layout
verdict: Passed
closed: "2026-10-19"
---

# Privacy layout

Publication: [PR #61](https://github.com/bcinarli/pane-peek/pull/61), targeting `main`.

2026-10-19, agent-observed in the local in-app browser: Eight cases at 1280, 850, 760 and 320 px in Light/Dark pass. The heading aligns with the shared navigation container and measures 1120 px at desktop width. All seven policy sections align with the heading’s left edge and retain a 760 px maximum with responsive shrinkage. No horizontal overflow; the footer remains at the document bottom.

2026-10-19, agent-observed: The Website section contains both hosting and saved-theme disclosures. All Privacy paragraph text is unchanged. Existing hosting/theme fragment targets, unique IDs and section labels pass; all 74 local HTML references/fragments resolve. Skip navigation focuses main and keyboard navigation retains visible 3 px Mauve focus. System appearance is restored; no console errors are reported.

Tighten removes unnecessary centring and a separate disclosure heading without adding selectors or runtime behaviour. Probe covers desktop/narrow alignment, both themes, bounded reading width, native labels, fragment preservation and footer placement. VoiceOver and actual browser zoom were not exercised.

2026-10-19, agent-observed: Repository privacy/Gitleaks checks pass across 14 changed/new files with zero findings. Whitespace and all 164 local Markdown targets pass.
