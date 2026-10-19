---
task: syntax-highlighting-content
verdict: Passed
closed: 2026-10-19
---

# Syntax highlighting content

Publication: [PR #65](https://github.com/bcinarli/pane-peek/pull/65).

## Assets

- `app-edit-dark.png`: native Macchiato capture editing TypeScript/TSX.
- `app-edit-light.png`: native Light capture editing Python.

Both show PanePeek 1.0.0 (5), fictional code/configuration files and an unsaved draft with Save available. The 2436 × 1200 PNGs preserve native capture pixels and colour profiles without retouching. Cursor/glow and personal owner/group fields are absent. Inline framing omits the 104-pixel title bar; full-size images retain it.

## Validation

Checks executed on 2026-10-19, agent-observed:

- Support covers all 25 highlighting language/format groups and 43 dispatched extension aliases, plus build/shell filename recognition, against `SyntaxHighlighting.swift` and A15. Alternatives and captions match the TSX/Python images.
- Home and Support pass 12 Light/Dark layout cases at 1280, 850 and 320 pixels without horizontal overflow. Paired frames and captions align; images stack at 850 pixels.
- Full-size images load at native dimensions. Keyboard opening, Escape dismissal, focus return and the Support-section link pass; keyboard focus has a visible 3-pixel Mauve outline.
- PNG/source comparisons find zero decoded RGB differences. Visual checks find no cursor/glow or personal owner/group fields.
- All 77 local HTML references and 97 changed-document Markdown targets resolve. Changed-file privacy checks cover 14 files without findings; website and paper-trail Gitleaks 8.30.1 and whitespace checks pass. Browser warning/error logs are empty.

## Limitations

- The installed capture build classifies `.ts` as video on this Mac. TSX and Python text editing are verified; `.ts` classification needs a separate app follow-up.
- VoiceOver and actual browser enlargement remain unverified under W4.
- Native regression tests were not run; app source is unchanged.
