---
task: external-links
verdict: Passed
closed: 2026-10-18
---

# External links

2026-10-18, agent-observed: Baseline homepage links had no new-tab target. All 18 external HTTP(S) links across Home, Support and Privacy now use native `_blank`, `noopener noreferrer` and the existing visually-hidden style for an “opens in a new tab” cue. Structural checks confirm all 39 local/email links retain their targets and all 74 href/src references/fragments resolve.

Browser checks: keyboard activation of Home GitHub, pointer activation of Support X and Privacy’s Apple policy each opened a separate tab while retaining the local page. Home–Support–Privacy–Home navigation and screenshot lightbox open/Escape/focus return pass. New-tab cues appear in accessible link names; GitHub has visible 3-pixel focus and the desktop page has no horizontal overflow. Mailto destinations are unchanged; no email client was opened. VoiceOver and remaining W4 checks remain unexecuted.

All 143 local Markdown target paths, 31 changed-file path/privacy checks, Gitleaks, JavaScript syntax and whitespace checks pass. Tighten retained native markup and shared styling; probe covered external/local/email classification, accessible names, keyboard activation and lightbox regression. Native app source, CSS and JavaScript behaviour are unchanged. Browser tab/window choice follows visitor settings. No commit, push or publication performed; presented external-link scope accepted overall on 2026-10-18.
