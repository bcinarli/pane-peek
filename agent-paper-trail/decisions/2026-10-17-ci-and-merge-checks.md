---
status: Accepted
date: 2026-10-17
supersedes: []
superseded_by: ""
---

# CI and merge checks

## Context and decision

Bilal approved CI workflow implementation and merge-check enablement on 2026-10-17. Release automation is outside this scope. This extends [decision 0002](0002-feature-branches-and-prs.md), which left branch protection undecided; implementation, publication and manual acceptance retain their existing gates.

- Use GitHub-hosted macOS 26 Apple Silicon runners with an explicitly selected full Xcode and Node.js version. Reuse the repository's test runner and app bundler.
- Run the complete suite and app bundling as one stable check named `macOS build and test`, on PRs targeting `main`, pushes to `main` and manual dispatch. Run all PRs without path filters. Cancel superseded PR runs and bound job duration.
- Pin external actions to full commit hashes, keep repository permissions read-only and leave checkout credentials unpersisted. PR jobs receive no signing or other repository secrets.
- Verify and archive the development bundle, preserving its executable permissions. Keep downloadable artifacts for seven days. These are development builds; distribution signing and release packaging remain separate work.
- After a successful hosted run verifies the check's exact identity, enable a ruleset for `main`: require PRs, the current CI check and an up-to-date branch; require resolved review conversations; block force pushes and branch deletion. Require no additional reviewer approval for the solo-maintainer workflow and add no bypass actors. Preserve unrelated rulesets.
- Confirm enforcement through GitHub's live rules and check results. Local green alone does not establish hosted execution or merge protection. CI does not replace manual UI/accessibility acceptance.

## Rationale and alternatives

Hosted runners provide a fresh macOS environment without maintaining an always-available personal Mac. Self-hosting was considered but adds maintenance and availability requirements. One build/test job shares compilation work and provides one required check. A larger OS/architecture matrix can be reviewed when a concrete compatibility risk warrants it.

GitHub Pro supports enforced checks while the repository is private. The same workflow can continue when it becomes public. A workflow without a required-check rule would report failures without preventing merges; activating the rule before hosted validation risks blocking merges on an unavailable check.

## Records and validation

The [CI plan](../specs/001-mvp/plan.md#ci-and-merge-checks) owns the bounded sequence. The [task row](../specs/001-mvp/tasks.md#build-and-repository-automation) and [evidence](../specs/001-mvp/evidence/github-ci-merge-checks.md) retain executed checks, publication and enforcement state.
