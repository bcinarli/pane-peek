# PanePeek engineering and review rules

Apply these rules to every workstream. Use the [validation checklist](validation/checklist.md) to review each unit and its owning spec and plan for task-specific checks.

## Core engineering requirements

- Keep functions focused, names clear and control flow local. Review nesting, state transitions and duplication against the task's risk. Avoid arbitrary complexity targets. Reuse existing validation, file operations and UI components where they fit. Give shared rules and state one owner and introduce abstractions at concrete boundaries.
- Keep comments short. Explain intent, non-obvious behaviour or public contracts. Keep spec and task identifiers in the paper trail.
- Bound work and memory. Justify the runtime, app size and maintenance cost of added dependencies or resources. Verify responsiveness in the running app when opening, editing, switching or other interactive paths change.

## Task review

1. Define one coding unit with its acceptance criteria, dependencies and checks. Verify required dependencies on `main`, obtain unit approval, and follow the [source-control decision](decisions/0002-feature-branches-and-prs.md). Plan and collect the [required performance baseline](#performance-checks-for-feature-development) before implementation.
2. Use red/green TDD for meaningful automated behaviour. Observe a failure caused by the missing or incorrect behaviour, make the smallest passing change, then refactor with tests green. Cover requirements, meaningful failure paths and regressions. Prefer disposable filesystem fixtures and use bounded failure injection for conditions that are difficult to reproduce. Test observable behaviour. Exclude boilerplate, coverage targets and assertions that mirror implementation.
3. Run the required checks on each affected surface. For native app units, launch the app for review and apply the [native accessibility baseline](specs/001-mvp/spec.md#accessibility-baseline) to changed UI. Review website changes in a browser and use the website spec for accessibility. Exercise the relevant command, job or artifact for tooling, CI and release work. Verify layout and packaging with actual runs and builds.
4. Apply tighten followed by probe before presenting each code unit or other meaningful output. Present the result, criteria covered, evidence, run and fixture instructions as needed, and a short manual checklist. Record concise outcomes and limits under the [paper-trail content rules](README.md#repository-record-content).
5. Wait for Bilal's manual acceptance before starting the next unit. Keep the unit Active and its verdict Pending until manual acceptance. Record unexecuted checks. Leave partly verified criteria Pending unless an applicable waiver covers them. Commit, push, merge and distribution each require separate approval.

At milestones, consider [code-quality analysis](prompts/README.md). Review the findings before planning remediation and obtain approval before implementing each cluster. Resolve correctness issues before milestone acceptance and explicitly defer optional maintenance.

## Performance checks for feature development

Measure every new native app feature against a baseline before acceptance. Repeat affected checks before manual review of feature or maintenance units that change runtime or bundle size.

1. Build the pre-change revision and candidate in Release mode on the same Mac. Match the toolchain, architecture, distribution configuration, signing, isolated app state, fixtures, workload and timing boundaries.
2. Measure unpacked `.app` size from the original bundles by summing regular file sizes, excluding symlinks. Measure settled idle CPU and resident memory (RSS), then elapsed time, CPU time and sampled peak RSS during the workload. Sample the verified process with `ps -p "$panepeek_pid" -o rss=,time=` or Instruments. Keep sampling intervals consistent. Use the change in cumulative CPU time for the workload. Report idle CPU as CPU time divided by elapsed time, expressed as a percentage of one core. Flag readings below sampler resolution.
3. Alternate builds for at least three measured trials per build after matched warm-up. Compare medians and ranges. For a new flow, measure a relevant shared path on both builds and report the new flow on the candidate. Measure affected helper processes separately where they materially contribute to cost. State which processes the figures cover and identify component measurements.
4. Investigate reproducible regressions and present trade-offs for review. Record the revisions, relevant setup, key figures and limits in task evidence. Keep blocked checks Pending with the reason. Retain raw samples and traces with private review material.
