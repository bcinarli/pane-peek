# Rendered Markdown preview

Status: Draft

Date: 2026-10-10

Bilal requested a future Markdown-specific preview that displays rendered Markdown. This is recorded for later scope and design review. Presentation controls and link/resource behaviour remain undecided.

Rendered Markdown remains [outside the MVP](../specs/001-mvp/spec.md#scope-boundaries). Accepted [T06 Markdown highlighting](../validation/t06-read-only-preview-highlighting.md#unit-13-markdown-highlighting) displays source text. This proposal does not change A15, extend T06 or authorise implementation.

## PR integration, 2026-10-14

[PR #16](https://github.com/bcinarli/pane-peek/pull/16) integrates `main` at `9e7ae66`, retaining fluid Details sizing and the editor's read-only presentation during rename. The native rename regression failed before the presentation guard was restored, then passed with the same editor and retained Undo.

Executed checks: `node scripts/test.mjs` passed 422 core and 60 app/native tests, with nine intentional gate-timeout diagnostics. Isolated review packaging, bundle plist validation and launch/process checks passed. Tighten retained the existing layout/component; probe checked editor retention and rename protection. Scope reconciliation and manual/accessibility acceptance remain pending.
