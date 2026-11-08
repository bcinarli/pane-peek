# MVP closure review

Status: Completed for MVP delivery, with release-specific waivers

Review date: 2026-11-08

## Completion basis

MVP delivery is complete. The [task tracker](../specs/001-mvp/tasks.md) records T01–T17, T19 and T20 as Completed/Passed. T18 is Completed/Waived for 1.0.0 (7), supported by its [acceptance evidence](../specs/001-mvp/evidence/mvp-acceptance-build-documentation.md) and [accepted waiver](../decisions/2026-10-19-mvp-release-acceptance-waivers.md). The [completion contract](../specs/001-mvp/spec.md#validation-and-completion) explicitly permits release-specific waivers for unverified checks.

GitHub release metadata confirms the published release line:

| Release | Delivery record |
| --- | --- |
| [v1.0.0](https://github.com/bcinarli/pane-peek/releases/tag/v1.0.0) | Shipped MVP; [candidate evidence](../specs/001-mvp/evidence/final-release-candidate.md). |
| [v1.1.0](https://github.com/bcinarli/pane-peek/releases/tag/v1.1.0) | Published follow-up; [download and installation evidence](../specs/001-mvp/evidence/hosted-signing-notarisation.md). |
| [v1.2.0](https://github.com/bcinarli/pane-peek/releases/tag/v1.2.0) | Latest stable release at review; [candidate/download evidence](../specs/001-mvp/evidence/github-1-2-candidate.md) and [separate release waiver](../decisions/2026-10-26-1-2-release-acceptance-waivers.md). |
| [v1.3.0-beta.1](https://github.com/bcinarli/pane-peek/releases/tag/v1.3.0-beta.1) | Published prerelease, excluded from Latest; [candidate evidence](../specs/2026-11-02-github-prereleases/evidence/beta-1-3-0.md). Stable 1.3.0 acceptance remains separate. |

## Baseline follow-up acceptance

All five baseline entries are Completed/Passed, with acceptance recorded on 2026-11-08:

| Task | Accepted scope |
| --- | --- |
| [Title-bar interaction](../specs/001-mvp/evidence/title-bar-interaction.md) | Native gestures, configured double-click actions, layout and affected accessibility/platform checks. |
| [T21 app information](../specs/001-mvp/evidence/app-information.md) | App information and documentation, including accessible About and browser/draft isolation. |
| [Reveal in Finder](../specs/001-mvp/evidence/open-in-finder.md) | Native opening of directories and revealing of listed files/links. |
| [Selective CodeQL](../specs/001-mvp/evidence/selective-codeql.md) | Main coverage/uploads, hosted PR scan/skip behaviour and weekly execution. |
| [Shared sandbox distribution](../specs/001-mvp/evidence/shared-sandbox-distribution.md) | Shipped GitHub and App Store distribution scope. |

## What remains open

The [native validation matrix](../specs/001-mvp/validation.md) remains authoritative for coverage outside those accepted task scopes. A36–A42 and later changes to earlier criteria retain their own evidence and verdicts; neither the 1.0.0 nor 1.2.0 waiver covers 1.3.0.

[Find feedback #182](../specs/001-mvp/evidence/document-find-match-feedback.md) retains an open fault beyond its accepted match-reveal/resize unit. The [update](../specs/2026-10-24-github-release-updates/validation.md), [Git/worktree](../specs/2026-10-27-git-worktrees/validation.md) and [website](../specs/2026-10-17-website/validation.md) packages retain separate acceptance ownership.

## Continuing development

The 001-mvp package remains the maintained native baseline and owner of its existing follow-up rows, preserving record names, criterion IDs and review bindings. It includes reviewed post-MVP requirements and is not a frozen snapshot of 1.0.0. Its engineering, accessibility and coding/manual-review gates remain binding. Use dated packages for new feature workstreams and the [continuation index](../INDEX.md) to select current work.
