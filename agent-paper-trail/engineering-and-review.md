# PanePeek engineering and review rules

Apply these rules to every workstream. Use the [validation checklist](validation/checklist.md) to review each unit and its owning spec and plan for task-specific checks.

## Core engineering requirements

- Keep functions focused, names clear and control flow local. Review nesting, state transitions and duplication against the task's risk. Avoid arbitrary complexity targets. Reuse existing validation, file operations and UI components where they fit. Give shared rules and state one owner and introduce abstractions at concrete boundaries.
- Keep comments short. Explain intent, non-obvious behaviour or public contracts. Keep stable requirement identifiers in their owning records and coding-unit identifiers in the working-plan home, never shipped comments.
- Bound work and memory. Justify the runtime, app size and maintenance cost of added dependencies or resources. Verify responsiveness in the running app when opening, editing, switching or other interactive paths change.

## Task review

1. Agree the implementation scope and any intermediate review checkpoints with the maintainer before starting. Break work into reviewable changes with acceptance criteria, dependencies and checks. Verify required dependencies on `main` and follow the [source-control decision](decisions/0002-feature-branches-and-prs.md). Collect the [required performance baseline](#performance-checks-for-feature-development) before implementation. Contributors may proceed within agreed scope between checkpoints; there is no default approval gate for each unit.
2. Use red/green TDD for meaningful automated behaviour. Observe a failure caused by the missing or incorrect behaviour, make the smallest passing change, then refactor with tests green. Cover requirements, meaningful failure paths and regressions. Prefer disposable filesystem fixtures and use bounded failure injection for conditions that are difficult to reproduce. Test observable behaviour. Exclude boilerplate, coverage targets and assertions that mirror implementation.
3. Run the required checks on each affected surface. For native app units, launch the app for review and apply the [native accessibility baseline](specs/001-mvp/spec.md#accessibility-baseline) to changed UI. Review website changes in a browser and use the website spec for accessibility. Exercise the relevant command, job or artifact for tooling, CI and release work. Verify layout and packaging with actual runs and builds.
4. Perform the [self-review checks](#self-review) before presenting a change or other meaningful output. Present the result, criteria covered, evidence, run and fixture instructions as needed, and a short manual checklist. Put detailed verification in the configured PR review home, using a conversation draft when writing there is unavailable or unauthorised. Reconcile only changed eligible outcomes and acceptance limits under the [paper-trail content rules](README.md#content-boundary).
5. Pause at agreed checkpoints, when scope changes or when an unresolved prerequisite blocks dependent work. Manual validation and maintainer acceptance remain required for the delivered result; they do not impose a pause after every unit. Keep incomplete criterion coverage Pending, preserve existing legacy task state and record unexecuted checks. A waiver requires maintainer approval for its exact scope. Obtain maintainer/code-owner review before merge and explicit maintainer authority for releases and distribution.

Contributors may commit and push their own feature branches within agreed scope and repository permissions. This project workflow does not override an agent user's instructions, tool permissions or external-write authorisation. Personal approval cadence stays in personal instructions. The [portable contributor workflow decision](decisions/2026-11-16-portable-contributor-workflow.md) replaces inherited per-unit approval rules without weakening technical requirements or acceptance criteria.

## Self-review

No personal skill installation is required. Use available tools or perform these checks directly, in this order:

1. **Simplify:** remove unnecessary abstraction, duplication and nesting; keep responsibilities clear and shared rules/state with one owner. Preserve behaviour, error handling and high-value tests.
2. **Check failure modes and evidence:** inspect realistic boundary/error cases, state and lifecycle transitions, requirement conflicts, regressions and missing validation. Verify claims against source and executed checks; distinguish demonstrated defects from unverified coverage.

At milestones, consider a bounded maintainability and test-quality review. Report source-backed findings before choosing remediation. Group accepted findings by cause, dependency or validation boundary into reviewable changes, with scope and checks in the issue. Agree any additional scope or checkpoints with the maintainer. Resolve correctness issues before milestone acceptance and explicitly defer optional maintenance. These activities require no particular skill or agent.

## Performance checks for feature development

Measure every new native app feature against a baseline before acceptance. Repeat affected checks before manual review of feature or maintenance units that change runtime or bundle size.

1. Build the pre-change revision and candidate in Release mode on the same Mac. Match the toolchain, architecture, distribution configuration, signing, isolated app state, fixtures, workload and timing boundaries.
2. Measure unpacked `.app` size from the original bundles by summing regular file sizes, excluding symlinks. Measure settled idle CPU and resident memory (RSS), then elapsed time, CPU time and sampled peak RSS during the workload. Sample the verified process with `ps -p "$panepeek_pid" -o rss=,time=` or Instruments. Keep sampling intervals consistent. Use the change in cumulative CPU time for the workload. Report idle CPU as CPU time divided by elapsed time, expressed as a percentage of one core. Flag readings below sampler resolution.
3. Alternate builds for at least three measured trials per build after matched warm-up. Compare medians and ranges. For a new flow, measure a relevant shared path on both builds and report the new flow on the candidate. Measure affected helper processes separately where they materially contribute to cost. State which processes the figures cover and identify component measurements.
4. Investigate reproducible regressions and present trade-offs for review. Record the revisions, relevant setup, figures and limits in the PR review home. Keep blocked checks Pending with the reason. Reconcile only durable performance outcomes or acceptance limits in the owning criterion; keep raw samples and traces outside the paper trail.
