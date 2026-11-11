# PanePeek continuation index

MVP delivery is completed with explicit release-specific waivers. The [closure review](notes/2026-11-08-mvp-closure.md) records the completion basis and open acceptance work. The 001-mvp package retains the maintained native baseline and existing follow-up records.

## What is in flight?

The current development line is 1.3.0. [v1.2.0](https://github.com/bcinarli/pane-peek/releases/tag/v1.2.0) is the latest stable GitHub release; [v1.3.0-beta.1](https://github.com/bcinarli/pane-peek/releases/tag/v1.3.0-beta.1), app version 1.3.0 (11), is a prerelease excluded from Latest. [Prerelease tasks](specs/2026-11-02-github-prereleases/tasks.md) own candidate preparation and acceptance. Later candidates require their own review; prior release waivers do not carry forward.

PanePeek is available on the [App Store](https://apps.apple.com/app/panepeek/id6825031842). The [website tracker](specs/2026-10-17-website/tasks.md) owns download/content work and review state.

| Workstream | State and start point |
| --- | --- |
| [Native baseline and existing follow-ups](specs/001-mvp/README.md) | MVP delivery completed; [tasks](specs/001-mvp/tasks.md) and [criterion verdicts](specs/001-mvp/validation.md) retain individual follow-up states. |
| [Test and CI reliability](specs/2026-11-11-test-ci-reliability/README.md) | Completed. [Compiler warning, macOS tooling and video readiness validation passed](specs/2026-11-11-test-ci-reliability/validation.md). |
| [GitHub prerelease preparation](specs/2026-11-02-github-prereleases/README.md) | [Tasks](specs/2026-11-02-github-prereleases/tasks.md) and [validation](specs/2026-11-02-github-prereleases/validation.md) own beta/RC/stable preparation and candidate acceptance. |
| [GitHub release updates](specs/2026-10-24-github-release-updates/README.md) | [Tasks](specs/2026-10-24-github-release-updates/tasks.md) and [validation](specs/2026-10-24-github-release-updates/validation.md) own updater work and remaining native coverage. |
| [Git and agent worktrees](specs/2026-10-27-git-worktrees/README.md) | Scope accepted; implementation has not started. [Tasks](specs/2026-10-27-git-worktrees/tasks.md) retain coding gates; [G1–G8](specs/2026-10-27-git-worktrees/validation.md) remain Pending. |
| [External change refresh](specs/2026-11-11-external-change-refresh/README.md) | Scope proposed in [#188](https://github.com/bcinarli/pane-peek/issues/188); change-source feasibility awaits manual review. [Tasks](specs/2026-11-11-external-change-refresh/tasks.md) retain coding gates; [E1–E8](specs/2026-11-11-external-change-refresh/validation.md) remain Pending. |
| [Website](specs/2026-10-17-website/README.md) | [Tasks](specs/2026-10-17-website/tasks.md) and [validation](specs/2026-10-17-website/validation.md) own live delivery and accessibility acceptance. |

## Search and Find

[A41](specs/001-mvp/spec.md#current-folder-search) owns folder and document Find behaviour. The [task tracker](specs/001-mvp/tasks.md) owns review/publication state; [validation](specs/001-mvp/validation.md#recursive-current-folder-search) owns criterion verdicts and remaining scope.

| Record | Scope |
| --- | --- |
| [Recursive folder search](specs/001-mvp/evidence/recursive-folder-search.md) | Cancellable filename search and guarded result actions. |
| [Search relevance](specs/001-mvp/evidence/search-relevance.md) | Filename ranking and independent search ordering. |
| [Contextual Find](specs/001-mvp/evidence/contextual-find.md) | Window-scoped folder/document routing and native ownership. |
| [Bounded native Find discovery](specs/001-mvp/evidence/bounded-native-find-traversal.md) | Client discovery cost and target selection. |
| [Document Find feedback](specs/001-mvp/evidence/document-find-match-feedback.md) | Match reveal, resize retention and the blank-viewport limitation. |
| [Editor viewport stability](specs/001-mvp/evidence/editor-viewport-stability.md) | Typing, Save and Undo retention. |

## What is the next slice?

Task trackers own coding readiness, dependencies and publication state. Existing native follow-ups retain their stable paths; new feature workstreams use dated spec packages and the native baseline review gates.

- [Git access feasibility](specs/2026-10-27-git-worktrees/plan.md#git-access-feasibility) is the first planned Git unit; its [task row](specs/2026-10-27-git-worktrees/tasks.md) still requires coding approval.
- [Change-source feasibility](specs/2026-11-11-external-change-refresh/plan.md#change-source-feasibility) awaits scope acceptance and manual review; [browser listing refresh](specs/2026-11-11-external-change-refresh/plan.md#browser-listing-refresh) follows.
- [Further filename and grammar candidates #144](https://github.com/bcinarli/pane-peek/issues/144) require separately reviewed scope.

## What binds implementation?

- [Native baseline](specs/001-mvp/spec.md), including [core engineering requirements](specs/001-mvp/spec.md#core-engineering-requirements), [accessibility](specs/001-mvp/spec.md#accessibility-baseline) and [task workflow](specs/001-mvp/plan.md#task-workflow-and-exit-gates). Delivery completion does not retire these rules.
- Dedicated [update](specs/2026-10-24-github-release-updates/spec.md), [Git/worktree](specs/2026-10-27-git-worktrees/spec.md), [external change refresh](specs/2026-11-11-external-change-refresh/spec.md) (proposed), [prerelease](specs/2026-11-02-github-prereleases/README.md) and [website](specs/2026-10-17-website/spec.md) contracts for their respective scopes.
- [Decisions](decisions/README.md), including the [network/distribution boundary](decisions/2026-10-24-github-release-updates.md), [HTML local-asset policy](decisions/2026-10-20-html-local-assets.md) and [source-control gates](decisions/0002-feature-branches-and-prs.md).
- [Shared validation checklist](validation/checklist.md) and [design sources](design/001-mvp/README.md).

## What remains open?

The [closure review](notes/2026-11-08-mvp-closure.md#baseline-follow-up-acceptance) defines completed baseline scope. The [native matrix](specs/001-mvp/validation.md) owns unverified functional, accessibility, platform, icon and clean-checkout coverage, including later extensions. Scoped acceptance and published releases do not establish full-criterion passes.

- [Document Find (#182)](https://github.com/bcinarli/pane-peek/issues/182): an occasional blank viewport has no reliable reproduction or confirmed cause. [Find feedback evidence](specs/001-mvp/evidence/document-find-match-feedback.md) owns verified scope and limitations.
- [Protected-folder privacy waits](notes/0004-protected-folder-permissions.md) retain the triggering-metadata and fresh/denied-access questions.
- [Website validation](specs/2026-10-17-website/validation.md) retains live/accessibility and discovery-client checks; [screenshot delivery](specs/2026-10-17-website/evidence/responsive-webp.md) retains its hosted-image limits.

The [code-quality plan](specs/001-mvp/2026-10-30-code-quality-plan.md) owns remediation scope; its [task rows](specs/001-mvp/tasks.md#2026-10-30-code-quality-remediation) own scoped acceptance and publication. Unit acceptance does not establish whole-app acceptance.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation index](validation/README.md).
