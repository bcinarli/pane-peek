---
status: Accepted
date: 2026-11-11
supersedes: []
superseded_by: ""
---

# Test and CI reliability

This maintenance package covers video test reliability, Swift compiler warnings and macOS tooling coverage. The native baseline and its engineering, accessibility and review gates apply. [Issue #186](https://github.com/bcinarli/pane-peek/issues/186) · [MVP closure](../../notes/2026-11-08-mvp-closure.md) · [Native baseline](../001-mvp/spec.md) · [Review gates](../001-mvp/plan.md#task-workflow-and-exit-gates)

## Video playback

Check source and file-access ownership independently of decoder startup. Keep real filesystem coverage for bounded reads and link restrictions. Use the production preview view in a laid-out window to verify readiness within five seconds, a paused first frame, playback advancement, pause, item replacement and cleanup on owning-window closure.

Extend the existing CI workload isolation with a required video phase. Discovery assigns each test to exactly one phase across highlighting, core, native and video. Native and video phases run serially in separate processes. Explicit selections and queries run once. Retain process bounds, descendant cleanup and diagnostic logs. A failed phase ends the run. [CI workload isolation](../001-mvp/plan.md#ci-workload-isolation)

## Compiler warnings

Remove the reported Swift warnings while preserving cancellation, saved-editor refresh, weak ownership, search announcements and rename and clipboard coverage. Keep the supported Swift baseline and validate local warnings-as-errors compilation, affected tests, the signed sandbox build and hosted execution.

## macOS tooling

Run Store asset and metadata, folder permission, package note and signing checks in the macOS CI job alongside runner and release-numbering checks. Preserve the Linux privacy gate, pinned actions, permissions and required build and test check. Verify the selected tests execute on hosted macOS.

[Tasks](tasks.md) records implementation, review and publication. [Validation](validation.md) records verified outcomes and remaining scope.
