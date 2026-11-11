# CLI and native path opening

[#132](https://github.com/bcinarli/pane-peek/issues/132) adds opening one local path from a terminal or native macOS file-open request, using PanePeek's existing browser, preview and permission rules. Native opening, the bundled launcher and app-menu setup are accepted within their reviewed scope.

| Record | Purpose |
| --- | --- |
| [Spec](spec.md) | Command behaviour, window policy and acceptance criteria. |
| [CLI entry point](../../decisions/2026-11-09-cli-entry-point.md) | Accepted launcher design and trade-offs. |
| [Plan](plan.md) | Implementation units and unresolved platform checks. |
| [Tasks](tasks.md) | Review, coding readiness and publication state. |
| [Validation](validation.md) | Criterion verdicts and remaining verification. |

The [native baseline](../001-mvp/spec.md), [folder-access model](../../notes/2026-10-20-app-store-sandbox-design.md) and [shared review gates](../../validation/checklist.md) remain binding. The [validation matrix](validation.md) and [tasks](tasks.md) retain broader distribution, accessibility and publication gates. Custom shell profiles can add the installed command directory to PATH.
