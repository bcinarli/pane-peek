# PanePeek continuation index

MVP delivery is completed with explicit release-specific waivers. The [closure review](notes/2026-11-08-mvp-closure.md) records the completion basis and open acceptance work. The 001-mvp package retains the maintained native baseline and existing follow-up records.

## What is in flight?

[CLI and native path opening (#132)](specs/2026-11-08-cli-support/README.md) has accepted native opening, a bundled launcher and app-menu setup. Its [tasks](specs/2026-11-08-cli-support/tasks.md) track publication and remaining review.

The current development line is 1.3.0. [v1.2.0](https://github.com/bcinarli/pane-peek/releases/tag/v1.2.0) is the latest stable GitHub release; [v1.3.0-beta.1](https://github.com/bcinarli/pane-peek/releases/tag/v1.3.0-beta.1), app version 1.3.0 (11), is a prerelease excluded from Latest. [Prerelease tasks](specs/2026-11-02-github-prereleases/tasks.md) own candidate preparation and acceptance. Later candidates require their own review; prior release waivers do not carry forward.

[Search relevance (#130)](specs/001-mvp/evidence/search-relevance.md) and [native Find match reveal and resizing (#182)](specs/001-mvp/evidence/document-find-match-feedback.md) are accepted in [PR #183](https://github.com/bcinarli/pane-peek/pull/183). #182 retains transient blank feedback after rapid mode/width/query changes. The [task tracker](specs/001-mvp/tasks.md) owns unit state; [A41](specs/001-mvp/validation.md#recursive-current-folder-search) retains broader acceptance limits.

PanePeek is available on the [App Store](https://apps.apple.com/app/panepeek/id6825031842). The [website tracker](specs/2026-10-17-website/tasks.md) owns download/content work and its review state; the [earlier Store candidate](specs/001-mvp/evidence/app-store-1-1-candidate.md) retains its local-preparation scope.

| Workstream | State and start point |
| --- | --- |
| [Native baseline and existing follow-ups](specs/001-mvp/README.md) | MVP delivery completed; [tasks](specs/001-mvp/tasks.md) and [criterion verdicts](specs/001-mvp/validation.md) retain individual follow-up states. |
| [GitHub prerelease preparation](specs/2026-11-02-github-prereleases/README.md) | [Tasks](specs/2026-11-02-github-prereleases/tasks.md) and [validation](specs/2026-11-02-github-prereleases/validation.md) own beta/RC/stable preparation and candidate acceptance. |
| [GitHub release updates](specs/2026-10-24-github-release-updates/README.md) | [Tasks](specs/2026-10-24-github-release-updates/tasks.md) and [validation](specs/2026-10-24-github-release-updates/validation.md) own updater work and remaining native coverage. |
| [Git and agent worktrees](specs/2026-10-27-git-worktrees/README.md) | Scope accepted; implementation has not started. [Tasks](specs/2026-10-27-git-worktrees/tasks.md) retain coding gates; [G1–G8](specs/2026-10-27-git-worktrees/validation.md) remain Pending. |
| [Website](specs/2026-10-17-website/README.md) | [Tasks](specs/2026-10-17-website/tasks.md) and [validation](specs/2026-10-17-website/validation.md) own live delivery and accessibility acceptance. |

## What is the next slice?

Choose a task from its owning tracker and verify dependencies, approval and published changes before coding. Existing native follow-ups retain their stable paths; new feature workstreams use dated spec packages.

- [Find feedback #182](specs/001-mvp/evidence/document-find-match-feedback.md) retains fault scope beyond the accepted unit; further correction needs a bounded coding unit and manual review.
- [Git access feasibility](specs/2026-10-27-git-worktrees/plan.md#git-access-feasibility) is the first planned Git unit; its [task row](specs/2026-10-27-git-worktrees/tasks.md) still requires coding approval.
- [Further filename and grammar candidates #144](https://github.com/bcinarli/pane-peek/issues/144) require separately reviewed scope.

## What binds implementation?

- [Native baseline](specs/001-mvp/spec.md), including [core engineering requirements](specs/001-mvp/spec.md#core-engineering-requirements), [accessibility](specs/001-mvp/spec.md#accessibility-baseline) and [task workflow](specs/001-mvp/plan.md#task-workflow-and-exit-gates). Delivery completion does not retire these rules.
- Dedicated [update](specs/2026-10-24-github-release-updates/spec.md), [Git/worktree](specs/2026-10-27-git-worktrees/spec.md), [prerelease](specs/2026-11-02-github-prereleases/README.md) and [website](specs/2026-10-17-website/spec.md) contracts for their respective scopes.
- [Decisions](decisions/README.md), including the [network/distribution boundary](decisions/2026-10-24-github-release-updates.md), [HTML local-asset policy](decisions/2026-10-20-html-local-assets.md) and [source-control gates](decisions/0002-feature-branches-and-prs.md).
- [Shared validation checklist](validation/checklist.md) and [design sources](design/001-mvp/README.md).

## What remains open?

The five baseline follow-up entries are Completed/Passed in the [task tracker](specs/001-mvp/tasks.md), with their accepted scope indexed by the [closure review](notes/2026-11-08-mvp-closure.md#baseline-follow-up-acceptance). The [native matrix](specs/001-mvp/validation.md) retains incomplete functional, accessibility, platform, icon and clean-checkout checks, including later extensions. Published releases and accepted units do not establish full-criterion passes.

- [Protected-folder privacy waits](notes/0004-protected-folder-permissions.md) retain the triggering-metadata and fresh/denied-access questions.
- [Website validation](specs/2026-10-17-website/validation.md) retains live/accessibility and discovery-client checks; [screenshot delivery](specs/2026-10-17-website/evidence/responsive-webp.md) retains its hosted-image limits.

The accepted [code-quality cluster plan](specs/001-mvp/2026-10-30-code-quality-plan.md) has thirteen accepted units across six clusters. Their [task rows](specs/001-mvp/tasks.md#2026-10-30-code-quality-remediation) retain publication references and do not establish whole-app acceptance.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation recipes](validation/README.md).
