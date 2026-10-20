---
task: github-ci-merge-checks
verdict: Passed
closed: 2026-10-17
---

# CI and merge checks

Main and PR workflows provide required build/test and privacy checks with pinned actions and read-only permissions. Main requires PR review resolution and successful checks, with force pushes and deletion blocked; CI does not replace app acceptance.

Reference: [PR #36](https://github.com/bcinarli/pane-peek/pull/36).
