# PanePeek continuation index

## What is in flight?

[Lossless screenshot delivery](specs/2026-10-17-website/evidence/lossless-webp.md) is Completed/Passed for the presented local scope. PNG masters retain native pixels and colour profiles; hosted delivery remains unverified.

[CI workload isolation](specs/001-mvp/plan.md#ci-workload-isolation) is Completed/Passed for its accepted scope, with local and hosted validation. Published in [PR #70](https://github.com/bcinarli/pane-peek/pull/70); [evidence](specs/001-mvp/evidence/ci-workload-isolation.md) retains the outcome.

[TypeScript preview classification](specs/001-mvp/evidence/typescript-classification.md) is Completed/Passed for `.ts`/`.mts` text routing and `.mjs` coverage. Published in [PR #67](https://github.com/bcinarli/pane-peek/pull/67), targeting `main`.

[Consistent confirmation sheets](specs/001-mvp/plan.md#consistent-confirmation-sheets-follow-up) is Completed/Passed for its presented scope. Unsaved-edit and transfer-collision prompts share adaptive styling with a trailing default action. [Evidence](specs/001-mvp/evidence/consistent-confirmation-sheets.md) retains validation and remaining accessibility checks. Published in [PR #66](https://github.com/bcinarli/pane-peek/pull/66), targeting `main`.

[Website syntax highlighting content](specs/2026-10-17-website/evidence/syntax-highlighting-content.md) is Completed/Passed for the accepted code-editing captures and supported-language list. Published in [PR #65](https://github.com/bcinarli/pane-peek/pull/65), targeting `main`.

| Workstream | Start here |
| --- | --- |
| [Native app MVP](specs/001-mvp/README.md) | [Tasks](specs/001-mvp/tasks.md) and [criterion verdicts](specs/001-mvp/validation.md). |
| [Website](specs/2026-10-17-website/README.md) | [Tasks](specs/2026-10-17-website/tasks.md), [criterion verdicts](specs/2026-10-17-website/validation.md) and [live verification](specs/2026-10-17-website/evidence/deployed-verification.md). |

## What is the next slice?

Use the owning task tracker to select the next reviewed unit. Confirm required dependencies are on `main` and obtain coding approval before implementation.

## What binds implementation?

- [MVP spec](specs/001-mvp/spec.md) and [website spec](specs/2026-10-17-website/spec.md) own requirements.
- [Decisions](decisions/README.md) own accepted choices; the [source-control decision](decisions/0002-feature-branches-and-prs.md) defines publication gates.
- [Shared validation checklist](validation/checklist.md) and [design sources](design/001-mvp/README.md) define review expectations.

## What remains open?

- Native acceptance: [T18](specs/001-mvp/evidence/mvp-acceptance-build-documentation.md) is Completed/Waived for 1.0.0 (7). The [validation matrix](specs/001-mvp/validation.md) retains the unverified scope covered by the release-specific waiver.
- Distribution: [hosted release evidence](specs/001-mvp/evidence/hosted-signing-notarisation.md) retains browser-quarantine installation, public distribution and App Store limits.
- Website: [validation](specs/2026-10-17-website/validation.md) retains live hosting acceptance, public-download availability, accessibility and actual indexing/social-client checks. Discovery files, metadata/image delivery and custom HTTP 404 checks pass.
- [Protected-folder permissions](notes/0004-protected-folder-permissions.md) need investigation. [Rendered Markdown](notes/0006-rendered-markdown-preview.md) is a draft outside the MVP.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation recipes](validation/README.md).
