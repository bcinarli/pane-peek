# PanePeek continuation index

## What is in flight?

The sandbox review units are Completed/Passed for their recorded scopes in [the implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826). The [access design](notes/2026-10-20-app-store-sandbox-design.md) owns the current model and compatibility limits. Production packaging still requires migration readiness.

| Workstream | Start here |
| --- | --- |
| [Native app MVP](specs/001-mvp/README.md) | [Tasks](specs/001-mvp/tasks.md) and [criterion verdicts](specs/001-mvp/validation.md). |
| [Website](specs/2026-10-17-website/README.md) | [Tasks](specs/2026-10-17-website/tasks.md), [criterion verdicts](specs/2026-10-17-website/validation.md) and [live verification](specs/2026-10-17-website/evidence/deployed-verification.md). |

## What is the next slice?

[Shared sandbox distribution readiness](specs/001-mvp/plan.md#shared-sandbox-distribution-readiness) requires settings and saved-location migration before production packaging changes. GitHub and Store releases will share sandbox behaviour, with separate signing and distribution pipelines. Use the owning task tracker and obtain coding approval before implementation.

## What binds implementation?

- [MVP spec](specs/001-mvp/spec.md) and [website spec](specs/2026-10-17-website/spec.md) own requirements.
- [Decisions](decisions/README.md) own accepted choices; the [source-control decision](decisions/0002-feature-branches-and-prs.md) defines publication gates.
- [Shared validation checklist](validation/checklist.md) and [design sources](design/001-mvp/README.md) define review expectations.

## What remains open?

- Native acceptance: [T18](specs/001-mvp/evidence/mvp-acceptance-build-documentation.md) is Completed/Waived for 1.0.0 (7). The [validation matrix](specs/001-mvp/validation.md) retains the unverified scope covered by the release-specific waiver.
- Distribution: [hosted release evidence](specs/001-mvp/evidence/hosted-signing-notarisation.md) retains browser-quarantine installation, public distribution and App Store limits.
- Website: [validation](specs/2026-10-17-website/validation.md) retains live hosting acceptance, public-download availability, accessibility and actual indexing/social-client checks. Discovery files, metadata/image delivery and custom HTTP 404 checks pass. [Screenshot delivery](specs/2026-10-17-website/evidence/responsive-webp.md) retains the unverified hosted-image scope.
- [Protected-folder permissions](notes/0004-protected-folder-permissions.md) need investigation. [Rendered Markdown](notes/0006-rendered-markdown-preview.md) has an implemented preview path while product-scope reconciliation remains pending.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation recipes](validation/README.md).
