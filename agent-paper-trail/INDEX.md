# PanePeek continuation index

## What is in flight?

The sandbox review units are Completed/Passed for their recorded scopes in [the implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826). The [access design](notes/2026-10-20-app-store-sandbox-design.md) owns the current model and compatibility limits. Production sandbox packaging is Completed/Passed in [`329c026`](https://github.com/bcinarli/pane-peek/commit/329c0261ca9f64cdaa2767a46b30e8208fedaed6) with the [current distribution and WebKit capability policy](decisions/2026-10-20-webkit-sandbox-capability.md).

[Additional file previews](decisions/2026-10-20-additional-file-previews.md) proceed as Markdown front matter, SVG preview/source editing, PDF, then static offline HTML. [Markdown front matter](specs/001-mvp/evidence/markdown-front-matter.md), [SVG preview/source editing](specs/001-mvp/evidence/svg-preview-source-editing.md) and [PDF preview](specs/001-mvp/evidence/pdf-preview.md) and [static HTML preview](specs/001-mvp/evidence/html-preview.md) are Completed/Passed for their presented units in [PR #78](https://github.com/bcinarli/pane-peek/pull/78). [The tracker](specs/001-mvp/tasks.md) owns review and publication gates.

| Workstream | Start here |
| --- | --- |
| [Native app MVP](specs/001-mvp/README.md) | [Tasks](specs/001-mvp/tasks.md) and [criterion verdicts](specs/001-mvp/validation.md). |
| [Website](specs/2026-10-17-website/README.md) | [Tasks](specs/2026-10-17-website/tasks.md), [criterion verdicts](specs/2026-10-17-website/validation.md) and [live verification](specs/2026-10-17-website/evidence/deployed-verification.md). |

[App Store archive preparation](specs/001-mvp/evidence/app-store-archive-preparation.md) is Completed/Passed for native archiving and local Store signing/export.

## What is the next slice?

App Store upload and server validation await approval. The [1.1.0 (8) candidate and app record](specs/001-mvp/evidence/app-store-1-1-candidate.md) are Completed/Passed for local preparation; listing/privacy/compliance details, review submission and hosted downloads retain separate gates.

## What binds implementation?

- [HTML local assets](decisions/2026-10-20-html-local-assets.md) confines CSS, images and fonts to the HTML folder tree while retaining script and remote-request blocking.
- [MVP spec](specs/001-mvp/spec.md) and [website spec](specs/2026-10-17-website/spec.md) own requirements.
- [Decisions](decisions/README.md) own accepted choices; the [source-control decision](decisions/0002-feature-branches-and-prs.md) defines publication gates.
- [Shared validation checklist](validation/checklist.md) and [design sources](design/001-mvp/README.md) define review expectations.

## What remains open?

- Native acceptance: [T18](specs/001-mvp/evidence/mvp-acceptance-build-documentation.md) is Completed/Waived for 1.0.0 (7). The [validation matrix](specs/001-mvp/validation.md) retains the unverified scope covered by the release-specific waiver.
- Distribution: [hosted release evidence](specs/001-mvp/evidence/hosted-signing-notarisation.md) retains browser-quarantine installation, public distribution and App Store limits.
- Website: [validation](specs/2026-10-17-website/validation.md) retains live hosting acceptance, public-download availability, accessibility and actual indexing/social-client checks. Discovery files, metadata/image delivery and custom HTTP 404 checks pass. [Screenshot delivery](specs/2026-10-17-website/evidence/responsive-webp.md) retains the unverified hosted-image scope.
- [Root navigation under remembered access](https://github.com/bcinarli/pane-peek/issues/79) can fail until explicit folder selection; the cause remains unresolved.
- [Protected-folder permissions](notes/0004-protected-folder-permissions.md) need investigation. [Rendered Markdown and additional previews](specs/001-mvp/validation.md#additional-file-previews) have separate pending acceptance.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation recipes](validation/README.md).
