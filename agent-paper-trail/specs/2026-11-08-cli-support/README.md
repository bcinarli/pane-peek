# CLI and native path opening

Native scope and CLI command contract accepted for [#132](https://github.com/bcinarli/pane-peek/issues/132): open one local path from a terminal or native macOS file-open request, using PanePeek's existing browser, preview and permission rules. The shell-bootstrap/shared-executable design and Unit 2 manual checklist are accepted; setup and broader distribution acceptance remain gated.

| Record | Purpose |
| --- | --- |
| [Spec](spec.md) | Command behaviour, window policy and acceptance criteria. |
| [CLI entry point](../../decisions/2026-11-09-cli-entry-point.md) | Accepted launcher design and trade-offs. |
| [Plan](plan.md) | Implementation units and unresolved platform checks. |
| [Tasks](tasks.md) | Review, coding readiness and publication state. |
| [Validation](validation.md) | Criterion verdicts and remaining verification. |

The [native baseline](../001-mvp/spec.md), [folder-access model](../../notes/2026-10-20-app-store-sandbox-design.md) and [shared review gates](../../validation/checklist.md) remain binding. Units 1 and 2 are accepted; [launcher evidence](evidence/cli-launcher.md) and the Unit 3 review gate are recorded in the task tracker.
