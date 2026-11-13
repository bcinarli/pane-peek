# PanePeek continuation index

## What is in flight?

| Workstream | State and start point |
| --- | --- |
| [Native baseline and existing follow-ups](specs/001-mvp/README.md) | [Tasks](specs/001-mvp/tasks.md) and [validation](specs/001-mvp/validation.md) track native follow-ups. |
| [CLI and native path opening (#132)](specs/2026-11-08-cli-support/README.md) | [Tasks](specs/2026-11-08-cli-support/tasks.md) track manual review and publication. [Validation](specs/2026-11-08-cli-support/validation.md) tracks criterion coverage. |
| [Test and CI reliability](specs/2026-11-11-test-ci-reliability/README.md) | Completed. [Compiler warning, macOS tooling and video readiness validation passed](specs/2026-11-11-test-ci-reliability/validation.md). |
| [GitHub prerelease preparation](specs/2026-11-02-github-prereleases/README.md) | [Tasks](specs/2026-11-02-github-prereleases/tasks.md) and [validation](specs/2026-11-02-github-prereleases/validation.md) own beta/RC/stable preparation and candidate acceptance. |
| [GitHub release updates](specs/2026-10-24-github-release-updates/README.md) | [Tasks](specs/2026-10-24-github-release-updates/tasks.md) and [validation](specs/2026-10-24-github-release-updates/validation.md) own updater work and remaining native coverage. |
| [Git and agent worktrees](specs/2026-10-27-git-worktrees/README.md) | Scope accepted; implementation has not started. [Tasks](specs/2026-10-27-git-worktrees/tasks.md) retain coding gates; [G1–G8](specs/2026-10-27-git-worktrees/validation.md) remain Pending. |
| [External change refresh](specs/2026-11-11-external-change-refresh/README.md) | Scope proposed in [#188](https://github.com/bcinarli/pane-peek/issues/188); change-source feasibility awaits manual review. [Tasks](specs/2026-11-11-external-change-refresh/tasks.md) retain coding gates; [E1–E8](specs/2026-11-11-external-change-refresh/validation.md) remain Pending. |
| [Highlighting coverage](specs/2026-11-11-highlighting-coverage/README.md) | Scope proposed for [#144](https://github.com/bcinarli/pane-peek/issues/144); alias registration is on `main` with H9 Pending. [Tasks](specs/2026-11-11-highlighting-coverage/tasks.md) retain coding gates; [H1–H9](specs/2026-11-11-highlighting-coverage/validation.md) remain Pending. |
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

Check the owning tracker for readiness, dependencies and publication. Apply the [shared unit review rules](engineering-and-review.md#task-review).

- [Git access feasibility](specs/2026-10-27-git-worktrees/plan.md#git-access-feasibility) is the first planned Git unit; its [task row](specs/2026-10-27-git-worktrees/tasks.md) still requires coding approval.
- [Change-source feasibility](specs/2026-11-11-external-change-refresh/plan.md#change-source-feasibility) awaits scope acceptance and manual review; [browser listing refresh](specs/2026-11-11-external-change-refresh/plan.md#browser-listing-refresh) follows.
- [Alias registration](specs/2026-11-11-highlighting-coverage/plan.md#alias-registration) is on `main`; scope acceptance and H9 ([#203](https://github.com/bcinarli/pane-peek/issues/203), signed Release comparison) remain before its dependent units. The remaining [#144](https://github.com/bcinarli/pane-peek/issues/144) units follow as separate PRs.

## What binds implementation?

- [Shared engineering and review rules](engineering-and-review.md) for every workstream, including [feature performance checks](engineering-and-review.md#performance-checks-for-feature-development).
- [Native product baseline](specs/001-mvp/spec.md), including [native accessibility](specs/001-mvp/spec.md#accessibility-baseline).
- Dedicated [update](specs/2026-10-24-github-release-updates/spec.md), [Git/worktree](specs/2026-10-27-git-worktrees/spec.md), [external change refresh](specs/2026-11-11-external-change-refresh/spec.md) (proposed), [highlighting coverage](specs/2026-11-11-highlighting-coverage/spec.md) (proposed), [prerelease](specs/2026-11-02-github-prereleases/README.md) and [website](specs/2026-10-17-website/spec.md) contracts for their respective scopes.
- [Decisions](decisions/README.md), including the [network/distribution boundary](decisions/2026-10-24-github-release-updates.md), [HTML local-asset policy](decisions/2026-10-20-html-local-assets.md) and [source-control gates](decisions/0002-feature-branches-and-prs.md).
- [Shared validation checklist](validation/checklist.md) and [design sources](design/001-mvp/README.md).

## What remains open?

The [native matrix](specs/001-mvp/validation.md) tracks unverified functional, accessibility, platform, icon and clean-checkout coverage.

- [Document Find (#182)](https://github.com/bcinarli/pane-peek/issues/182): an occasional blank viewport has no reliable reproduction or confirmed cause. [Find feedback evidence](specs/001-mvp/evidence/document-find-match-feedback.md) owns verified scope and limitations.
- [Protected-folder privacy waits](notes/0004-protected-folder-permissions.md) retain the triggering-metadata and fresh/denied-access questions.
- [Website validation](specs/2026-10-17-website/validation.md) retains live/accessibility and discovery-client checks; [screenshot delivery](specs/2026-10-17-website/evidence/responsive-webp.md) retains its hosted-image limits.

The [code-quality plan](specs/001-mvp/2026-10-30-code-quality-plan.md) owns remediation scope; its [task rows](specs/001-mvp/tasks.md#2026-10-30-code-quality-remediation) own scoped acceptance and publication. Unit acceptance does not establish whole-app acceptance.

## Which workflows can be reused?

[Paper-trail skill](skills/panepeek-paper-trail/SKILL.md), [task starter](prompts/task-starter.md), [milestone guidance](prompts/README.md) and [validation index](validation/README.md).
