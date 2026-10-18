---
task: local-homepage
verdict: Passed
closed: 2026-10-18
---

# Evidence: local-homepage

- 2026-10-17: HTTP 200; all 17 homepage references resolve locally, images load, HTML nesting/IDs/image alternatives and CSS variables pass. SHA-256 checks confirm three unchanged design assets; 110 local Markdown link targets resolve. No runtime scripts or external resources. No app code or app tests are involved.
- 2026-10-17: Agent-observed in-app browser checks pass at 1280, 836, 640, 390 and 320 px without horizontal overflow. Desktop/mobile visuals, section navigation, a full-size image link, skip-link focus and all four FAQs using Enter/Space pass; focus is visible and browser warning/error logs are empty. Measured text combinations range from 6.62:1 to 9.92:1. The 640 px check tests reflow, not actual browser zoom; VoiceOver, zoom and manual acceptance remain pending.
- 2026-10-17: Tighten/probe removed redundant styling, decorative numbering and filler, and checked launch wording, image provenance and accessible shortcut text. Repository path rules pass on all 16 changed files; Gitleaks 8.30.1 directory scan of the final worktree reports no leaks. Binary previews were inspected visually. Whitespace checks pass.

## Released-app copy and system appearance

- 2026-10-17: Pre-launch header/status, availability FAQ and closing section removed; supported-OS wording is present tense. Both App Store links use the explicitly requested `https://apps.apple.com/` placeholder. HTML/reference checks pass for all 17 references; no pre-launch text, orphaned release links, scripts or invalid CSS variable references remain.
- 2026-10-17: Agent-observed paired browser previews force only the stylesheet’s dark media-query condition for visual/contrast checks. Latte and Macchiato pass at 320 px and desktop width without horizontal overflow; all images load. Minimum tested text/button contrast is 4.79:1 in Latte and 6.62:1 in Macchiato; focus pairs exceed 3:1. All three FAQs toggle using Enter/Space in both appearances with visible 3 px focus. The unchanged live CSS media query selects Macchiato consistently with the browser’s dark preference. Actual system-theme switching, VoiceOver and browser zoom remain unexecuted.
- 2026-10-17: Tighten/probe checked theme-specific hover/focus/shadow colours, release-copy removal and the documented placeholder exception. Final path-privacy, Gitleaks 8.30.1 and whitespace checks pass. App Store listing validation remains deferred until the real URL is available.

## Local-scope closure

- 2026-10-18: Presented homepage and released-app/Latte/Macchiato revision accepted overall by Bilal. Individual VoiceOver, actual zoom and system-theme-switching outcomes remain unreported; W4 stays Pending. Publication remains separate, with real App Store URLs and native release screenshots still required.

## Manual review

Use the [preview guide](../../../../website/README.md). Review desktop/mobile layout, section navigation, full-size app previews and FAQ operation. Check keyboard/VoiceOver reading and enlarged text. Review Latte and Macchiato appearance and the released-app copy. Replace both placeholder App Store URLs before publication; illustrative imagery still needs native release screenshots.

## PR preparation

2026-10-18: Final source checks pass for all three pages, 57 local HTML references/fragments, 18 external-link targets, 143 local Markdown paths, CSS balance and both JavaScript syntax checks. The staged privacy/secret check covers 36 files with zero findings; the full committed-tree scan after updating to current main covers 383 file versions with zero findings. Retained screenshot sources and the current homepage preview have manual image provenance checks. Tighten condenses the continuation index; probe retains App Store, hosting/privacy and W4 validation limits.

Source review: [PR #43](https://github.com/bcinarli/pane-peek/pull/43), targeting `main`. Hosting/deployment and remaining W4 checks retain their separate scope.
