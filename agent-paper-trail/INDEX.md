# PanePeek continuation index

## What is in flight?

[Website syntax highlighting content](specs/2026-10-17-website/evidence/syntax-highlighting-content.md) is Completed/Passed for the accepted code-editing captures and supported-language list. Publication is pending.

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

- Native acceptance: [T18](specs/001-mvp/plan.md#t18-mvp-acceptance-and-build-documentation) owns app-wide accessibility and production icon acceptance. [About](specs/001-mvp/evidence/app-information.md) and [Open in Finder](specs/001-mvp/evidence/open-in-finder.md) retain manual checks.
- Distribution: [hosted release evidence](specs/001-mvp/evidence/hosted-signing-notarisation.md) retains browser-quarantine installation, public distribution and App Store limits.
- Website: [validation](specs/2026-10-17-website/validation.md) retains live hosting acceptance, public-download availability, accessibility and actual indexing/social-client checks. Discovery files, metadata/image delivery and custom HTTP 404 checks pass.
- [Protected-folder permissions](notes/0004-protected-folder-permissions.md) need investigation. [Rendered Markdown](notes/0006-rendered-markdown-preview.md) is a draft outside the MVP.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation recipes](validation/README.md).
