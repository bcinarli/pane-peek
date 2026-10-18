---
task: hero-theme-menu
verdict: Passed
closed: "2026-10-18"
---

# Hero and theme menu

2026-10-18, agent-observed red baseline: the theme combobox was absent (count 0), and the hero used the shorter copy. The preferred “A little more room…” paragraph is restored. A labelled native System/Light/Dark select is available on all three pages; System is the initial choice and clears an explicit browser preference. Privacy explains this setting.

Live browser green checks: System matches actual dark appearance. Light switches to Latte and the light hero; Dark switches to Macchiato and its native hero. Browser theme-colour metadata follows the choice. Light persists through Home→Support and reload; Dark persists into Privacy. System survives reload as the default again. Keyboard Tab reaches the selector, arrow keys and Enter select Light, and focus is visible at 3 pixels: Macchiato Teal #8bd5ca or Latte Mauve #8839ef.

All three pages reflow in both modes at 1280 and 320 pixels. Home headers also pass at 961/960 and 836 pixels, with no logo/menu overlap or horizontal overflow; the selector is at least 79 × 44 pixels. A forced-System-light fixture confirms the light hero/palette and a working Dark override. A no-script fixture follows actual system Dark with a hidden inactive control. These fixtures do not change OS settings.

Isolated Node VM checks against the shipped controller pass for default/saved choices before DOM ready, persistence/removal, System media changes and explicit overrides. Invalid values fall back to System; blocked reads/writes retain current-page switching. These simulate storage/media failure paths; actual browser storage blocking and OS-theme switching remain unexecuted. W4 also retains VoiceOver and actual zoom checks.

Tighten kept one small script and native select, with one palette mapping through CSS. Probe covered preference errors, page/reload consistency, screenshot selection, keyboard focus and narrow headers. Palette names/values match the [official palette](https://catppuccin.com/palette/); CSS selection follows [MDN light-dark guidance](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value/light-dark). All 77 HTML references/fragments and 153 local Markdown paths resolve. Existing destinations and all 18 external-link targets are unchanged; script ordering, CSS balance, 34-file privacy/path scan, Gitleaks, JS syntax and whitespace checks pass. Browser warnings/errors are empty. Manual review pending; no native app changes, commit, push or publication performed.


## Footer placement

2026-10-18, agent-observed: the existing theme control is in each footer beside the social links, with none in the header. All three pages reflow at 1280 and 320 pixels in Light and Dark; keyboard Tab reaches the selector after LinkedIn, with a 79 × 44-pixel target. Home header/footer also fit at 836/761/760 pixels without overlap or horizontal overflow. Light persists through Home→Support; System is restored for review. Browser warnings/errors are empty.

Tighten retained the existing controller and one shared wrapping footer row, removing the header-specific spacing accommodation. Probe checked the footer location, keyboard order, narrow wrapping and persistence. The header stacks at 760 pixels again. Manual review and the unexecuted W4 checks remain pending.

Presented hero/footer theme scope accepted overall on 2026-10-18. W4 retains the unexecuted accessibility checks; publication remains separate.
