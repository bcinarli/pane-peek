# PanePeek continuation index

## What is in flight?

[Resizable browser columns (#77)](specs/001-mvp/evidence/resizable-browser-columns.md) is accepted for the reviewed scope. The [task row](specs/001-mvp/tasks.md) owns publication state.

[PR #119](https://github.com/bcinarli/pane-peek/pull/119) covers the [File information heading target](specs/001-mvp/evidence/file-information-heading-target.md), Completed/Passed for the reviewed scope; the [task row](specs/001-mvp/tasks.md) owns current state.

[Recursive current-folder search (#93)](specs/001-mvp/evidence/recursive-folder-search.md) is Completed/Passed for the reviewed scope, including compact Back/Forward spacing and expandable search. [PR #118](https://github.com/bcinarli/pane-peek/pull/118) carries publication. The [task row](specs/001-mvp/tasks.md) owns review and publication state.

[PR #109](https://github.com/bcinarli/pane-peek/pull/109) covers [Back and Forward navigation](specs/001-mvp/evidence/back-forward-navigation.md), Completed/Passed for the reviewed scope; the [task row](specs/001-mvp/tasks.md) owns publication state.

[PR #108](https://github.com/bcinarli/pane-peek/pull/108) covers [editor line numbers](specs/001-mvp/evidence/editor-line-numbers.md), Completed/Passed for the reviewed scope. The [tracker](specs/001-mvp/tasks.md) owns publication state.

[PR #107](https://github.com/bcinarli/pane-peek/pull/107) covers test coordination and CI isolation, Completed/Passed for the reviewed scope. The [tracker](specs/001-mvp/tasks.md#build-and-repository-automation) owns task state and evidence.

[PR #106](https://github.com/bcinarli/pane-peek/pull/106) covers [collapsible File information](specs/001-mvp/evidence/collapsible-file-information.md), Completed/Passed for the reviewed scope. The [tracker](specs/001-mvp/tasks.md) owns publication state.

[PR #105](https://github.com/bcinarli/pane-peek/pull/105) covers [single-pane Details width](specs/001-mvp/evidence/single-pane-details-width.md), Completed/Passed for the reviewed scope. The [decision](decisions/2026-10-22-single-pane-details-width.md) owns current sizing and fresh-window policy; the [tracker](specs/001-mvp/tasks.md) owns publication state.

[PR #104](https://github.com/bcinarli/pane-peek/pull/104) covers [same-folder copies](specs/001-mvp/evidence/same-folder-copies.md), [Duplicate](specs/001-mvp/evidence/duplicate-menu.md) and [context-menu grouping](specs/001-mvp/evidence/context-menu-grouping.md), each Completed/Passed for its reviewed scope. The [tracker](specs/001-mvp/tasks.md) owns publication state.

[PR #102](https://github.com/bcinarli/pane-peek/pull/102) covers accepted [fresh-window defaults](specs/001-mvp/evidence/fresh-single-pane-windows.md), [stable review signing](specs/001-mvp/evidence/stable-review-signing.md) and [folder-listing metadata](specs/001-mvp/evidence/directory-listing-metadata.md). The [tracker](specs/001-mvp/tasks.md) owns publication state.

[Root navigation bookmark reuse](specs/001-mvp/evidence/root-navigation-bookmark.md) is Completed/Passed for the reviewed scope. The [tracker](specs/001-mvp/tasks.md) owns publication state.

[Syntax-highlighting flashes](specs/001-mvp/evidence/syntax-highlighting-flashes.md) is Completed/Passed for the reviewed scope in [PR #99](https://github.com/bcinarli/pane-peek/pull/99). The [tracker](specs/001-mvp/tasks.md) owns publication state.

[v1.1.0](https://github.com/bcinarli/pane-peek/releases/tag/v1.1.0) is the latest public release. [Distribution evidence](specs/001-mvp/evidence/hosted-signing-notarisation.md) records verified scope and remaining limits.

[Save ownership preservation](specs/001-mvp/evidence/save-owner-preservation.md) is Completed/Passed for the reviewed scope. [The tracker](specs/001-mvp/tasks.md) owns review and publication state.

[Markdown link policy](specs/001-mvp/evidence/markdown-link-policy.md) is Completed/Passed for the reviewed scope; [the tracker](specs/001-mvp/tasks.md) owns publication state.

[Save permission preservation](specs/001-mvp/evidence/save-permission-preservation.md) is Completed/Passed for the reviewed scope; [the tracker](specs/001-mvp/tasks.md) owns publication state.

The sandbox review units are Completed/Passed for their recorded scopes in [the implementation commit](https://github.com/bcinarli/pane-peek/commit/55d79d887312349a0c874f9931e5ad545b1af826). The [access design](notes/2026-10-20-app-store-sandbox-design.md) owns the current model and compatibility limits. Production sandbox packaging is Completed/Passed in [`329c026`](https://github.com/bcinarli/pane-peek/commit/329c0261ca9f64cdaa2767a46b30e8208fedaed6) with the [current network and distribution policy](decisions/2026-10-24-github-release-updates.md).

[Additional file previews](decisions/2026-10-20-additional-file-previews.md) proceed as Markdown front matter, SVG preview/source editing, PDF, then static offline HTML. [Markdown front matter](specs/001-mvp/evidence/markdown-front-matter.md), [SVG preview/source editing](specs/001-mvp/evidence/svg-preview-source-editing.md) and [PDF preview](specs/001-mvp/evidence/pdf-preview.md) and [static HTML preview](specs/001-mvp/evidence/html-preview.md) are Completed/Passed for their presented units in [PR #78](https://github.com/bcinarli/pane-peek/pull/78). [The tracker](specs/001-mvp/tasks.md) owns review and publication gates.

| Workstream | Start here |
| --- | --- |
| [Native app MVP](specs/001-mvp/README.md) | [Tasks](specs/001-mvp/tasks.md) and [criterion verdicts](specs/001-mvp/validation.md). |
| [GitHub release updates](specs/2026-10-24-github-release-updates/README.md) | [Tasks](specs/2026-10-24-github-release-updates/tasks.md) and [criterion verdicts](specs/2026-10-24-github-release-updates/validation.md). |
| [Website](specs/2026-10-17-website/README.md) | [Tasks](specs/2026-10-17-website/tasks.md), [criterion verdicts](specs/2026-10-17-website/validation.md) and [live verification](specs/2026-10-17-website/evidence/deployed-verification.md). |

[App Store archive preparation](specs/001-mvp/evidence/app-store-archive-preparation.md) is Completed/Passed for native archiving and local Store signing/export.

## What is the next slice?

[GitHub release updates (#98)](specs/2026-10-24-github-release-updates/README.md) has an accepted download/manual-install contract and [Updates window design](design/001-mvp/README.md#updates-window). The [task row](specs/2026-10-24-github-release-updates/tasks.md) retains implementation and native-review readiness.

[Website Markdown delivery](specs/2026-10-17-website/evidence/markdown-publication.md) is live through [PR #110](https://github.com/bcinarli/pane-peek/pull/110). The [task row](specs/2026-10-17-website/tasks.md#markdown-delivery) and [validation](specs/2026-10-17-website/validation.md) retain remaining acceptance.

App Store upload and server validation await approval. The [1.1.0 (8) candidate and app record](specs/001-mvp/evidence/app-store-1-1-candidate.md) are Completed/Passed for local preparation; listing/privacy/compliance details and review submission retain separate gates.

## What binds implementation?

- [GitHub release updates](decisions/2026-10-24-github-release-updates.md) confines app-operated requests to update checking and requested downloads in GitHub builds, retaining the shared sandbox and offline preview policies.
- [HTML local assets](decisions/2026-10-20-html-local-assets.md) confines CSS, images and fonts to the HTML folder tree while retaining script and remote-request blocking.
- [MVP spec](specs/001-mvp/spec.md) and [website spec](specs/2026-10-17-website/spec.md) own requirements.
- [Decisions](decisions/README.md) own accepted choices; the [source-control decision](decisions/0002-feature-branches-and-prs.md) defines publication gates.
- [Shared validation checklist](validation/checklist.md) and [design sources](design/001-mvp/README.md) define review expectations.

## What remains open?

- [Title-bar interaction (#101)](specs/001-mvp/evidence/title-bar-interaction.md): physical gesture/control review passed; remaining layout and accessibility validation is pending.

- Native acceptance: [T18](specs/001-mvp/evidence/mvp-acceptance-build-documentation.md) is Completed/Waived for 1.0.0 (7). The [validation matrix](specs/001-mvp/validation.md) retains the unverified scope covered by the release-specific waiver.
- Distribution: [hosted release evidence](specs/001-mvp/evidence/hosted-signing-notarisation.md) retains fresh-account, native macOS 26, ZIP installation and App Store limits.
- Website: [validation](specs/2026-10-17-website/validation.md) retains live hosting acceptance, public-download availability, accessibility and actual indexing/social-client checks. Discovery files, metadata/image delivery and custom HTTP 404 checks pass. [Screenshot delivery](specs/2026-10-17-website/evidence/responsive-webp.md) retains the unverified hosted-image scope.
- [Protected-folder privacy waits](notes/0004-protected-folder-permissions.md) are confirmed; the triggering metadata call and fresh/denied-access acceptance remain open. [Rendered Markdown and additional previews](specs/001-mvp/validation.md#additional-file-previews) have separate pending acceptance.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation recipes](validation/README.md).
