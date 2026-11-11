# PanePeek specifications

| Workstream | Status | Entry point |
| --- | --- | --- |
| 001 MVP / native baseline | Completed for MVP delivery; native baseline retained | [Spec package](001-mvp/README.md) and [closure review](../notes/2026-11-08-mvp-closure.md) |
| Website | Active | [Spec package](2026-10-17-website/README.md) |
| GitHub release updates | Active | [Spec package](2026-10-24-github-release-updates/README.md) |
| Git and agent worktrees | Active | [Spec package](2026-10-27-git-worktrees/README.md) |
| GitHub prerelease preparation | Accepted; candidate acceptance tracked separately | [Spec package](2026-11-02-github-prereleases/README.md) |
| Test and CI reliability | Active | [Maintenance package](2026-11-11-test-ci-reliability/README.md) |

A package owns one coherent workstream: `spec.md` holds outcomes, `plan.md` the approach, `tasks.md` task state, `validation.md` criterion verdicts and `evidence/` concise task checks.

MVP completion closes delivery. Its native baseline, engineering/accessibility rules and existing follow-up records remain binding at their stable paths. New feature workstreams use dated packages; closure never promotes Pending/Waived coverage or carries a release waiver forward.

Keep progress and results out of specs and plans. Update task and criterion rows in place and link concise evidence under the [repository content boundary](../README.md#repository-record-content). Manual acceptance and publication remain separate gates.

New spec packages and decisions use dated names. Preserve existing numbered names and links. Decisions and specs use the paper-trail status/header conventions; supersession is explicit, never inferred from a newer filename.
