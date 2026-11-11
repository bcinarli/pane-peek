---
status: Proposed
date: 2026-11-11
supersedes: []
superseded_by: ""
---

# Highlighting coverage

Completes the configuration inventory in [issue #144](https://github.com/bcinarli/pane-peek/issues/144) and extends it with missing aliases for supported languages and Kotlin, Ruby and Objective-C highlighting. Highlighting stays lexical, local and inert. [MVP closure](../../notes/2026-11-08-mvp-closure.md) · [Native baseline](../001-mvp/spec.md) · [Review gates](../001-mvp/plan.md#task-workflow-and-exit-gates)

| Record | Purpose |
| --- | --- |
| [Spec](spec.md) | Proposed inventory, lexical treatment and acceptance criteria. |
| [Plan](plan.md) | Implementation units, dependencies and verification gates. |
| [Tasks](tasks.md) | Coding readiness, manual review and publication state. |
| [Validation](validation.md) | Acceptance criteria and remaining checks. |

The [A15 highlighting contract](../001-mvp/spec.md#details-sidebar-and-preview-editor), with decisions [0006](../../decisions/0006-extended-syntax-highlighting.md) and [0007](../../decisions/0007-script-query-and-build-highlighting.md), remains binding for detection, editing, source preservation and accessibility. This package adds no dependency, engine, entitlement or network operation.
